module Orbacle
  class ConstRef
    def self.from_ast(ast)
      prename, const_name = AstUtils.get_nesting(ast)
      full_name = (prename + [const_name]).join("::")
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

  class NestingContainer
    def initialize
      @current_nesting = []
      @is_selfed = false
    end

    def get_output_nesting
      @current_nesting.map {|const_ref| const_ref.full_name }
    end

    def is_selfed?
      @is_selfed
    end

    def increase_nesting_const(const_ref)
      @current_nesting << const_ref
    end

    def make_nesting_selfed
      @is_selfed = true
    end

    def make_nesting_not_selfed
      @is_selfed = false
    end

    def decrease_nesting
      @current_nesting.pop
    end

    def scope_from_nesting_and_prename(prename)
      scope_from_nesting = nesting_to_scope()

      if prename.at(0).eql?("")
        result = prename.join("::")
      else
        result = ([scope_from_nesting] + prename).join("::")
      end
      result if !result.empty?
    end

    def nesting_to_scope
      return nil if @current_nesting.empty?

      @current_nesting.inject("") do |skope, nesting_level|
        if nesting_level.absolute?
          nesting_level.full_name
        else
          [skope, nesting_level.full_name].join("::")
        end
      end
    end
  end
end
