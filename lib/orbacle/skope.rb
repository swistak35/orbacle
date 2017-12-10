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
end
