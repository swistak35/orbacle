module Orbacle
  class ConstRef
    def self.from_ast(ast)
      full_name = AstUtils.const_to_string(ast)
      from_full_name(full_name)
    end

    def self.from_full_name(full_name)
      if full_name.start_with?("::")
        new(full_name[2..-1].split("::"), true)
      else
        new(full_name.split("::"), false)
      end
    end

    def initialize(elems, is_absolute)
      @elems = elems
      @is_absolute = is_absolute
      raise ArgumentError if elems.empty?
    end

    def full_name
      if absolute?
        "::#{relative_name}"
      else
        relative_name
      end
    end

    def name
      @elems.last
    end

    def prename
      @elems[0..-2]
    end

    def absolute?
      @is_absolute
    end

    def relative_name
      @elems.join("::")
    end
  end
end
