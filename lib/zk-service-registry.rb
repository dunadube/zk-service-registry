require 'json'
require File.dirname(__FILE__) + '/zk-service-registry/zookeeper'

# Default host configuration
module ZK::Config
  # Zookeeper Hosts: Can be a comma separated list of host and ports
  Hosts = "localhost:2181" if !const_defined?(:Hosts)
  
  # Service registrations will be created under this path
  ServicePath = "/services"
end

module ZK::Utils

  def self.wait_until(timeout=10, &block)
    time_to_stop = Time.now + timeout
    until yield do 
      break unless Time.now < time_to_stop
    end
  end
end

module ZK 


  class Service
    attr_accessor :name, :instances

    def initialize(name, instances)
      @name = name
      @instances = instances
    end
  end

  class ServiceInstance
    @hosts = ZK::Config::Hosts 

    attr_accessor :service_name, :name, :data 

    def initialize(zk_inst, svcname, name, data=nil)
      @zk = zk_inst
      @service_name = svcname
      @name = name
      @data = {:state => :up}
      @data = JSON.parse(data,:symbolize_names => true) if data && !data.empty?
    end

    # Factory method which advertises
    # a new service instance on zookeeper
    def self.advertise(svcname, hostport)
      zk_service.create(:path => ZK::Config::ServicePath, :data => "service registry root") if !zk_service.exists(:path => ZK::Config::ServicePath)
      zk_service.create(:path => ZK::Config::ServicePath + "/#{svcname}", :data => svcname) if !zk_service.exists(:path => ZK::Config::ServicePath + "/#{svcname}")

      # Delete an existing registration first, otherwise
      # Zookeeper will throw an exception creating the registration
      if exists_service?(svcname, hostport) then
        delete_service(svcname, hostport)
      end

      svc_inst = self.new(zk_service, svcname, hostport)
      zk_service.create(:path => ZK::Config::ServicePath + "/#{svcname}/#{hostport}", :data => svc_inst.data.to_json, :ephemeral => true) 

      svc_inst
    end


    # List all currently registered services
    # in zookeeper
    def self.list_services
      service_names = zk_service.children(:path => ZK::Config::ServicePath)
      
      services = service_names.map do |svc_name|
        service_instance_names = zk_service.children(:path => ZK::Config::ServicePath + "/" + svc_name)

        service_instances = service_instance_names.map do |svc_inst_name|
          res = zk_service.get(:path => ZK::Config::ServicePath + "/" + svc_name + "/" + svc_inst_name)

          ZK::ServiceInstance.new(zk_service, svc_name, svc_inst_name, res[0])
        end
       
        ZK::Service.new(svc_name, service_instances)
      end
      services
    end

    # ===
    # instance methods
    # ===

    # Remove the service instance from
    # zookeeper
    def delete
      self.class.delete_service(@service_name, @name)
    end

    # Mark the service as down
    def down!
      @data[:state] = :down
      @zk.set(:path => ZK::Config::ServicePath + "/#{@service_name}/#{@name}", :data => @data.to_json) 
    end

    # Mark the service as up
    def up!
      @data[:state] = :up
      @zk.set(:path => ZK::Config::ServicePath + "/#{@service_name}/#{@name}", :data => @data.to_json) 
    end
    
    # ===
    private
    # ===

    def self.zk_service
      @zk1 =@zk1 ||  ZooKeeper.new(:host => @hosts)

      ZK::Utils.wait_until { @zk1.connected? }

      @zk1
    end

    def self.exists_service?(svcname, hostport)
      zk_service.exists(:path => ZK::Config::ServicePath + "/#{svcname}/#{hostport}")
    end

    def self.delete_service(svcname, hostport)
      zk_service.delete(:path => ZK::Config::ServicePath + "/#{svcname}/#{hostport}")
    end
  end

  # Connect to zookeeper service registry 
  # and watch for services coming online or
  # going offline.
  # Usage:
  #     finder = ServiceFinder.new.connect
  #     finder.watch("fooservice")
  #     ... do something with finder.instances
  #     finder.close
  #
  class ServiceFinder
    attr_accessor :instances

    def initialize(hosts = ZK::Config::Hosts)
      @hosts = hosts 
      @instances = []
      @lock = Mutex.new
    end

    def connect
      @zk = @zk || ZooKeeper.new(:host => @hosts, :watcher => self)
      ZK::Utils.wait_until { @zk.connected? }
      self
    end

    def watch(svcname)
      path = ZK::Config::ServicePath + "/#{svcname}"
      res = @zk.children(:path => path, :watch => true)

      service_instances = res.collect do |svc_inst_name|
        ret = @zk.get(:path => path + "/" + svc_inst_name, :watch => true)

        ZK::ServiceInstance.new(@zk, svcname, svc_inst_name, ret[0])
      end

      @lock.synchronize do
        @instances = service_instances
      end

    end

    def close
      if @zk then
        @zk.close
        ZK::Utils.wait_until { @zk.closed? }
        @zk = nil
      end
    end

    def instances
      @lock.synchronize do
        ret = @instances.clone
      end
    end

    private

    def process(e)
      begin
        _process(e)
      rescue Exception => e
        puts("ERROR: #{e.message} - " + e.backtrace)
      end
    end

    # Event callback for Zookeeper events
    # EventNodeCreated           = 1
    # EventNodeDeleted           = 2
    # EventNodeDataChanged       = 3
    # EventNodeChildrenChanged   = 4
    def _process(e)
      return if e.type == Java::org.apache.zookeeper::Watcher::Event::EventType::None

      # Something changed in Zookeepr so 
      # refresh the service instances
      if e.type == Java::org.apache.zookeeper::Watcher::Event::EventType::NodeChildrenChanged then
        # $LOG.debug("Children changed on " + e.path)
        watch(e.path.split("/").last) 
      else
        # $LOG.debug("Node create/deleted on " + e.path)
        watch(e.path.split("/")[-2]) 
      end
    end

  end
end

