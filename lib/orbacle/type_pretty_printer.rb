module Orbacle
  class TypePrettyPrinter
    def call(type)
      case type
      when BottomType
        "unknown"
      when ClassType
        "class(#{type.name})"
      when NominalType
        type.name
      when GenericType
        pretty_parameters = type.parameters.map(&method(:call))
        "generic(#{type.name}, [#{pretty_parameters.join(", ")}])"
      when MainType
        "main"
      when UnionType
        included_types = type.types.map(&method(:call))
        "Union(#{included_types.join(" or ")})"
      end
    end
  end
end
