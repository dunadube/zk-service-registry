require File.join(File.dirname(__FILE__), %w[spec_helper])
require File.dirname(__FILE__) + "/../lib/zk-service-registry"

describe ZK::LeaderElection do

  before :all do
    ZK::ZookeeperServer.start
    ZK::Utils.wait_until { ZK::ZookeeperServer.running? }

    ZK::LeaderElection.clear_all
    @nodes = (1..3).map { |i| ZK::LeaderElection.start("redis") }
  end

  after :all do
    ZK::ZookeeperServer.stop
    ZK::Utils.wait_until { !ZK::ZookeeperServer.running? }
  end

  it "should have 3 participants" do
    @nodes.first.participants.size.should eql(3)
  end

  it "should have one leader" do
    number_of_leaders = @nodes.inject(0) do |sum, n|
      if n.leader?
        sum + 1
      else 
        sum
      end
    end

    number_of_leaders.should eql(1)
  end

end
