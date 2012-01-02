require File.join(File.dirname(__FILE__), %w[spec_helper])
require File.dirname(__FILE__) + "/../lib/zk-service-registry.rb"

describe ZK::ServiceInstance do
  before :all do
    ZK::ZookeeperServer.start
    ZK::Utils.wait_until { ZK::ZookeeperServer.running? }

    # make sure there are no
    # services registered
    ZK::ServiceInstance.list_services.each do |svc|
      svc.instances.each do |inst|
        inst.delete
      end
    end

  end

  after :all do
    ZK::ZookeeperServer.stop
    ZK::Utils.wait_until { !ZK::ZookeeperServer.running? }
  end

  def service_from_list(svcname)
    ZK::ServiceInstance.list_services.select { |svc| svc.name == svcname }.first
  end

  # ############################################
  # TESTS start here
  # ############################################
  context "advertising dynamic services (i. e. they may come and go at any time)" do

    before(:all) do
      @service_name = "online-status"
      @dynamic_service = ZK::ServiceInstance.advertise(@service_name, "host01:port1")
      @service_finder = ZK::ServiceFinder.new.connect
    end

    after(:all) do
      ZK::ServiceInstance.clear_service(@service_name)
    end

    subject do
      @dynamic_service
    end

    it "can advertise a service and a service instance" do
      service = service_from_list(@service_name)

      service.instances.size.should eql(1)
      service.should be_a_kind_of(ZK::Service)
      service.instances.first.name.should eql("host01:port1")
    end

    it "can flag a service instance as up/down" do
      @dynamic_service.down! 
      service = service_from_list(@service_name)
      service.instances.first.data[:state].should eql("down")
    end

    it "can lookup a service/service instance" do
      @service_finder.watch(@service_name)

      @service_finder.instances.size.should eql(1)
      @service_finder.instances.first.name.should eql("host01:port1")
    end


    it "can watch for removed  service instances" do
      @service_finder.watch(@service_name)
      new_instance = ZK::ServiceInstance.advertise(@service_name, "host02:port2")
      sleep 1
      new_instance.delete
      sleep 2

      @service_finder.instances.size.should eql(1)
    end

    it "can watch for new service instances" do
      @service_finder.watch(@service_name)
      new_instance = ZK::ServiceInstance.advertise(@service_name, "host02:port2")

      sleep 3
      @service_finder.instances.size.should eql(2)
    end
  end

  context "register static services (for infrastructure like dbs, caches, MOM)"do
    before(:all) do
      @static_service = ZK::ServiceInstance.register("rabbitmq", "host01:port1")
      @static_service.data[:user] = "user"
      @static_service.data[:pass] = "seekrit"
      @static_service.save!

      @rabbitmq_finder = ZK::ServiceFinder.new.connect
      @rabbitmq_finder.watch("rabbitmq")
    end

    after(:all) do
      ZK::ServiceInstance.clear_service("rabbitmq")
    end

    subject do
      @static_service
    end

    it "registered one instance of the static service" do
      @rabbitmq_finder.instances.size.should eql(1)
    end

    it "set all the metadata for the service instance" do
      @rabbitmq_finder.instances.first.data[:user].should eql("user")
      @rabbitmq_finder.instances.first.data[:pass].should eql("seekrit")
    end

    it "can change the metadata" do
      @static_service.data[:user] = "user_changed"
      @static_service.save!
      sleep 1
      @rabbitmq_finder.instances.first.data[:user].should eql("user_changed")
    end
  end

end
