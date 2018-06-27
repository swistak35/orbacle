module Orbacle
  class ClassType < Struct.new(:name)
    def each_possible_type
      yield self
    end

    def pretty
      "class(#{name})"
    end

    def bottom?
      false
    end
  end
end
