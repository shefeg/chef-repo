#
# Cookbook:: wp-app
# Recipe:: default
#
# Copyright:: 2018, The Authors, All Rights Reserved.

ENV['WP_CONTENT_DIR'] = '/var/www/html'

case node['platform_family']
#---- DEBIAN ----
when 'debian'
  apt_repository 'php' do
    uri 'ppa:ondrej/php'
    components ['main']
    action :add
  end

  apt_update 'update'

  package 'required packages' do
    package_name ['mysql-client', 'php7.0', 'php7.0-mysql', 'libapache2-mod-php7.0', 'php7.0-cli',
                  'php7.0-cgi', 'php7.0-gd', 'apache2', 'apache2-utils', 'curl'
                 ]
    action :install
  end

# TO DO rework repository add
#---- RHEL ----
when 'rhel'
  # install additional repositories listed in attributes file
  node['repository']['files'].each do |pkg, src|
    remote_file "/tmp/#{pkg}" do
      source src
      owner 'root'
      group 'root'
      mode '0755'
      action :create_if_missing
    end
    rpm_package pkg do
      source "/tmp/#{pkg}"
      action :install
    end
  end

  bash 'enable remi-php72 repo' do
    user 'root'
    code <<-EOH
    sed -i 's/enabled=.*/enabled=1/' /etc/yum.repos.d/remi-php72.repo
    EOH
    action :run
  end

  package 'install required packages' do 
   package_name ['mysql-community-client', 'php', 'php-common', 'php-mysql', 'php-gd', 'php-xml', 'php-mbstring',
                 'php-mcrypt', 'php-xmlrpc', 'httpd', 'curl', 'httpd'
                ]
   action :install
 end

  bash 'set SELINUX to permissive' do # or define apache rule: setsebool -P httpd_can_network_connect=true
    user 'root'
    code <<-EOH
    setenforce 0
    EOH
    action :run
    ignore_failure true
  end
 end

service 'apache2' do
  case node['platform_family']
  #---- DEBIAN ----
  when 'debian'
    service_name 'apache2'
  #---- RHEL ----
  when 'rhel'
    service_name 'httpd'
  end
  action [:enable, :start]
end

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
end

# TO DO change user to apache, change root to tmp dir, remove wp package after install
remote_file '/root/latest.tar.gz' do
  source 'http://wordpress.org/latest.tar.gz'
  owner 'root'
  group 'root'
  mode '0755'
  action :create_if_missing
end

# TO DO research permissions for WP content
case node['platform_family']
#---- DEBIAN ----
when 'debian'
  bash 'copy WP content' do
    user 'root'
    code <<-EOH
    tar -xzf /root/latest.tar.gz -C /root
    rsync -av /root/wordpress/* $WP_CONTENT_DIR/
    chown -R www-data:www-data $WP_CONTENT_DIR
    chmod -R 755 $WP_CONTENT_DIR
    EOH
    action :run
  end

  cookbook_file "#{ENV['WP_CONTENT_DIR']}/wp-config.php" do
    source 'wp-config.php'
    owner 'www-data'
    group 'www-data'
    mode '0755'
    action :create
  end

#---- RHEL ----
when 'rhel'
  bash 'copy wp content' do
    user 'root'
    code <<-EOH
    tar -xzf /root/latest.tar.gz -C /root
    rsync -av /root/wordpress/* $WP_CONTENT_DIR
    chown -R apache:apache $WP_CONTENT_DIR
    chmod -R 755 $WP_CONTENT_DIR
    EOH
    action :run
  end

  # create wp-config.php file from template
  cookbook_file "#{ENV['WP_CONTENT_DIR']}/wp-config.php" do
    source 'wp-config.php'
    owner 'apache'
    group 'apache'
    mode '0755'
    action :create
  end
end

bash 'populate RDS and EC2 endpoints to wp-config' do
  user 'root'
  code <<-EOH
  RDS_HOST="$(cat /tmp/rds_endpoint.txt)"
  EC2_HOST="$(cat /tmp/ec2_endpoint.txt)"
  WP_CONFIG_RDS="define( 'DB_HOST', '$RDS_HOST' );"
  WP_CONFIG_HOME="define('WP_HOME','http://$EC2_HOST');"
  WP_CONFIG_SITE_URL="define('WP_SITEURL','http://$EC2_HOST');"
  sed -i -e "/DB_HOST/c\${WP_CONFIG_RDS}" $WP_CONTENT_DIR/wp-config.php
  sed -i -e '/WP_HOME/d' -e '/WP_SITEURL/d' $WP_CONTENT_DIR/wp-config.php
  echo "\n${WP_CONFIG_HOME}" >> $WP_CONTENT_DIR/wp-config.php
  echo "${WP_CONFIG_SITE_URL}\n" >> $WP_CONTENT_DIR/wp-config.php
  EOH
  action :run
end

file "#{ENV['WP_CONTENT_DIR']}/index.html" do
  action :delete
end

service 'apache2' do
  case node['platform_family']
  #---- DEBIAN ----
  when 'debian'
    service_name 'apache2'
  #---- RHEL ----
  when 'rhel'
    service_name 'httpd'
  end
  action :restart
end

cookbook_file "#{ENV['WP_CONTENT_DIR']}/db_setup.sql" do
  source 'db_setup.sql'
  owner 'root'
  group 'root'
  mode '0755'
  action :create
  ignore_failure true
end

# TO DO change db host address (siteurl, home) in DB table;
# TO DO research kitchen testing locally (create toggle, install local mysql, etc...)
# Install todo plugin and merge everything to master
bash 'import db settings' do
  user 'root'
  code <<-EOH
  DB_NAME=$(grep "DB_NAME" $WP_CONTENT_DIR/wp-config.php | cut -d',' -f 2 | tr -d "';) ")
  DB_USER=$(grep "DB_USER" $WP_CONTENT_DIR/wp-config.php | cut -d',' -f 2 | tr -d "';) ")
  DB_PASSWORD=$(grep "DB_PASSWORD" $WP_CONTENT_DIR/wp-config.php | cut -d',' -f 2 | tr -d "';) ")
  DB_HOST=$(grep "DB_HOST" $WP_CONTENT_DIR/wp-config.php | cut -d',' -f 2 | tr -d "';) ")
  while ! mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD $DB_NAME < $WP_CONTENT_DIR/db_setup.sql; do echo "DB import failed, retrying..."; sleep 5; done
  EOH
  action :run
end

bash 'verify wp login' do
  user 'root'
  code <<-EOH
  DB_NAME=$(grep "DB_NAME" $WP_CONTENT_DIR/wp-config.php | cut -d',' -f 2 | tr -d "';) ")
  DB_USER=$(grep "DB_USER" $WP_CONTENT_DIR/wp-config.php | cut -d',' -f 2 | tr -d "';) ")
  DB_PASSWORD=$(grep "DB_PASSWORD" $WP_CONTENT_DIR/wp-config.php | cut -d',' -f 2 | tr -d "';) ")
  DB_HOST=$(grep "DB_HOST" $WP_CONTENT_DIR/wp-config.php | cut -d',' -f 2 | tr -d "';) ")
  WP_LOGIN=$(curl -v --data "log=$DB_USER&pwd=$DB_PASSWORD&wp-submit=Log+In&testcookie=1" \
  --cookie 'wordpress_test_cookie=WP+Cookie+check' http://localhost/wp-login.php 2>&1 | cat)
  if [[ "$WP_LOGIN" = *"wordpress_logged_in"* ]]; then
    echo "LOG IN TO WORDPRESS IS SUCCESSFULL"
  else
    exit 1
  fi
  EOH
  action :run
end