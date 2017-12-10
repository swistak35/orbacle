module Orbacle
  class NestingContainer
    def initialize
      @current_nesting = []
      @is_selfed = false
    end

    def get_output_nesting
      @current_nesting.dup
    end

    def is_selfed?
      @is_selfed
    end

    def increase_nesting_const(ast_name)
      prename, klasslike_name = AstUtils.get_nesting(ast_name)

      @current_nesting << (prename + [klasslike_name]).join("::")
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
        if nesting_level.start_with?("::")
          nesting_level
        else
          [skope, nesting_level].join("::")
        end
      end
    end
  end
end
