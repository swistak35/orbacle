module Orbacle
  class GenericType
    def initialize(name, parameters)
      @name = name
      @parameters = parameters
    end

    attr_reader :name, :parameters

    def ==(other)
      self.class == other.class &&
        self.name == other.name &&
        self.parameters == other.parameters
    end

    def hash
      [
        self.class,
        self.name,
        self.parameters,
      ].hash ^ BIG_VALUE
    end
    alias eql? ==

    def each_possible_type
      yield self
    end

    def pretty
      "generic(#{name}, [#{parameters.map {|t| t.nil? ? "nil" : t.pretty }.join(", ")}])"
    end

    def bottom?
      false
    end
  end
end
