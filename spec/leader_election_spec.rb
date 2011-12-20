require File.join(File.dirname(__FILE__), %w[spec_helper])
require File.dirname(__FILE__) + "/../lib/zk-service-registry"

describe ZK::LeaderElection do

  before :all do
    ZK::ZookeeperServer.start
    ZK::Utils.wait_until { ZK::ZookeeperServer.running? }

    # clear all nodes before starting
    ZK::LeaderElection.clear_all
    # create a couple of election nodes
    @nodes = (1..3).map { |i| ZK::LeaderElection.start("redis") }
    @leader = @nodes.select { |n| n.leader? }.first
    @followers = @nodes.select { |n| !n.leader? }
  end

  after :all do
    ZK::ZookeeperServer.stop
    ZK::Utils.wait_until { !ZK::ZookeeperServer.running? }
  end

  it "should have 3 participants" do
    @nodes.first.participants.size.should eql(3)
  end

  it "should have a leader who does not follow" do
    @leader.following.should eql(nil)
  end

  it "should have followers who follow someone" do
    @followers.size.should eql(2)
    @followers.each { |f| f.following.should_not eql(nil) }
  end

  it "should do something if the leader fails" do
    become_leader = false
    @followers.first.on_become_leader { become_leader = true }
    @leader.close
    sleep 2

    become_leader.should eql(true)
  end

end
