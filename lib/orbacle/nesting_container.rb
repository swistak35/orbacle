module Orbacle
  class Skope < Struct.new(:str, :metaklass?)
    def self.from_nesting(nesting)
      nesting.levels.inject(Skope.empty) do |skope, nesting_level|
        if nesting_level.absolute?
          Skope.new(nesting_level.full_name, nesting_level.metaklass?)
        else
          skope.increase_by_ref(nesting_level.const_ref)
        end
      end
    end

    def self.empty
      new(nil, false)
    end

    def increase_by_ref(const_ref)
      Skope.new(
        [str, const_ref.full_name].compact.join("::"),
        metaklass?)
    end

    def empty?
      str.nil?
    end

    def absolute_str
      str.start_with?("::") ? str : "::#{str}"
    end
  end

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
      @current_nesting = []
    end

    def get_output_nesting
      @current_nesting.map {|level| level.full_name }
    end

    def levels
      @current_nesting
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
      skope = Skope.from_nesting(self)
      skope.empty? ? nil : skope.absolute_str
    end
  end
end
