module Orbacle
  class ConstRef
    def self.from_ast(ast, nesting)
      full_name = AstUtils.const_to_string(ast)
      from_full_name(full_name, nesting)
    end

    def self.from_full_name(full_name, nesting)
      if full_name.start_with?("::")
        name = full_name[2..-1]
        new(ConstName.from_string(name), true, nesting)
      else
        new(ConstName.from_string(full_name), false, nesting)
      end
    end

    def initialize(const_name, is_absolute, nesting)
      @const_name = const_name
      @is_absolute = is_absolute
      @nesting = nesting
    end

    attr_reader :const_name, :is_absolute, :nesting

    def full_name
      if absolute?
        "::#{const_name.to_string}"
      else
        const_name.to_string
      end
    end

    def to_full_const_name
      if absolute?
        const_name
      else
        ConstName.new([*nesting.to_primitive, const_name.to_string])
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
        is_absolute == other.is_absolute &&
        nesting == other.nesting
    end
  end
end
