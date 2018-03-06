#
# Cookbook:: wp-app
# Spec:: default
#
# Copyright:: 2018, The Authors, All Rights Reserved.

require 'spec_helper'

describe 'wp-app::default' do
  context 'When all attributes are default, on Ubuntu 16.04' do
    let(:chef_run) do
      # for a complete list of available platforms and versions see:
      # https://github.com/customink/fauxhai/blob/master/PLATFORMS.md
      runner = ChefSpec::ServerRunner.new(platform: 'ubuntu', version: '16.04')
      runner.converge(described_recipe)
    end
    
    it 'converges successfully' do
      expect { chef_run }.to_not raise_error
    end

    it 'installs a apt_repositories with an explicit action' do
      expect(chef_run).to add_apt_repository('php')
    end
  end

  context 'When all attributes are default, on CentOS 7.4.1708' do
    let(:chef_run) do
      # for a complete list of available platforms and versions see:
      # https://github.com/customink/fauxhai/blob/master/PLATFORMS.md
      runner = ChefSpec::ServerRunner.new(platform: 'centos', version: '7.4.1708')
      runner.converge(described_recipe)
    end
    
    # TODO: add yum_repository test
    # it 'creates a yum_repository with add action' do
    #   expect(chef_run).to add_yum_repository('epel')
    # end
    
    it 'test SELINUX' do
      expect(chef_run).to run_execute('setenforce 0')
      expect(chef_run).to run_execute('apachectl configtest')
    end
    # it 'test apachectl' do
    #   expect(chef_run).to run_execute('apachectl configtest').with(user: 'root')
    #   expect(chef_run).to_not run_execute('apachectl configtest').with(user: 'vagrant')
    # end
    # it 'runs a execute with an explicit action' do
    #   expect(chef_run).to run_execute('explicit_action')
    # end
  
    # it 'runs a execute with attributes' do
      
    # end
  
    # it 'runs a execute when specifying the identity attribute' do
    #   expect(chef_run).to run_execute('identity_attribute')
    # end

    # it 'converges successfully' do
    #   expect { chef_run }.to_not raise_error
    # end
  end
end
