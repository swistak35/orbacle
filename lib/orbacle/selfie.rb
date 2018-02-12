module Orbacle
  class Selfie
    def self.klass_from_scope(scope)
      new(:klass, scope)
    end

    def self.instance_from_scope(scope)
      new(:instance, scope)
    end

    def self.main
      new(:main, nil)
    end

    def initialize(kind, scope)
      @kind = kind
      @scope = scope
      raise if ![:klass, :instance, :main].include?(kind)
    end

    def klass?
      @kind == :klass
    end

    def instance?
      @kind == :instance
    end

    def main?
      @kind == :main
    end

    attr_reader :kind, :scope

    def ==(other)
      @kind == other.kind && @scope == other.scope
    end
  end
end
