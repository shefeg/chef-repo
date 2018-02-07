#
# Cookbook:: nginx
# Recipe:: default
#
# Copyright:: 2018, The Authors, All Rights Reserved.

case node['platform_family']
when 'debian'
  include_recipe 'nginx::ubuntu'
when 'rhel'
  include_recipe 'nginx::centos'
end

