module Orbacle
  class ConstRef
    def self.from_ast(ast)
      full_name = AstUtils.const_to_string(ast)
      new(full_name)
    end

    def initialize(full_name)
      @full_name = full_name
      raise ArgumentError if full_name.empty?
    end

    attr_reader :full_name

    def name
      full_name.split("::").last
    end

    def prename
      full_name.split("::")[0..-2]
    end

    def absolute?
      full_name.start_with?("::")
    end
  end
end
