module ZK
  #
  # Convenience methods to perform a 
  # service registration
  #
  class Registration

    #
    # Register a service specified by svcname
    # under given ip and port
    #
    def self.register(svcname, ip, port)
      ip = ZK::Utils.local_ip if ip == '0.0.0.0'
      ZK::ServiceInstance.advertise(svcname, ip + ':' + port.to_s)
    end

    # 
    # Deferred register when condition becomes true
    # (e. g. wait for a service start in a sinatra 
    # application)
    #
    def self.register_deferred(svcname, ip, port, &block)
      Thread.new{
        (sleep 0.1 until yield) if block_given?
        $LOG.info("zk-service-registry") { "Registering service #{svcname} at #{ip}:#{port} with ZooKeeper" }
        register(svcname, ip, port)
      }
    end
  end


  # A (logical) service can have multiple 
  # instances (physical) running on different
  # ports and hosts.
  #
  class Service
    attr_accessor :name, :instances

    def initialize(name, instances)
      @name = name
      @instances = instances
    end
  end

  # ServiceInstance is the class to use
  # if you want to register services with
  # Zookeeper
  class ServiceInstance
    attr_accessor :service_name, :name, :data

    def initialize(zk_inst, svcname, name, data=nil)
      @zk = zk_inst
      @service_name = svcname
      @name = name
      @data = {:state => :up}
      @data = JSON.parse(data,:symbolize_names => true) if data && !data.empty?
    end

    #
    # Registers a service instance with Zookeeper using ephemeral nodes
    # which means the registration will decay after a timeout period
    # if the registering client looses connection to Zookeeper.
    #
    # # Parameters
    # * svcname: the servicename under which the instance will be registered
    # * hostport: a String containing the host (ip address) and port 
    #     under which the instance can be reached
    #
    # # Example
    #     # Register an instance of service 'online-status' running on host biz01 
    #     # listening on port 12345
    #     ServiceInstance.advertise("online-status", "biz01:12345")
    #
    def self.advertise(svcname, hostport)
      prepare_dir_structure(svcname)

      # Delete an existing registration first, otherwise
      # Zookeeper will throw an exception creating the registration
      if exists_service?(svcname, hostport) then
        delete_service_instance(svcname, hostport)
      end

      svc_inst = self.new(zk_service, svcname, hostport)
      zk_service.create(:path => ZK::Config::ServicePath + "/#{svcname}/#{hostport}", :data => svc_inst.data.to_json, :ephemeral => true)

      svc_inst
    end

    #
    # Like advertise but instead of an ephemeral node a persistent node will be used, i. e. the
    # service registration will persist if the registering client looses connection or 
    # regularly disconnects from Zookeeper.
    #
    def self.register(svcname, hostport)
      prepare_dir_structure(svcname)

      # Delete an existing registration first, otherwise
      # Zookeeper will throw an exception creating the registration
      if exists_service?(svcname, hostport) then
        delete_service_instance(svcname, hostport)
      end

      svc_inst = self.new(zk_service, svcname, hostport)
      svc_inst.data[:static] = true
      zk_service.create(:path => ZK::Config::ServicePath + "/#{svcname}/#{hostport}", :data => svc_inst.data.to_json, :ephemeral => false)

      svc_inst
    end


    #
    # List all currently registered services in zookeeper
    #
    def self.list_services
      service_names = []
      service_names = zk_service.children(:path => ZK::Config::ServicePath) if zk_service.exists(ZK::Config::ServicePath)

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

    #  
    # Remove the entry for the service completely
    #
    def self.clear_service(svcname)
      zk_service.rm_r(ZK::Config::ServicePath + "/" + svcname)
    end

    # 
    # Remove a service instance entry.
    # The service and instance path must be given (e. g. foo/bar:12345 , 
    # where foo is the service name and bar:12345 the instance name)
    def self.unregister_instance(service_and_instance)
      zk_service.rm_r(ZK::Config::ServicePath + "/" + service_and_instance)
    end

    # ===
    # instance methods
    # ===

    # Remove the service instance from
    # zookeeper
    def delete
      self.class.delete_service_instance(@service_name, @name)
    end

    # Mark the service as down
    def down!
      @data[:state] = :down
      save!
    end

    # Mark the service as up
    def up!
      @data[:state] = :up
      save!
    end

    # Save instance data to Zookeeper
    def save!
      @zk.set(:path => ZK::Config::ServicePath + "/#{@service_name}/#{@name}", :data => @data.to_json)
    end

    # Return all node data from Zookeeper
    def meta
      data,stat = @zk.get(:path => ZK::Config::ServicePath + "/#{@service_name}/#{@name}")
      stat
    end

    # ===
    private
    # ===

    def self.zk_service
      @zk1 =@zk1 ||  ZooKeeper.new(:host => ZK::Config::Hosts.join(","))

      ZK::Utils.wait_until { @zk1.connected? }

      @zk1
    end

    def self.exists_service?(svcname, hostport)
      zk_service.exists(:path => ZK::Config::ServicePath + "/#{svcname}/#{hostport}")
    end

    def self.delete_service_instance(svcname, hostport)
      zk_service.delete(:path => ZK::Config::ServicePath + "/#{svcname}/#{hostport}")
    end
    
    # Prepare the service registration 'directory' layout in 
    # Zookeeper
    def self.prepare_dir_structure(svcname)
      zk_service.mkdir_p(ZK::Config::ServicePath + "/#{svcname}")
    end
  end

end
