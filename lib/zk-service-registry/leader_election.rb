#
# Add some convenience methods
#
class ZooKeeper

  #
  # Force create a path
  #
  def mkdir_p(path)
    path.split("/").slice(1..-1).inject("") do |current_path, part|
      current_path =  current_path + "/" + part

      create(:path => current_path, :data => "") if !exists(:path => current_path)

      current_path
    end
  end

  #
  # Delete a path recursively
  #
  def rm_r(path)
    children(path).each do |c|
      rm_r(path + "/" + c)
    end
    delete(path)
  end
end

module ZK

  LeaderElectionRoot = "/leader_election"

  class LeaderElection

    # 
    # Delete the election tree
    #
    def self.clear_all
      zk = ZooKeeper.new(:host => ZK::Config::Hosts)
      ZK::Utils.wait_until { zk.connected? }
      zk.rm_r(LeaderElectionRoot)
    end

    # Connect to Zookeeper and start an election
    #
    def self.start(service_name)
      instance = self.new(service_name).connect

      instance.elect

      instance
    end

    def initialize(service_name)
      @hosts = ZK::Config::Hosts
      @election_path = "#{LeaderElectionRoot}/#{service_name}"
      @elector_name = ZK::Utils.local_ip
    end

    def connect
      @zk = @zk || ZooKeeper.new(:host => @hosts)
      ZK::Utils.wait_until { @zk.connected? }
      
      # make sure there is a path for the election
      @zk.mkdir_p(@election_path)

      self
    end

    def elect
     @my_path = @zk.create(:path => "#{@election_path}/#{@elector_name}_", :data => "", :ephemeral => true, :sequence => true)

     @my_path
    end

    def leader?
      if participants[0] == @my_path
        true
      else
        false
      end
    end

    def participants
      # NOTE: You have to sort by sequence id yourself
      #   ZooKeeper won't do that
      @zk.children(@election_path).sort.map do |c|
        "#{@election_path}/#{c}" 
      end
    end

  end

end
