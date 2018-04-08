module Orbacle
  module DataFlowGraph
    ProcessError = Class.new(StandardError)

    MessageSend = Struct.new(:message_send, :send_obj, :send_args, :send_result, :block)
    SuperSend = Struct.new(:send_args, :send_result, :block)
    Super0Send = Struct.new(:send_result, :block)

    Block = Struct.new(:args, :result)
    BlockPass = Struct.new(:node)
    CurrentlyAnalyzedKlass = Struct.new(:klass, :method_visibility)

    Position = Struct.new(:line, :character)
    PositionRange = Struct.new(:start, :end)
    class Location < Struct.new(:uri, :position_range)
      def start
        position_range&.start
      end

      def end
        position_range&.end
      end
    end
  end
end
