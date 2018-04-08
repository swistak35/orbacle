module Orbacle
  class Worklist
    MessageSend = Struct.new(:message_send, :send_obj, :send_args, :send_result, :block)
    SuperSend = Struct.new(:send_args, :send_result, :block)
    Super0Send = Struct.new(:send_result, :block)

    def initialize
      @message_sends = []
    end

    attr_reader :message_sends

    def add_message_send(message_send)
      @message_sends << message_send
    end
  end
end
