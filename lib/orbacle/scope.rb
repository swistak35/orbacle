module Orbacle
  class Scope
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
        Scope.new(const_ref.const_name.elems, false)
      else
        Scope.new(elems + const_ref.const_name.elems, metaklass?)
      end
    end

    def increase_by_metaklass
      raise if metaklass?
      Scope.new(elems, true)
    end

    def decrease
      if metaklass?
        Scope.new(elems, false)
      elsif elems.empty?
        raise
      else
        Scope.new(elems[0..-2], false)
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

    def ==(other)
      @elems == other.elems && metaklass? == other.metaklass?
    end

    def to_s
      absolute_str
    end

    def to_const_name
      ConstName.new(elems)
    end
  end
end
