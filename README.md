zk-service-registry
==========================

zk-service-registry is a JRuby client library for the popular [Apache Zookeeper Service](http://zookeeper.apache.org/) project. The gem is intended to be used by clients who want to consume services as well as by service instances who want to advertise their services to clients. 

## Getting started

Check out the project and install the gem on your machine using

    bundle install
    bundle exec rake install      # install gem

Before running the examples make sure you have Zookeeper installed and running on localhost.

In the examples subdirectory you find two instances of a simple demo http service which registers a service called "foo".
Start the service instances using

    bundle exec foo_service1.rb
    bundle exec foo_service2.rb

Now start the demo client

    bundle exec client.rb

You should see the client making requests randomly to both service instances. If you take down one instance the client will automatically switch to the remaining instance.

## How it works

Service instances advertise services on Zookeeper using ephemeral nodes. The service registry uses a hierarchical system of nodes which looks like this:

    /services
        |
        + SERVICE_NAME
              |
              + INSTANCE01_HOST ":" INSTANCE01_PORT
              |
              + INSTANCE02_HOST ":" INSTANCE02_PORT
        + ANOTHER_SERVICE_NAME
              |
              + ...

As the instance registrations are ephemeral even if an instance dies Zookeeper will take notice of it and notify other clients and services relying on the service instance.

