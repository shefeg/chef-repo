#
# Cookbook:: nginx
# Recipe:: default
#
# Copyright:: 2018, The Authors, All Rights Reserved.

case node['platform_family']
when 'rhel'
  package 'epel-release' do
    action [:install]
  end
end

package 'nginx' do
  action [:install]
end

service 'nginx' do
  action [:enable]
end

case node['platform_family']
when 'debian'
  %w( /var/www /var/www/site1 /var/www/site2 ).each do |path|
    directory path do
      mode '0755'
      owner 'www-data'
      group 'www-data'
    end
  end

  file '/var/www/site1/index.html' do
    content 'Hello world 1'
    mode '0755'
    owner 'www-data'
    group 'www-data'
  end

  file '/var/www/site2/index.html' do
    content 'Hello world 2'
    mode '0755'
    owner 'www-data'
    group 'www-data'
  end
when 'rhel'
  %w( /var/www /var/www/site1 /var/www/site2 ).each do |path|
    directory path do
      mode '0755'
      owner 'nginx'
      group 'nginx'
    end
  end

  file '/var/www/site1/index.html' do
    content 'Hello world 1'
    mode '0755'
    owner 'nginx'
    group 'nginx'
  end

  file '/var/www/site2/index.html' do
    content 'Hello world 2'
    mode '0755'
    owner 'nginx'
    group 'nginx'
  end
end

directory '/etc/nginx/sites-available' do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

file '/etc/nginx/sites-available/site1.conf' do
  content <<-EOF
server {
    listen       80;
    listen       [::]:80 ;
    server_name  site1.com www.site1.com;
    root         /var/www/site1;
    index  index.html index.htm;
    location / {
    }
    error_page 404 /404.html;
    location = /40x.html {
    }
    error_page 500 502 503 504 /50x.html;
        location = /50x.html {
    }
}
	EOF
  mode '0755'
  owner 'root'
  group 'root'
end

file '/etc/nginx/sites-available/site2.conf' do
  content <<-EOF
server {
    listen       80;
    listen       [::]:80 ;
    server_name  site2.com www.site2.com;
    root         /var/www/site2;
    index  index.html index.htm;
    location / {
    }
    error_page 404 /404.html;
    location = /40x.html {
    }
    error_page 500 502 503 504 /50x.html;
        location = /50x.html {
    }
}
	EOF
  mode '0755'
  owner 'root'
  group 'root'
end

case node['platform_family']
when 'debian'
  bash 'create symlinks for sites configs' do
    user 'root'
    code <<-EOF
		    ln -sf /etc/nginx/sites-available/site1.conf /etc/nginx/sites-enabled/site1.conf
		    ln -sf /etc/nginx/sites-available/site2.conf /etc/nginx/sites-enabled/site2.conf
        EOF
  end
  file '/etc/nginx/sites-enabled/default' do
    action :delete
  end
when 'rhel'
  bash 'create symlinks for sites configs' do
    user 'root'
    code <<-EOF
           	ln -sf /etc/nginx/sites-available/site1.conf /etc/nginx/conf.d/site1.conf
           	ln -sf /etc/nginx/sites-available/site2.conf /etc/nginx/conf.d/site2.conf
		EOF
  end
end

service 'nginx' do
  action [:restart]
end

bash 'verify sites availability' do
  user 'root'
  code <<-EOF
    echo -e "$(hostname -I | cut -d' ' -f1) site1.com\n$(hostname -I | cut -d' ' -f1) site2.com" >> /etc/hosts
    if [[ $(curl site1.com) = *"Hello world"* ]] && [[ $(curl site2.com) = *"Hello world"* ]]; then
        echo "SUCCESS!"
        sed -i '/site*/d' /etc/hosts
    else
        sed -i '/site*/d' /etc/hosts
        exit 1
    fi
    EOF
end
