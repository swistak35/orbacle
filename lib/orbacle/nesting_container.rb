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
      skope = Skope.from_nesting(self)
      @levels << ClassConstLevel.new(skope.absolute_str)
    end

    def decrease_nesting
      @levels.pop
    end
  end
end
