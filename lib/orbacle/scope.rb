module Orbacle
  class Scope
    def self.empty
      new([], false)
    end

    def initialize(elems, is_eigenclass)
      @elems = elems
      @is_eigenclass = is_eigenclass
    end

    attr_reader :elems

    def increase_by_ref(const_ref)
      if const_ref.absolute?
        Scope.new(const_ref.const_name.elems, false)
      else
        Scope.new(elems + const_ref.const_name.elems, eigenclass?)
      end
    end

    def increase_by_eigenclass
      raise if eigenclass?
      Scope.new(elems, true)
    end

    def decrease
      if eigenclass?
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
      elems.join("::")
    end

    def eigenclass?
      @is_eigenclass
    end

    def ==(other)
      @elems == other.elems && eigenclass? == other.eigenclass?
    end

    def to_s
      absolute_str
    end

    def to_const_name
      ConstName.new(elems)
    end
  end
end
