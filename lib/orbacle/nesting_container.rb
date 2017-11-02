module Orbacle
  class NestingContainer
    def initialize
      @current_nesting = []
      @is_selfed = false
    end

    def get_nesting(ast_const)
      [prename(ast_const.children[0]), ast_const.children[1].to_s]
    end

    def get_current_nesting
      @current_nesting
    end

    def is_selfed?
      @is_selfed
    end

    def increase_nesting_mod(ast_name)
      prename, module_name = get_nesting(ast_name)

      if prename[0] == ""
        current_nesting_element = [:mod, prename[1..-1] || [], module_name]
        @current_nesting = [current_nesting_element]
      else
        current_nesting_element = [:mod, prename, module_name]
        @current_nesting << current_nesting_element
      end
    end

    def increase_nesting_class(ast_name)
      prename, klass_name = get_nesting(ast_name)

      if prename[0] == ""
        current_nesting_element = [:klass, prename[1..-1] || [], klass_name]
        @current_nesting = [current_nesting_element]
      else
        current_nesting_element = [:klass, prename, klass_name]
        @current_nesting << current_nesting_element
      end
    end

    def make_nesting_selfed
      @is_selfed = true
    end

    def make_nesting_not_selfed
      @is_selfed = false
    end

    def prename(ast_const)
      if ast_const.nil?
        []
      else
        prename(ast_const.children[0]) + [ast_const.children[1].to_s]
      end
    end

    def decrease_nesting
      @current_nesting.pop
    end
  end
end
