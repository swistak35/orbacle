module Orbacle
  module DataFlowGraph
    Block = Struct.new(:args, :result)
    BlockPass = Struct.new(:node)

    Position = Struct.new(:line, :character)
    PositionRange = Struct.new(:start, :end)
    class Location < Struct.new(:uri, :position_range)
      def start
        position_range&.start
      end

      def start_line
        start&.line
      end

      def start_character
        start&.character
      end

      def end
        position_range&.end
      end

      def end_line
        self.end&.line
      end

      def end_character
        self.end&.character
      end
    end
  end
end
