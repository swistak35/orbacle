require 'fc'

module Orbacle
  class Worklist
    BlockNode = Struct.new(:node)
    BlockLambda = Struct.new(:lambda_id)
    MessageSend = Struct.new(:message_send, :send_obj, :send_args, :send_result, :block, :location)
    SuperSend = Struct.new(:send_args, :send_result, :block, :method_id, :location)

    def initialize
      @message_sends = Set.new
      @nodes = FastContainers::PriorityQueue.new(:max)
      @handled_message_sends = Set.new
      @nodes_counter = {}
    end

    attr_reader :message_sends, :nodes, :handled_message_sends
    attr_writer :nodes

    def add_message_send(message_send)
      @message_sends << message_send
    end

    def enqueue_node(v)
      @nodes.push(v, 1)
    end

    def pop_node
      @nodes.pop
    end

    def count_node(node)
      @nodes_counter[node] = @nodes_counter.fetch(node, 0) + 1
    end

    def limit_exceeded?(node)
      # @nodes_counter.fetch(node, 0) > 100
      false
    end

    def message_send_handled?(message_send)
      handled_message_sends.include?(message_send)
    end

    def mark_message_send_as_handled(message_send)
      handled_message_sends << message_send
    end
  end
end
