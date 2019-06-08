# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/resque"
require "logstash/codecs/plain"
require "logstash/event"

describe LogStash::Outputs::Resque do
  describe "ship lots of events to a file" do
    LogStash::Logging::Logger::configure_logging("DEBUG")

    event_count = 2

    config <<-CONFIG
    input {
      generator {
        message => '{"event": "test_event"}'
        count => #{event_count}
        type => "generator"
      }
    }
    filter {
      json {
        source => "message"
        remove_field => "message"
      }
    }
    output {
      resque {
        redis_url => "localhost:6379"
        jobs_map => [
          {
            filter => "event.get('event') == 'test_event'"
            job => "TestJob"
            queue => "default"
          }
        ]
      }
    }
    CONFIG

    Resque.redis.del "queue:default"

    agent do
      jobs = Resque.peek('default', 0, event_count + 1)
      
      insist { jobs.count } == event_count
      jobs.each do |job|
        insist { job["class"] } == "TestJob"
        insist { job["args"].first["event"] } == "test_event"
      end

    end # agent
  end

end
