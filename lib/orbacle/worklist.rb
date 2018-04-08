module Orbacle
  class Worklist
    MessageSend = Struct.new(:message_send, :send_obj, :send_args, :send_result, :block)
    SuperSend = Struct.new(:send_args, :send_result, :block)
    Super0Send = Struct.new(:send_result, :block)

    def initialize
      @message_sends = Set.new
      @nodes = Set.new
      @handled_message_sends = Set.new
    end

    attr_reader :message_sends, :nodes, :handled_message_sends
    attr_writer :nodes

    def add_message_send(message_send)
      @message_sends << message_send
    end

    def enqueue_node(v)
      @nodes << v
    end
  end
end
