module Orbacle
  class UnionType
    def initialize(types)
      @types_set = Set.new(types)
    end

    attr_reader :types_set

    def types
      @types_set
    end

    def ==(other)
      self.class == other.class &&
        self.types_set == other.types_set
    end

    def hash
      [
        self.class,
        self.types_set,
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
