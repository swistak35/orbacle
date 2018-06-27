module Orbacle
  class NominalType < Struct.new(:name)
    def each_possible_type
      yield self
    end

    def pretty
      name
    end

    def bottom?
      false
    end
  end
end
