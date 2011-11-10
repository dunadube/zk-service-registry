require 'json'
require File.dirname(__FILE__) + '/zk-service-registry/zookeeper'

module ZK 
  ServicePath = "/services"

  class Service
    attr_accessor :name, :instances

    def initialize(name, instances)
      @name = name
      @instances = instances
    end
  end

  class ServiceInstance
    @hosts = "localhost:2181"

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
      zk_service.create(:path => ZK::ServicePath, :data => "service registry") if !zk_service.exists(:path => ZK::ServicePath)
      zk_service.create(:path => ZK::ServicePath + "/#{svcname}", :data => svcname) if !zk_service.exists(:path => ZK::ServicePath + "/#{svcname}")
      if exists_service?(svcname, hostport) then
        delete_service(svcname, hostport)
      end
      svc_inst = self.new(zk_service, svcname, hostport)
      zk_service.create(:path => ZK::ServicePath + "/#{svcname}/#{hostport}", :data => svc_inst.data.to_json, :ephemeral => true) 

      svc_inst
    end


    # List all currently registered services
    # in zookeeper
    def self.list_services
      service_names = zk_service.children(:path => ZK::ServicePath)
      
      services = service_names.map do |svc_name|
        service_instance_names = zk_service.children(:path => ZK::ServicePath + "/" + svc_name)

        service_instances = service_instance_names.map do |svc_inst_name|
          res = zk_service.get(:path => ZK::ServicePath + "/" + svc_name + "/" + svc_inst_name)

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
      @zk.set(:path => ZK::ServicePath + "/#{@service_name}/#{@name}", :data => @data.to_json) 
    end

    # Mark the service as up
    def up!
      @data[:state] = :up
      @zk.set(:path => ZK::ServicePath + "/#{@service_name}/#{@name}", :data => @data.to_json) 
    end
    
    # ===
    private
    # ===

    def self.zk_service
      @zk1 =@zk1 ||  ZooKeeper.new(:host => @hosts)
    end

    def self.exists_service?(svcname, hostport)
      zk_service.exists(:path => ZK::ServicePath + "/#{svcname}/#{hostport}")
    end

    def self.delete_service(svcname, hostport)
      zk_service.delete(:path => ZK::ServicePath + "/#{svcname}/#{hostport}")
    end
  end

  class ServiceFinder
    @hosts = "localhost:2181"

    attr_accessor :instances

    def initialize
      @instances = []
      @lock = Mutex.new
    end

    def self.find_and_watch(svcname)
      service_finder = ServiceFinder.new

      path = ZK::ServicePath + "/#{svcname}"
      res = zk.children(:path => path, :watch => service_finder)

      service_instances = res.collect do |svc_inst_name|
        ret = zk.get(:path => path + "/" + svc_inst_name)

        ZK::ServiceInstance.new(zk, svcname, svc_inst_name, ret[0])
      end

      service_finder.instances = service_instances
      service_finder
    end

    def instances=(new_instances)
      @lock.synchronize do
        @instances = new_instances 
      end
    end

    def instances
      @lock.synchronize do
        ret = @instances.clone
      end
    end

    private

    def self.zk
      @zk =@zk ||  ZooKeeper.new(:host => @hosts)
    end

    # Event callback for Zookeeper events
    def process(e)
      p e
      # Something changed in Zookeepr so 
      # refresh the service instances
      if e.type == 4 then
        new_service_finder = self.class.find_and_watch(e.data)

        self.instances = new_service_finder.instances

      end
    end

  end
end

