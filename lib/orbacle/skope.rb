module Orbacle
  class Skope < Struct.new(:str, :metaklass?)
    def self.from_nesting(nesting)
      nesting.levels.inject(Skope.empty) do |skope, nesting_level|
        if nesting_level.metaklass?
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
      raise if metaklass?

      if const_ref.absolute?
        Skope.new(const_ref.full_name, false)
      else
        Skope.new([str, const_ref.full_name].compact.join("::"), false)
      end
    end

    def empty?
      str.nil?
    end

    def absolute_str
      if str.nil?
        nil
      else
        str.start_with?("::") ? str : "::#{str}"
      end
    end

    def prefix
      new_str = str.split("::")[0..-2].join("::")
      Skope.new(new_str == "" ? nil : new_str, metaklass?)
    end
  end
end