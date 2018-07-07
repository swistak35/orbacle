module Orbacle
  class SymbolType
    def initialize(value)
      @value = value
    end

    attr_reader :value

    def ==(other)
      self.class == other.class &&
        self.value == other.value
    end

    def hash
      [
        self.class,
        self.value,
      ].hash ^ BIG_VALUE
    end
    alias eql? ==

    def each_possible_type
      yield self
    end

    def bottom?
      false
    end
  end
end
