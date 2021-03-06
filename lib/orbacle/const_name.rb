# frozen_string_literal: true

module Orbacle
  class ConstName
    def self.from_string(str)
      raise ArgumentError if str.start_with?("::")
      new(str.split("::"))
    end

    def initialize(elems)
      @elems = elems
      raise ArgumentError if elems.empty?
    end

    attr_reader :elems

    def ==(other)
      elems == other.elems
    end

    def name
      elems.last
    end

    def to_string
      elems.join("::")
    end

    def scope
      Scope.new(elems[0..-2], false)
    end
  end
end
