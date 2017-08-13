require 'thread'
require 'securerandom'

class RPC
  attr_reader :reply_queue
  attr_accessor :response, :call_id
  attr_reader :lock, :condition

  def initialize(channel, server_queue)
    @channel  = channel
    @exchange = channel.default_exchange

    @server_queue = server_queue
    @reply_queue  = channel.queue('', exclusive: true)

    @lock      = Mutex.new
    @condition = ConditionVariable.new
    that       = self

    @reply_queue.subscribe do |_delivery_info, properties, payload|
      if properties[:correlation_id] == that.call_id
        that.response = payload
        that.lock.synchronize { that.condition.signal }
      end
    end
  end

  def call(n)
    self.call_id = generate_uuid
    @exchange.publish(n.to_s, routing_key: @server_queue, correlation_id: call_id, reply_to: @reply_queue.name)

    lock.synchronize { condition.wait(lock) }
    response
  end

  private

  def generate_uuid
    SecureRandom.uuid
  end
end
