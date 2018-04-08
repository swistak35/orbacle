module Orbacle
  module DataFlowGraph
    class Node
      def initialize(type, params = {}, location = nil)
        @type = type
        @params = params
        @location = location
      end

      attr_reader :type, :params
      attr_accessor :location

      def ==(other)
        @type == other.type && @params == other.params
      end

      def to_s
        "#<#{self.class.name}:#{self.object_id} @type=#{@type.inspect}>"
      end
    end
  end
end
