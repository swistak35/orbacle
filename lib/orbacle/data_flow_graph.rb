module Orbacle
  module DataFlowGraph
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
