module Orbacle
  class GenericType < Struct.new(:name, :parameters)
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
