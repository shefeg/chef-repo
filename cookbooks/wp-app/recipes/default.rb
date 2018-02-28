#
# Cookbook:: wp-app
# Recipe:: default
#
# Copyright:: 2018, The Authors, All Rights Reserved.

#***** SET KEY *****  # for testing purposes! don't store key in repository!
# cookbook_file '/tmp/key' do
#   source 'key'
#   owner 'root'
#   group 'root'
#   mode '0640'
#   action :create
# end

#***** SET ENV VARIABLES *****
ENV['WP_CONTENT_DIR'] = '/var/www/html'
ENV['RDS_ENDPOINT'] = `cat /tmp/rds_endpoint.txt`.chomp
ENV['EC2_ENDPOINT'] = `cat /tmp/ec2_endpoint.txt`.chomp
credentials = data_bag_item('credentials', 'mysql',  IO.read('/tmp/key'))
ENV['DB_NAME'] = credentials['db_name']
ENV['USER'] = credentials['user']
ENV['PASSWORD'] = credentials['password']

#***** CONFIGURATION BLOCK *****
# def do_something_useless()
#   puts "You gave me EC2: #{ENV['RDS_ENDPOINT']} and RDS: #{ENV['EC2_ENDPOINT']} and DB_NAME: #{ENV['DB_NAME']} and USER: #{ENV['USER']} and PASSWORD: #{ENV['PASSWORD']}"
# end

# do_something_useless()

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

# TODO rework repository add
#---- RHEL ----
when 'rhel'
  # set additional repositories for required packages installation
  yum_repository 'epel' do
    description "Extra Packages for Enterprise Linux 7 - $basearch"
    baseurl "http://download.fedoraproject.org/pub/epel/7/$basearch"
    gpgkey 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7'
    enabled true
    gpgcheck true
    action :create
  end

  yum_repository 'mysql57-community' do
    description 'MySQL 5.7 Community Server'
    baseurl "http://repo.mysql.com/yum/mysql-5.7-community/el/7/$basearch/"
    gpgkey 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mysql'
    enabled true
    gpgcheck true
    action :create
  end

  yum_repository 'remi-php72' do
    description "Remi's PHP 7.2 RPM repository for Enterprise Linux 7 - $basearch"
    mirrorlist "http://cdn.remirepo.net/enterprise/7/php72/mirror"
    gpgkey 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-remi'
    enabled true
    gpgcheck true
    action :create
  end
  
  # node['repository']['files'].each do |pkg, src|
  #   remote_file "/tmp/#{pkg}" do
  #     source src
  #     owner 'root'
  #     group 'root'
  #     mode '0755'
  #     action :create_if_missing
  #   end
  #   rpm_package pkg do
  #     source "/tmp/#{pkg}"
  #     action :install
  #   end
  # end

  # bash 'enable remi-php72 repo' do
  #   user 'root'
  #   code <<-EOH
  #   sed -i 's/enabled=.*/enabled=1/' /etc/yum.repos.d/remi-php72.repo
  #   EOH
  #   action :run
  # end

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

remote_file '/tmp/latest.tar.gz' do
  source 'http://wordpress.org/latest.tar.gz'
  owner 'root'
  group 'root'
  mode '0755'
  action :create_if_missing
end

