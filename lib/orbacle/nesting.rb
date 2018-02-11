module Orbacle
  class Nesting
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

    class ClassConstLevel < Struct.new(:scope)
      def full_name
        scope.absolute_str
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

    def increase_nesting_const(const_ref)
      @levels << ConstLevel.new(const_ref)
    end

    def increase_nesting_self
      @levels << ClassConstLevel.new(Scope.from_nesting(self))
    end

    def decrease_nesting
      @levels.pop
    end
  end
end
