module Orbacle
  class BottomType
    def ==(other)
      other.class == self.class
    end

    def hash
      [
        self.class,
      ].hash ^ BIG_VALUE
    end
    alias eql? ==

    def each_possible_type
    end

    def bottom?
      true
    end
  end
end
