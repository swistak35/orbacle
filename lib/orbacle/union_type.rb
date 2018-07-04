module Orbacle
  class UnionType
    def initialize(types)
      @types = Set.new(types)
    end

    def types
      @types.to_a
    end

    def ==(other)
      self.class == other.class &&
        self.types == other.types
    end

    def hash
      [
        self.class,
        self.types,
      ].hash ^ BIG_VALUE
    end
    alias eql? ==

    def each_possible_type
      types.each do |type|
        type.each_possible_type do |t|
          yield t
        end
      end
    end

    def bottom?
      false
    end
  end
end
