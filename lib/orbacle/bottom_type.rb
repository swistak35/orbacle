module Orbacle
  class BottomType
    def ==(other)
      other.class == self.class
    end

    def each_possible_type
    end

    def pretty
      "unknown"
    end

    def bottom?
      true
    end
  end
end
