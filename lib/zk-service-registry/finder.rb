
module ZK
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

    def initialize(hosts = ZK::Config::Hosts.join(","))
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
        $LOG.error("#{e.message} - " + e.backtrace)
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