case node['platform_family']
#---- DEBIAN ----
when 'debian'
  bash 'copy WP content' do
    user 'root'
    code <<-EOH
    tar -xzf /tmp/latest.tar.gz -C /tmp
    rsync -av /tmp/wordpress/* $WP_CONTENT_DIR/
    rm -rf /tmp/latest.tar.gz /tmp/wordpress
    find $WP_CONTENT_DIR -type d -exec chmod 755 {} \;
    find $WP_CONTENT_DIR -type f -exec chmod 644 {} \;
    EOH
    action :run
  end

  # create wp-config.php file from template
  template "#{ENV['WP_CONTENT_DIR']}/wp-config.php" do
    source 'wp-config.php.erb'
    owner 'www-data'
    group 'www-data'
    mode '0644'
    variables(DB_NAME: ENV['DB_NAME'],
              USER: ENV['USER'],
              PASSWORD: ENV['PASSWORD'],
              DB_HOST: ENV['RDS_ENDPOINT'])
    action :create
  end

  # cookbook_file "#{ENV['WP_CONTENT_DIR']}/wp-config.php" do
  #   source 'wp-config.php'
  #   owner 'www-data'
  #   group 'www-data'
  #   mode '0644'
  #   action :create
  # end

#---- RHEL ----
when 'rhel'
  bash 'copy wp content' do
    user 'root'
    code <<-EOH
    tar -xzf /tmp/latest.tar.gz -C /tmp
    rsync -av /tmp/wordpress/* $WP_CONTENT_DIR/
    rm -rf /tmp/latest.tar.gz /tmp/wordpress
    find $WP_CONTENT_DIR -type d -exec chmod 755 {} \;
    find $WP_CONTENT_DIR -type f -exec chmod 644 {} \;
    EOH
    action :run
  end

  # create wp-config.php file from template
  template "#{ENV['WP_CONTENT_DIR']}/wp-config.php" do
    source 'wp-config.php.erb'
    owner 'apache'
    group 'apache'
    mode '0644'
    variables(DB_NAME: ENV['DB_NAME'],
              USER: ENV['USER'],
              PASSWORD: ENV['PASSWORD'],
              DB_HOST: ENV['RDS_ENDPOINT'])
    action :create
  end
#   cookbook_file "#{ENV['WP_CONTENT_DIR']}/wp-config.php" do
#     source 'wp-config.php'
#     owner 'apache'
#     group 'apache'
#     mode '0644'
#     action :create
#   end
# end

# bash 'populate RDS and EC2 endpoints to wp-config' do
#   user 'root'
#   code <<-EOH
#   RDS_HOST="$(cat /tmp/rds_endpoint.txt)"
#   EC2_HOST="$(cat /tmp/ec2_endpoint.txt)"
#   WP_CONFIG_RDS="define( 'DB_HOST', '$RDS_HOST' );"
#   WP_CONFIG_HOME="define('WP_HOME','http://$EC2_HOST');"
#   WP_CONFIG_SITE_URL="define('WP_SITEURL','http://$EC2_HOST');"
#   sed -i -e "/DB_HOST/c\${WP_CONFIG_RDS}" $WP_CONTENT_DIR/wp-config.php
#   sed -i -e '/WP_HOME/d' -e '/WP_SITEURL/d' $WP_CONTENT_DIR/wp-config.php
#   echo "\n${WP_CONFIG_HOME}" >> $WP_CONTENT_DIR/wp-config.php
#   echo "${WP_CONFIG_SITE_URL}\n" >> $WP_CONTENT_DIR/wp-config.php
#   EOH
#   action :run
# end

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

# cookbook_file "#{ENV['WP_CONTENT_DIR']}/db_setup.sql" do
#   source 'db_setup.sql'
#   owner 'apache'
#   group 'root'
#   mode '0755'
#   action :create
#   ignore_failure true
# end

template "#{ENV['WP_CONTENT_DIR']}/db_setup.sql" do
  source 'db_setup.sql.erb'
  owner 'apache'
  group 'apache'
  mode '0644'
  variables(DB_HOST: ENV['RDS_ENDPOINT'],
            DB_NAME: ENV['DB_NAME'],
            EC2_ENDPOINT: ENV['EC2_ENDPOINT'])
  action :create
end

# TODO research kitchen testing locally (create toggle, install local mysql, etc...)
# Install todo plugin and merge everything to master

  # DB_NAME=$(grep "DB_NAME" $WP_CONTENT_DIR/wp-config.php | cut -d',' -f 2 | tr -d "';) ")
  # DB_USER=$(grep "DB_USER" $WP_CONTENT_DIR/wp-config.php | cut -d',' -f 2 | tr -d "';) ")
  # DB_PASSWORD=$(grep "DB_PASSWORD" $WP_CONTENT_DIR/wp-config.php | cut -d',' -f 2 | tr -d "';) ")
  # DB_HOST=$(grep "DB_HOST" $WP_CONTENT_DIR/wp-config.php | cut -d',' -f 2 | tr -d "';) ")
  # while ! mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD $DB_NAME < $WP_CONTENT_DIR/db_setup.sql; do echo "DB import failed, retrying..."; sleep 5; done

bash 'import db settings' do
  user 'root'
  code <<-EOH
  RETRIES=0
  while [ ! mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD $DB_NAME < $WP_CONTENT_DIR/db_setup.sql ] && [ "$RETRIES" -le 7 ]; do \
  echo "DB import failed, retrying..."; RETRIES=$((RETRIES+1)); sleep 5; done
  EOH
  action :run
end

# DB_NAME=$(grep "DB_NAME" $WP_CONTENT_DIR/wp-config.php | cut -d',' -f 2 | tr -d "';) ")
# DB_USER=$(grep "DB_USER" $WP_CONTENT_DIR/wp-config.php | cut -d',' -f 2 | tr -d "';) ")
# DB_PASSWORD=$(grep "DB_PASSWORD" $WP_CONTENT_DIR/wp-config.php | cut -d',' -f 2 | tr -d "';) ")
# DB_HOST=$(grep "DB_HOST" $WP_CONTENT_DIR/wp-config.php | cut -d',' -f 2 | tr -d "';) ")

bash 'verify wp login' do
  user 'root'
  code <<-EOH
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