require 'securerandom'

module Orbacle
  class GlobalTree
    class Method
      class ArgumentsTree < Struct.new(:args, :kwargs, :blockarg)
        Regular = Struct.new(:name)
        Optional = Struct.new(:name)
        Splat = Struct.new(:name)
        Nested = Struct.new(:args)
      end

      def initialize(id: SecureRandom.uuid, scope:, name:, location:, visibility:, args:)
        raise ArgumentError.new(visibility) if ![:public, :private, :protected].include?(visibility)

        @id = id
        @name = name
        @location = location
        @visibility = visibility
        @args = args
        @scope = scope
      end

      attr_reader :id, :name, :location, :scope, :args
      attr_accessor :visibility
    end

    class Klass
      def initialize(id: SecureRandom.uuid, name:, scope:, location:, parent_ref:)
        @id = id
        @name = name
        @scope = scope
        @location = location
        @parent_ref = parent_ref
      end

      attr_reader :id, :name, :scope, :location, :parent_ref

      def ==(other)
        @id == other.id &&
          @name == other.name &&
          @scope == other.scope &&
          @parent_ref == other.parent_ref &&
          @location == location
      end

      def full_name
        [*scope.elems, @name].join("::")
      end
    end

    class Mod
      def initialize(id: SecureRandom.uuid, name:, scope:, location:)
        @id = id
        @name = name
        @scope = scope
        @location = location
      end

      attr_reader :name, :scope, :location

      def ==(other)
        @id = other.id &&
          @name == other.name &&
          @scope == other.scope &&
          @location == location
      end

      def full_name
        [*scope.elems, @name].join("::")
      end
    end

    class Constant
      def initialize(name:, scope:, location:)
        @name = name
        @scope = scope
        @location = location
      end

      attr_reader :name, :scope, :location

      def ==(other)
        @name == other.name &&
          @scope == other.scope &&
          @location == location
      end

      def full_name
        [*scope.elems, @name].join("::")
      end
    end

    def initialize
      @constants = []
      @metods = []
      @lambdas = []
    end

    attr_reader :metods, :constants

    def add_method(metod)
      @metods << metod
      return metod
    end

    def add_klass(klass)
      @constants << klass
      return klass
    end

    def add_mod(mod)
      @constants << mod
      return mod
    end

    def add_constant(constant)
      @constants << constant
      return constant
    end

    def add_lambda
      lambda_id = SecureRandom.uuid
      @lambdas << lambda_id
      return lambda_id
    end

    def solve_reference(const_ref)
      nesting = const_ref.nesting
      while !nesting.empty?
        scope = nesting.to_scope
        @constants.each do |constant|
          return constant if scope.increase_by_ref(const_ref).to_const_name == ConstName.from_string(constant.full_name)
        end
        nesting = nesting.decrease_nesting
      end
      @constants.find do |constant|
        const_ref.const_name == ConstName.from_string(constant.full_name)
      end
    end

    def get_parent_of(class_name)
      possible_parents = @constants
        .select {|c| c.is_a?(Klass) }
        .select {|c| c.full_name == class_name }
        .map(&:parent_ref)
        .reject(&:nil?)
        .map(&method(:solve_reference))
        .reject(&:nil?)
        .map(&:full_name)
      if class_name == "Object"
        nil
      elsif possible_parents.empty?
        "Object"
      else
        possible_parents[0]
      end
    end

    def find_instance_method(class_name, method_name)
      @metods.find {|m| m.scope.to_s == class_name && m.name == method_name }
    end

    def find_class_method(class_name, method_name)
      @metods.find {|m| !m.scope.empty? && m.scope.to_const_name.to_string == class_name && m.scope.metaklass? && m.name == method_name }
    end

    def find_any_methods(method_name)
      @metods.select {|m| m.name == method_name }
    end

    def find_super_method(method_id)
      analyzed_method = get_method(method_id)
      if analyzed_method.scope.metaklass?
        raise
      else
        klass_of_this_method = find_constants_by_const_name(analyzed_method.scope.to_const_name)[0]
        parent_klass = solve_reference(klass_of_this_method.parent_ref)
        find_instance_method(parent_klass.full_name, analyzed_method.name)
      end
    end

    def get_method(method_id)
      @metods.find {|m| m.id == method_id }
    end

    def find_constants_by_const_name(const_name)
      @constants.select do |constant|
        constant.scope == const_name.scope && constant.name == const_name.name
      end
    end

    def change_metod_visibility(scope, name, new_visibility)
      @metods.each do |m|
        if m.scope == scope && m.name == name
          m.visibility = new_visibility
        end
      end
    end
  end
end
