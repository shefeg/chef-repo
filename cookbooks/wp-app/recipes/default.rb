#
# Cookbook:: wp-app
# Recipe:: default
#
# Copyright:: 2018, The Authors, All Rights Reserved.

# ***** SET ENV VARIABLES *****
# 'localmode' attribute is 'false' by default. it's value should be 'true' in kitchen.yml for local kitchen testing
node.normal['localmode'] = 'true'

if node['localmode'] == 'true'
  ENV['RDS_ENDPOINT'] = 'localhost'
  ENV['EC2_ENDPOINT'] = 'localhost'
  # credentials = data_bag_item('credentials', 'mysql_local') - have troubles with data_bags and local testing
  ENV['DB_NAME'] = 'wordpress'
  ENV['USER'] = 'wordpressuser'
  ENV['PASSWORD'] = 'Drowssap1!'
else
  ENV['RDS_ENDPOINT'] = `cat /tmp/rds_endpoint.txt`.chomp
  ENV['EC2_ENDPOINT'] = `cat /tmp/ec2_endpoint.txt`.chomp
  credentials = data_bag_item('credentials', 'mysql', Chef::EncryptedDataBagItem.load_secret('/tmp/key'))
  ENV['DB_NAME'] = credentials['db_name']
  ENV['USER'] = credentials['user']
  ENV['PASSWORD'] = credentials['password']
end

ENV['APACHE_USER'] = node['apache']['user']
ENV['WP_CONTENT_DIR'] = '/var/www/html'

# set additional repositories for required packages installation and set selinux to permissive
case node['platform_family']
#---- DEBIAN ----
when 'debian'
  for index in (0...node['repositories']['apt_repository'].length)
    apt_repository node['repositories']['apt_repository'][index] do
      uri node['repositories']['uri'][index]
      components ["#{node['repositories']['components'][index]}"]
      action :add
    end
  end

  apt_update 'update'

#---- RHEL ----
when 'rhel'
  for index in (0...node['repositories']['yum_repository'].length)
    yum_repository node['repositories']['yum_repository'][index] do
      description node['repositories']['description'][index]
      baseurl node['repositories']['baseurl'][index]
      enabled true
      gpgcheck false
      action :create
    end
  end

  execute 'setenforce 0' do # or define apache rule: setsebool -P httpd_can_network_connect=true
    user 'root'
    action :run
    not_if { `sestatus | sed -n -e 's/^Current mode: *//p'`.chomp == 'permissive' }
  end
end

package node['package_list'] do
  action :install
  notifies :run, 'bash[verify PHP installation]', :immediately
  notifies :delete, "file[#{ENV['WP_CONTENT_DIR']}/index.html]", :immediately
end

# install local mysql server for localtesting
package node['mysql']['package'] do
  action :install
  only_if { node['localmode'] == 'true' }
end

directory ENV['WP_CONTENT_DIR'] do
  recursive true
  action :create
end

# verify if PHP is installed properly
bash 'verify PHP installation' do
  user 'root'
  code <<-EOH
  cat <<EOF > ${WP_CONTENT_DIR}/info.php
  <?php
  phpinfo();
  ?>
  EOF
  [[ $(curl localhost/info.php) = *"PHP Version 7"* ]] && rm -f ${WP_CONTENT_DIR}/info.php || rm -f ${WP_CONTENT_DIR}/info.php; exit 1;
  EOH
  action :nothing
end

template "#{node['apache']['config_dir']}/wp.conf" do
  source 'wp.conf.erb'
  owner 'root'
  group 'root'
  mode '0644'
  variables(SERVERNAME: ENV['EC2_ENDPOINT'],
            DOCUMENTROOT: ENV['WP_CONTENT_DIR'])
  action :create
  notifies :run, 'execute[apachectl configtest]', :immediately
  notifies :reload, "service[#{node['apache']['service']}]", :immediately
end

# in situations when we change apache configs
execute 'apachectl configtest' do
  user 'root'
  action :nothing
  subscribes :run, 'bash[copy wp content]', :immediately
end

# this block is for cases when we need to reload apache
service node['apache']['service'] do
  action [:enable, :start]
end

service node['mysql']['service'] do
  action [:enable, :start]
  only_if { node['localmode'] == 'true' }
end

