# encoding: utf-8
require "logstash/outputs/base"
require "logstash/namespace"
require "resque"

class LogStash::Outputs::Resque < LogStash::Outputs::Base
  config_name "resque"

  config :redis_url, validate: :string, required: true
  config :jobs_map, validate: :hash, list: true, required: true

  concurrency :single
  
  public
  def register
  	@logger.debug("in register for LogStash::Outputs::Resque")
  	@jobs_map.each do |event|
  		unless ['filter', 'job', 'queue'].all? { |k| event.has_key?(k) }
			@logger.error("Bad jobs_map entry: #{event.inspect}") 
  		end
  	end
  	Resque.redis = @redis_url
  end # def register

 
  public
  def receive(event)
    @logger.debug("Event received", event: event.inspect)
  	@jobs_map.select do |item|
  		begin
  			eval(item['filter'])
  		rescue
  			@logger.error("Failed evaluation filter #{filter} on event #{event.inspect}: #{$!}")
  			false
  		end
  	end.each do |item|
  		@logger.debug("Sending event #{event.to_hash.inspect} to #{item.inspect}")
  		Resque.push(item['queue'], :class => item['job'], :args => [event.to_hash])
  	end
  end # def event

end # class LogStash::Outputs::Resque
