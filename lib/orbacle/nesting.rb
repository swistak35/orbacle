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

    def initialize(levels = [])
      @levels = levels
    end

    def ==(other)
      levels.size == other.levels.size &&
        levels.zip(other.levels).all? {|l1, l2| l1 == l2 }
    end

    attr_reader :levels

    def to_primitive
      levels.map {|level| level.full_name }
    end

    def increase_nesting_const(const_ref)
      Nesting.new(levels + [ConstLevel.new(const_ref)])
    end

    def increase_nesting_self
      Nesting.new(levels + [ClassConstLevel.new(to_scope)])
    end

    def decrease_nesting
      Nesting.new(levels[0..-2])
    end

    def empty?
      levels.empty?
    end

    def to_scope
      levels.inject(Scope.empty) do |scope, nesting_level|
        if nesting_level.metaklass?
          Scope.new(nesting_level.full_name.split("::").reject(&:empty?), nesting_level.metaklass?)
        else
          scope.increase_by_ref(nesting_level.const_ref)
        end
      end
    end
  end
end
