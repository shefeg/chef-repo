default['localmode'] = 'false'

case node['platform_family']
when 'debian'
  default['package_list']         = ['mysql-client', 'php7.0', 'php7.0-mysql', 'libapache2-mod-php7.0', 'php7.0-cli',
                                     'php7.0-cgi', 'php7.0-gd', 'apache2', 'apache2-utils', 'curl', 'rsync'
                                    ]
  default['apache']['service']    = 'apache2'
  default['apache']['user']       = 'www-data'
  default['apache']['config_dir'] = '/etc/apache2/sites-enabled'
  default['mysql']['package']     = 'mysql-server'
  default['mysql']['service']     = 'mysql'
  default['repositories'] = {
    'apt_repository' => ['php'],
    'uri'            => ['ppa:ondrej/php'],
    'components'     => ['main']
  }
when 'rhel'
  default['package_list']         = ['mysql-community-client', 'php', 'php-common', 'php-mysqlnd', 'php-gd', 'php-xml',
                                     'php-mbstring', 'php-pecl-mcrypt', 'php-xmlrpc', 'httpd', 'curl', 'httpd', 'rsync'
                                    ]
  default['apache']['service']    = 'httpd'
  default['apache']['user']       = 'apache'
  default['apache']['config_dir'] = '/etc/httpd/conf.d'
  default['mysql']['package']     = 'mysql-community-server'
  default['mysql']['service']     = 'mysqld'
  default['repositories'] = {
    'yum_repository' => ['epel',
                         'mysql57-community',
                         'remi-safe',
                         'remi-php72'],
    'description'    => ['Extra Packages for Enterprise Linux 7 - $basearch',
                         'MySQL 5.7 Community Server',
                         'Safe Remi\'s RPM repository for Enterprise Linux $releasever - $basearch',
                         'Remi\'s PHP 7.2RPM repository for Enterprise Linux 7 – $basearch'],
    'baseurl'        => ["http://download.fedoraproject.org/pub/epel/#{node['platform_version'].to_i}/$basearch/",
                         "http://repo.mysql.com/yum/mysql-5.7-community/el/#{node['platform_version'].to_i}/$basearch/",
                         "http://rpms.remirepo.net/enterprise/#{node['platform_version'].to_i}/safe/$basearch/",
                         "http://rpms.remirepo.net/enterprise/#{node['platform_version'].to_i}/php72/$basearch/"]
  }
end