default['localmode'] = 'false'
default['debian']['repositories'] = {
    "apt_repository" => ['php'],
    "uri"            => ['ppa:ondrej/php'],
    "components"     => ['main']
}
default['rhel']['repositories'] = {
    "yum_repository" => ['epel', 
                         'mysql57-community',
                         'remi-safe',
                         'remi-php72'],
    "description"    => ['Extra Packages for Enterprise Linux 7 - $basearch',
                         'MySQL 5.7 Community Server',
                         'Safe Remi\'s RPM repository for Enterprise Linux $releasever - $basearch',
                         'Remi\'s PHP 7.2RPM repository for Enterprise Linux 7 – $basearch'],
    "baseurl"        => ["http://download.fedoraproject.org/pub/epel/#{node['platform_version'].to_i}/$basearch/",
                         "http://repo.mysql.com/yum/mysql-5.7-community/el/#{node['platform_version'].to_i}/$basearch/",
                         "http://rpms.remirepo.net/enterprise/#{node['platform_version'].to_i}/safe/$basearch/",
                         "http://rpms.remirepo.net/enterprise/#{node['platform_version'].to_i}/php72/$basearch/"]
}