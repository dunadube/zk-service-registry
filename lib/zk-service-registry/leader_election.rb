module ZK

  LeaderElectionRoot = "/leader_election"

  # 
  # Performs a leader/follower election
  #
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
      @on_become_leader_fns = []
    end

    # Connect to Zookeeper
    def connect
      @zk = @zk || ZooKeeper.new(:host => @hosts, :watcher => self)
      ZK::Utils.wait_until { @zk.connected? }
      
      # make sure there is a path for the election
      @zk.mkdir_p(@election_path)

      self
    end

    # Delete the election node
    def close
      @zk.delete(@my_path) if @my_path 
    end

    # Creates a sequence, ephemeral node under the elcetion_path using
    # the local ip address as the node name.
    # Zookeeper will return the full path and append a sequence number.
    # The node with the smallest sequence number is the leader.
    def elect
      # ZK will create the specified path and append a sequence number
     @my_path = @zk.create(:path => "#{@election_path}/#{@elector_name}_", :data => "", :ephemeral => true, :sequence => true)

     # ZK returns the full path created
     @my_path
    end

    # Return true if this instance is the leader
    # in the election.
    # It is the leader if this instances path
    # is the first in the participants array.
    def leader?
      if participants[0] == @my_path
        true
      else
        false
      end
    end

    # Return all paths of all participants in
    # the election and sort by sequence numbers.
    def participants
      # NOTE: You have to sort by sequence id yourself
      #   ZooKeeper won't do that
      @zk.children(@election_path).sort.map do |c|
        "#{@election_path}/#{c}" 
      end
    end

    # Find and return the path of the participant
    # this instance is following. 
    # nil if the instance is a leader.
    def following
      my_index = participants.find_index do |path|
        path == @my_path
      end
      return nil if my_index == 0  # must be the leader then

      return participants[my_index-1]
    end

    # Setup a subscription for the on_become_leader event
    # and schedule an action to be executed in this 
    # event
    def on_become_leader(&block)
      return if leader?

      @on_become_leader_fns << block
      @zk.get(:path => following, :watch => true)
    end

    private

    # Process ZK events
    def process(e)
      begin
        # puts "Event: " + e.inspect
        _process(e)
      rescue Exception => e
        puts("ERROR: #{e.message} - " + e.backtrace)
      end
    end

    def _process(e)
      return if e.type == Java::org.apache.zookeeper::Watcher::Event::EventType::None

      if e.type == Java::org.apache.zookeeper::Watcher::Event::EventType::NodeDeleted then
        if leader? then
          @on_become_leader_fns.each do |fn|
            fn.call
          end
        end
      end
    end

  end

end