bash 'create local mysql user and db' do
  user 'root'
  code <<-EOH
  ROOTPASSWD="$(sed -n -e 's/^.*temporary password.*: //p' /var/log/mysqld.log)"
  mysql -u root -p${ROOTPASSWD} --connect-expired-password -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${PASSWORD}';" || true
  mysql -u root -p${PASSWORD} -e "CREATE DATABASE ${DB_NAME} /*\!40100 DEFAULT CHARACTER SET utf8 */;" || true
  mysql -u root -p${PASSWORD} -e "CREATE USER '${USER}' IDENTIFIED BY '${PASSWORD}';" || \
  mysql -u root -p${PASSWORD} -e "SET PASSWORD FOR '${USER}'='${PASSWORD}';"
  mysql -u root -p${PASSWORD} -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${USER}';"
  mysql -u root -p${PASSWORD} -e "FLUSH PRIVILEGES;"
  EOH
  action :run
  only_if { node['localmode'] == 'true' }
end

# download WP package
remote_file '/tmp/latest.tar.gz' do
  source 'http://wordpress.org/latest.tar.gz'
  owner ENV['APACHE_USER']
  group ENV['APACHE_USER']
  mode '0755'
  action :create
  not_if { ::File.exist?("#{ENV['WP_CONTENT_DIR']}/index.php") }
  notifies :run, 'bash[copy wp content]', :immediately
end

# install WP package and copy content
bash 'copy wp content' do
  user 'root'
  code <<-EOH
  tar -xzf /tmp/latest.tar.gz -C /tmp
  rsync -av /tmp/wordpress/* $WP_CONTENT_DIR/
  rm -rf /tmp/latest.tar.gz /tmp/wordpress
  EOH
  action :nothing
end

# creating wp-config.php file
template "#{ENV['WP_CONTENT_DIR']}/wp-config.php" do
  source 'wp-config.php.erb'
  owner ENV['APACHE_USER']
  group ENV['APACHE_USER']
  mode '0644'
  variables(DB_NAME: ENV['DB_NAME'],
            USER: ENV['USER'],
            PASSWORD: ENV['PASSWORD'],
            DB_HOST: ENV['RDS_ENDPOINT'])
  action :create
end

file "#{ENV['WP_CONTENT_DIR']}/index.html" do
  action :delete
end

bash 'set permissions to wp directories and files' do
  user 'root'
  code <<-EOH
  chown -R ${APACHE_USER}:${APACHE_USER} $WP_CONTENT_DIR
  find $WP_CONTENT_DIR -type d -exec chmod 755 {} \; > /dev/null
  find $WP_CONTENT_DIR -type f -exec chmod 644 {} \; > /dev/null
  EOH
  action :run
end

# creating mysql dump file for importing into db
template "#{ENV['WP_CONTENT_DIR']}/db_setup.sql" do
  source 'db_setup.sql.erb'
  owner ENV['APACHE_USER']
  group ENV['APACHE_USER']
  mode '0644'
  variables(DB_HOST: ENV['RDS_ENDPOINT'],
            DB_NAME: ENV['DB_NAME'],
            EC2_ENDPOINT: ENV['EC2_ENDPOINT'])
  action :create
  notifies :run, 'bash[import db settings]', :immediately
end

bash 'import db settings' do
  user 'root'
  code <<-EOH
  mysql -h ${RDS_ENDPOINT} -u ${USER} -p${PASSWORD} ${DB_NAME} < ${WP_CONTENT_DIR}/db_setup.sql
  mysql -h ${RDS_ENDPOINT} -u ${USER} -p${PASSWORD} ${DB_NAME} -e "UPDATE wp_users SET user_login='${USER}' WHERE ID=1 LIMIT 1;"
  mysql -h ${RDS_ENDPOINT} -u ${USER} -p${PASSWORD} ${DB_NAME} -e "UPDATE wp_users SET user_pass=MD5('${PASSWORD}') WHERE ID=1 LIMIT 1;"
  mysql -h ${RDS_ENDPOINT} -u ${USER} -p${PASSWORD} ${DB_NAME} -e "UPDATE wp_users SET user_email='${USER}@example.com' WHERE ID=1 LIMIT 1;"
  EOH
  action :nothing
  retries 6
  retry_delay 5
  # notifies :run, 'bash[verify wp login]', :immediately
end

# bash 'verify wp login' do
#   user 'root'
#   code <<-EOH
#   WP_LOGIN=$(curl -v --data "log=${USER}&pwd=${PASSWORD}&wp-submit=Log+In&testcookie=1" \
#   --cookie 'wordpress_test_cookie=WP+Cookie+check' http://$EC2_ENDPOINT/wp-login.php 2>&1 | cat)
#   if [[ "$WP_LOGIN" = *"wordpress_logged_in"* ]]; then
#     echo "LOG IN TO WORDPRESS IS SUCCESSFULL"
#   else
#     exit 1
#   fi
#   EOH
#   action :run
# end
