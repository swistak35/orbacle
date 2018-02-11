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
        Skope.new(const_ref.relative_name, false)
      else
        Skope.new([str, const_ref.relative_name].compact.join("::"), false)
      end
    end

    def increase_by_metaklass
      raise if metaklass?
      Skope.new(str, true)
    end

    def empty?
      str.nil?
    end

    def absolute_str
      if str.nil?
        nil
      else
        name_str = str.start_with?("::") ? str : "::#{str}"
        if metaklass?
          "Metaklass(#{name_str})"
        else
          name_str
        end
      end
    end

    def prefix
      raise if metaklass?

      new_elems = str.split("::")[0..-2]
      if new_elems.empty? || (new_elems.size == 1 && new_elems[0].empty?)
        Skope.new(nil, false)
      else
        Skope.new(new_elems.join("::"), false)
      end
    end
  end
end
