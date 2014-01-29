require 'spec_helper'
require 'dcell/registries/etcd_adapter'

describe DCell::Registry::EtcdAdapter, :pending => ENV["CI"] && "no zookeeper" do
  subject { DCell::Registry::EtcdAdapter.new :server => 'localhost', :env => 'test' }
  it_behaves_like "a DCell registry"
end
