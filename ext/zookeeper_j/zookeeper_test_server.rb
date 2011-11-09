class ZookeeperTestServer

  ZKHOME = File.dirname(__FILE__) + "/zookeeper-3.3.3"
  
  def self.running?
    `ps ax | grep zookeeper`.include?("zookeeper")
  end

  def self.start(background=true)
    set_log_level
    FileUtils.remove_dir("/tmp/zookeeper", true)
    FileUtils.mkdir_p("/tmp/zookeeper/server1/data")
    if background
      thread = Thread.new do
        `#{ZKHOME}/bin/zkServer.sh start`
      end
    else
      `#{ZKHOME}/bin/zkServer.sh start`
    end
  end

  def self.wait_til_started
    while !running?
      sleep 1
    end
    # make sure zookeeper is really ready
    sleep 2
  end

  def self.wait_til_stopped
    while running?
      sleep 1
    end
  end

  def self.stop
    `#{ZKHOME}/bin/zkServer.sh stop`
    FileUtils.remove_dir("/tmp/zookeeper", true)
  end

  def self.status
    `#{ZKHOME}/bin/zkServer.sh status`
  end
  
  def self.set_log_level
    require File.dirname(__FILE__) + '/log4j-1.2.15.jar'
    import org.apache.log4j.Logger
    import org.apache.log4j.Level
    Logger.getRootLogger().set_level(Level::OFF)
  end
  
end
