module Orbacle
  class NestingContainer
    class ConstLevel < Struct.new(:const_ref)
      def full_name
        const_ref.full_name
      end

      def absolute?
        const_ref.absolute?
      end

      def metaklass?
        false
      end
    end

    class ClassConstLevel < Struct.new(:skope_string)
      def full_name
        skope_string
      end

      def absolute?
        true
      end

      def metaklass?
        true
      end
    end

    def initialize
      @levels = []
    end

    attr_reader :levels

    def get_output_nesting
      @levels.map {|level| level.full_name }
    end

    def is_selfed?
      @levels.last.is_a?(ClassConstLevel)
    end

    def increase_nesting_const(const_ref)
      @levels << ConstLevel.new(const_ref)
    end

    def increase_nesting_self
      @levels << ClassConstLevel.new(nesting_to_scope())
    end

    def decrease_nesting
      @levels.pop
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
      skope = Skope.from_nesting(self)
      skope.empty? ? nil : skope.absolute_str
    end
  end
end
