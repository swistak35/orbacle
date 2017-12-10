module Orbacle
  class NestingContainer
    class ConstLevel < Struct.new(:const_ref)
      def full_name
        const_ref.full_name
      end

      def absolute?
        const_ref.absolute?
      end
    end

    class ClassConstLevel < Struct.new(:skope_string)
      def full_name
        skope_string
      end

      def absolute?
        true
      end
    end

    def initialize
      @current_nesting = []
    end

    def get_output_nesting
      @current_nesting.map {|level| level.full_name }
    end

    def is_selfed?
      @current_nesting.last.is_a?(ClassConstLevel)
    end

    def increase_nesting_const(const_ref)
      @current_nesting << ConstLevel.new(const_ref)
    end

    def increase_nesting_self
      @current_nesting << ClassConstLevel.new(nesting_to_scope())
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
