<<<<<<< HEAD
#
# Cookbook:: wp-app
# Recipe:: default
#
# Copyright:: 2018, The Authors, All Rights Reserved.

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

#---- RHEL ----
when 'rhel'
  package 'epel-release' do
    action [:install]
  end
  
  bash 'install mysql repo' do
    user 'root'
    code <<-EOH
    wget -nc https://dev.mysql.com/get/mysql57-community-release-el7-9.noarch.rpm
    rpm -ivh mysql57-community-release-el7-9.noarch.rpm
    EOH
    action :run
  end

  package 'required packages' do
    package_name ['mysql', 'php', 'php-common', 'php-mysql', 'php-gd', 'php-xml', 'php-mbstring', 
                  'php-mcrypt', 'php-xmlrpc', 'httpd', 'curl'
                 ]
    action :install
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


bash 'verify php' do
  user 'root'
  code <<-EOH
  cat <<EOF > /var/www/html/info.php
  <?php
  phpinfo();
  ?>
  EOF
  if [[ $(curl localhost/info.php) = *"PHP Version 7"* ]]; then
      echo "SUCCESS!"
  else
      exit 1
  fi
  EOH
end

remote_file '/root/latest.tar.gz' do
  source 'http://wordpress.org/latest.tar.gz'
  owner 'root'
  group 'root'
  mode '0755'
  action :create_if_missing
end

case node['platform_family']
#---- DEBIAN ----
when 'debian'
  bash 'copy wp content' do
    user 'root'
    code <<-EOH
    tar -xzf /root/latest.tar.gz -C /root
    rsync -av /root/wordpress/* /var/www/html/
    chown -R www-data:www-data /var/www/html/
    chmod -R 755 /var/www/html/
    EOH
    action :run
  end

  cookbook_file '/var/www/html/wp-config.php' do
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
    rsync -av /root/wordpress/* /var/www/html/
    chown -R apache:apache /var/www/html/
    chmod -R 755 /var/www/html/
    EOH
    action :run
  end

  cookbook_file '/var/www/html/wp-config.php' do
    source 'wp-config.php'
    owner 'apache'
    group 'apache'
    mode '0755'
    action :create
  end
end

file '/var/www/html/index.html' do
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
=======
#
# Cookbook:: wp-app
# Recipe:: default
#
# Copyright:: 2018, The Authors, All Rights Reserved.


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

#---- RHEL ----
when 'rhel'
  package 'epel-release' do
    action [:install]
  end

  bash 'install mysql repo' do
    user 'root'
    code <<-EOH
    wget -nc https://dev.mysql.com/get/mysql57-community-release-el7-9.noarch.rpm
    rpm -ivh mysql57-community-release-el7-9.noarch.rpm
    EOH
    action :run
  end

  package 'required packages' do
    package_name ['mysql', 'php', 'php-common', 'php-mysql', 'php-gd', 'php-xml', 'php-mbstring',
                  'php-mcrypt', 'php-xmlrpc', 'httpd', 'curl'
                 ]
    action :install
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


bash 'verify php' do
  user 'root'
  code <<-EOH
  cat <<EOF > /var/www/html/info.php
  <?php
  phpinfo();
  ?>
  EOF
  if [[ $(curl localhost/info.php) = *"PHP Version 7"* ]]; then
      echo "SUCCESS!"
  else
      exit 1
  fi
  EOH
end

remote_file '/root/latest.tar.gz' do
  source 'http://wordpress.org/latest.tar.gz'
  owner 'root'
  group 'root'
  mode '0755'
  action :create_if_missing
end

case node['platform_family']
#---- DEBIAN ----
when 'debian'
  bash 'copy wp content' do
    user 'root'
    code <<-EOH
    tar -xzf /root/latest.tar.gz -C /root
    rsync -av /root/wordpress/* /var/www/html/
    chown -R www-data:www-data /var/www/html/
    chmod -R 755 /var/www/html/
    EOH
    action :run
  end

  cookbook_file '/var/www/html/wp-config.php' do
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
    rsync -av /root/wordpress/* /var/www/html/
    chown -R apache:apache /var/www/html/
    chmod -R 755 /var/www/html/
    EOH
    action :run
  end

  cookbook_file '/var/www/html/wp-config.php' do
    source 'wp-config.php'
    owner 'apache'
    group 'apache'
    mode '0755'
    action :create
  end
end

file '/var/www/html/index.html' do
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

cookbook_file '/var/www/html/db_setup.sql' do
  source 'db_setup.sql'
  owner 'root'
  group 'root'
  mode '0755'
  action :create
  notifies :run, 'bash[import db settings]', :immediately
  ignore_failure true
end

bash 'import db settings' do
  code <<-EOH
  DB_NAME=$(grep "DB_NAME" /var/www/html/wp-config.php | cut -d',' -f 2 | tr -d "';) ")
  DB_USER=$(grep "DB_USER" /var/www/html/wp-config.php | cut -d',' -f 2 | tr -d "';) ")
  DB_PASSWORD=$(grep "DB_PASSWORD" /var/www/html/wp-config.php | cut -d',' -f 2 | tr -d "';) ")
  DB_HOST=$(grep "DB_HOST" /var/www/html/wp-config.php | cut -d',' -f 2 | tr -d "';) ")
  
  mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD $DB_NAME < /var/www/html/db_setup.sql
  EOH
  action :nothing
end

bash 'verify wp login' do
  user 'root'
  code <<-EOH
  DB_NAME=$(grep "DB_NAME" /var/www/html/wp-config.php | cut -d',' -f 2 | tr -d "';) ")
  DB_USER=$(grep "DB_USER" /var/www/html/wp-config.php | cut -d',' -f 2 | tr -d "';) ")
  DB_PASSWORD=$(grep "DB_PASSWORD" /var/www/html/wp-config.php | cut -d',' -f 2 | tr -d "';) ")
  DB_HOST=$(grep "DB_HOST" /var/www/html/wp-config.php | cut -d',' -f 2 | tr -d "';) ")
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
>>>>>>> wp-app
