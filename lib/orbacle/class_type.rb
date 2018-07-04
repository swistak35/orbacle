module Orbacle
  class ClassType
    def initialize(name)
      @name = name
    end

    attr_reader :name

    def ==(other)
      self.class == other.class &&
        self.name == other.name
    end

    def hash
      [
        self.class,
        self.name,
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
