module Orbacle
  class Skope
    def self.from_nesting(nesting)
      nesting.levels.inject(Skope.empty) do |skope, nesting_level|
        if nesting_level.metaklass?
          Skope.new(nesting_level.full_name.split("::").reject(&:empty?), nesting_level.metaklass?)
        else
          skope.increase_by_ref(nesting_level.const_ref)
        end
      end
    end

    def self.empty
      new([], false)
    end

    def initialize(elems, is_metaklass)
      @elems = elems
      @is_metaklass = is_metaklass
    end

    attr_reader :elems

    def increase_by_ref(const_ref)
      if const_ref.absolute?
        Skope.new(const_ref.elems, false)
      else
        Skope.new(elems + const_ref.elems, metaklass?)
      end
    end

    def increase_by_metaklass
      raise if metaklass?
      Skope.new(elems, true)
    end

    def decrease
      if metaklass?
        Skope.new(elems, false)
      elsif elems.empty?
        raise
      else
        Skope.new(elems[0..-2], false)
      end
    end

    def empty?
      elems.empty?
    end

    def absolute_str
      klasslike_name = elems.join("::")
      if metaklass?
        "Metaklass(#{klasslike_name})"
      else
        klasslike_name
      end
    end

    def metaklass?
      @is_metaklass
    end
  end
end
