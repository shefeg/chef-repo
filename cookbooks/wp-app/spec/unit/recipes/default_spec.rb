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
  # end
  end
  context 'When all attributes are default, on CentOS 7.4.1708' do
    # let(:chef_run) do
    #   # for a complete list of available platforms and versions see:
    #   # https://github.com/customink/fauxhai/blob/master/PLATFORMS.md
    #   runner = ChefSpec::ServerRunner.new(platform: 'centos', version: '7.4.1708')
    #   runner.converge(described_recipe)
    # end
    # let(:node) { chef_run.node }
    
    let(:runner) { ChefSpec::ServerRunner.new(platform: 'centos', version: '7.4.1708') }
    let(:node) { runner.node }
    let(:chef_run) do
      # node.normal['repo'] = 'epel'
      runner.converge(described_recipe)
    end
    
    
    it 'converges successfully' do
      expect { chef_run }.to_not raise_error
    end
    
    # TODO: add yum_repository test
    it "creates yum_repository add action" do
      expect(chef_run).to add_yum_repository('epel')
      expect(chef_run).to add_yum_repository('mysql57-community')
    end
    # it "creates yum_repository add action" do
    #   expect(chef_run).to add_yum_repository('mysql57-community')
    # end
    # it "creates yum_repository add action" do
    #   expect(chef_run).to add_yum_repository('remi-safe')
    # end
    # it "creates yum_repository add action" do
    #   expect(chef_run).to add_yum_repository("#{node['repositories']['yum_repository'][3]}")
    # end
    
    # it 'runs a execute setenforce 0' do
    #   expect(chef_run).to run_execute('setenforce 0').with(user: 'root')
    #   expect(chef_run).to_not run_execute('setenforce 0').with(user: 'vagrant')
    # end

    # it 'runs a execute apachectl configtest' do
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


  end
end
