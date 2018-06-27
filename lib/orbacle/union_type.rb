module Orbacle
  class UnionType < Struct.new(:types)
    def each_possible_type
      types.each do |type|
        type.each_possible_type do |t|
          yield t
        end
      end
    end

    def pretty
      "Union(#{types.map {|t| t.nil? ? "nil" : t.pretty }.join(" or ")})"
    end

    def bottom?
      false
    end
  end
end
