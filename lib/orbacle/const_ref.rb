module Orbacle
  class ConstRef
    def self.from_ast(ast)
      full_name = AstUtils.const_to_string(ast)
      from_full_name(full_name)
    end

    def self.from_full_name(full_name)
      if full_name.start_with?("::")
        name = full_name[2..-1]
        new(ConstName.from_string(name), true)
      else
        new(ConstName.from_string(full_name), false)
      end
    end

    def initialize(const_name, is_absolute)
      @const_name = const_name
      @is_absolute = is_absolute
    end

    attr_reader :const_name, :is_absolute

    def full_name
      if absolute?
        "::#{const_name.to_string}"
      else
        const_name.to_string
      end
    end

    def absolute?
      @is_absolute
    end

    def relative_name
      const_name.to_string
    end

    def name
      const_name.name
    end

    def ==(other)
      const_name == other.const_name &&
        is_absolute == other.is_absolute
    end
  end
end
