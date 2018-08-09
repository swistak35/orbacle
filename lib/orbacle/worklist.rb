# frozen_string_literal: true

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
      @handled_message_sends = Hash.new {|h,k| h[k] = [] }
      @nodes_counter = {}
      @nodes_mapping = {}
    end

    attr_reader :message_sends, :nodes, :handled_message_sends
    attr_writer :nodes

    def add_message_send(message_send)
      @message_sends << message_send
    end

    def enqueue_node(v)
      if !@nodes_mapping[v]
        @nodes.push(v, 1)
        @nodes_mapping[v] = true
      end
    end

    def pop_node
      e = @nodes.pop
      @nodes_mapping[e] = false
      e
    end

    def count_node(node)
      @nodes_counter[node] = @nodes_counter.fetch(node, 0) + 1
    end

    def limit_exceeded?(node)
      # @nodes_counter.fetch(node, 0) > 100
      false
    end

    def message_send_handled?(message_send)
      !handled_message_sends[message_send].empty?
    end

    def mark_message_send_as_handled(message_send, handled_type)
      handled_message_sends[message_send] << handled_type
    end

    def message_send_handled_by_type?(message_send, handled_type)
      handled_message_sends[message_send].include?(handled_type)
    end
  end
end
