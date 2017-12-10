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
      prename, module_name = AstUtils.get_nesting(ast_name)

      if prename[0] == ""
        current_nesting_element = [prename[1..-1] || [], module_name]
        @current_nesting = [current_nesting_element]
      else
        current_nesting_element = [prename, module_name]
        @current_nesting << current_nesting_element
      end
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
        result = prename.drop(1).join("::")
      else
        result = ([scope_from_nesting] + prename).compact.join("::")
      end
      result if !result.empty?
    end

    def nesting_to_scope
      return nil if @current_nesting.empty?

      @current_nesting.map do |pre, name|
        pre + [name]
      end.join("::")
    end
  end
end
