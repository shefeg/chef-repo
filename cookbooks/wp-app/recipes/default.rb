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
  credentials = data_bag_item('credentials', 'mysql_local')
  ENV['DB_NAME'] = credentials['db_name']
  ENV['USER'] = credentials['user']
  ENV['PASSWORD'] = credentials['password']
else
  ENV['RDS_ENDPOINT'] = `cat /tmp/rds_endpoint.txt`.chomp
  ENV['EC2_ENDPOINT'] = `cat /tmp/ec2_endpoint.txt`.chomp
  credentials = data_bag_item('credentials', 'mysql', Chef::EncryptedDataBagItem.load_secret('/tmp/key'))
  ENV['DB_NAME'] = credentials['db_name']
  ENV['USER'] = credentials['user']
  ENV['PASSWORD'] = credentials['password']
end

case node['platform_family']
when 'debian'
  package_list = ['mysql-client', 'php7.0', 'php7.0-mysql', 'libapache2-mod-php7.0', 'php7.0-cli',
                  'php7.0-cgi', 'php7.0-gd', 'apache2', 'apache2-utils', 'curl', 'rsync'
                 ]
  mysql_package = 'mysql-server'
  mysql_service = 'mysql'
  apache_service = 'apache2'
  ENV['APACHE_USER'] = 'www-data'
  apache_config_dir = '/etc/apache2/sites-enabled'
when 'rhel'
  package_list = ['mysql-community-client', 'php', 'php-common', 'php-mysqlnd', 'php-gd', 'php-xml',
                  'php-mbstring', 'php-pecl-mcrypt', 'php-xmlrpc', 'httpd', 'curl', 'httpd', 'rsync'
                 ]
  mysql_package = 'mysql-community-server'
  mysql_service = 'mysqld'
  apache_service = 'httpd'
  ENV['APACHE_USER'] = 'apache'
  apache_config_dir = '/etc/httpd/conf.d'
end

ENV['WP_CONTENT_DIR'] = '/var/www/html'

# set additional repositories for required packages installation and set selinux to permissive
case node['platform_family']
#---- DEBIAN ----
when 'debian'
  apt_repository 'php' do
    uri 'ppa:ondrej/php'
    components ['main']
    action :add
  end

  apt_update 'update'

#---- RHEL ----
when 'rhel'
  yum_repository 'epel' do
    description 'Extra Packages for Enterprise Linux 7 - $basearch'
    baseurl "http://download.fedoraproject.org/pub/epel/7/$basearch"
    enabled true
    gpgcheck false
    action :create
  end

  yum_repository 'mysql57-community' do
    description 'MySQL 5.7 Community Server'
    baseurl "http://repo.mysql.com/yum/mysql-5.7-community/el/7/$basearch/"
    enabled true
    gpgcheck false
    action :create
  end

  yum_repository 'remi-safe' do
    description "Safe Remi's RPM repository for Enterprise Linux 7 - $basearch"
    mirrorlist 'http://cdn.remirepo.net/enterprise/7/safe/mirror'
    enabled true
    gpgcheck false
    action :create
  end

  yum_repository 'remi-php72' do
    description "Remi's PHP 7.2 RPM repository for Enterprise Linux 7 - $basearch"
    mirrorlist 'http://cdn.remirepo.net/enterprise/7/php72/mirror'
    enabled true
    gpgcheck false
    action :create
  end

  execute 'set SELINUX to permissive' do # or define apache rule: setsebool -P httpd_can_network_connect=true
    user 'root'
    command 'setenforce 0'
    action :run
    not_if { `sestatus | sed -n -e 's/^Current mode: *//p'`.chomp == 'permissive' }
  end
end

package 'required packages' do
  package_name package_list
  action :install
  notifies :run, 'bash[verify PHP installation]', :immediately
end

# install local mysql server for localtesting
package 'mysql' do
  package_name mysql_package
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
  cat <<EOF > $WP_CONTENT_DIR/info.php
  <?php
  phpinfo();
  ?>
  EOF
  if [[ $(curl localhost/info.php) = *"PHP Version 7"* ]]; then
    echo "SUCCESS!"
  else
    exit 1
  fi
  rm -rf $WP_CONTENT_DIR/info.php
  EOH
  action :nothing
end

template "#{apache_config_dir}/wp.conf" do
  source 'wp.conf.erb'
  owner 'root'
  group 'root'
  mode '0644'
  variables(SERVERNAME: ENV['EC2_ENDPOINT'],
            DOCUMENTROOT: ENV['WP_CONTENT_DIR'])
  action :create
  notifies :run, 'execute[run apache configtest]', :immediately
  notifies :reload, 'service[apache]', :immediately
end

# in situations when we change apache configs
execute 'run apache configtest' do
  user 'root'
  command 'apachectl configtest'
  action :nothing
  subscribes :run, 'bash[copy wp content]', :immediately
end

# this block is for cases when we need to reload apache
service 'apache' do
  service_name apache_service
  action [:enable, :start]
end

service 'mysql' do
  service_name mysql_service
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
  not_if { ::File.exist?("#{ENV['WP_CONTENT_DIR']}/wp-config.php") }
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
  notifies :run, 'bash[copy wp content]', :before
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
#   action :nothing
# end
