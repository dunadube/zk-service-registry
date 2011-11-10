require File.join(File.dirname(__FILE__), %w[spec_helper])
require File.dirname(__FILE__) + "/../lib/zk-service-registry.rb"

describe ZK::ServiceInstance do
  before :all do
    ZookeeperTestServer.start
    wait_until { ZookeeperTestServer.running? }
    sleep 2
  end

  before :each do
    @svc_instance = ZK::ServiceInstance.advertise("online_status", "host01:port1")
  end

  it "can advertise a service and a service instance" do
    services = ZK::ServiceInstance.list_services

    services.size.should eql(1)
    services.first.instances.size.should eql(1)
    services.first.should be_a_kind_of(ZK::Service)
    services.first.instances.first.name.should eql("host01:port1")
  end

  it "can flag a service instance as up/down" do
    @svc_instance.down! 
    services = ZK::ServiceInstance.list_services
    services.first.instances.first.data[:state].should eql("down")
  end

  it "can lookup a service/service instance" do
    service_finder = ZK::ServiceFinder.find_and_watch("online_status")

    service_finder.instances.size.should eql(1)
    service_finder.instances.first.name.should eql("host01:port1")
  end

  it "can watch for new service instances" do
    service_finder = ZK::ServiceFinder.find_and_watch("online_status")
    new_instance = ZK::ServiceInstance.advertise("online_status", "host02:port2")

    sleep 1
    service_finder.instances.size.should eql(2)
  end

  it "can watch for removed  service instances" do
    service_finder = ZK::ServiceFinder.find_and_watch("online_status")
    new_instance = ZK::ServiceInstance.advertise("online_status", "host02:port2")
    new_instance.delete
    sleep 1

    service_finder.instances.size.should eql(1)
  end

  after :each do
    @svc_instance.delete if @svc_instance
  end

  after :all do
    ZookeeperTestServer.stop
    wait_until { !ZookeeperTestServer.running? }
  end
end
