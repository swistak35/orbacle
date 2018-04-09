module Orbacle
  class GlobalTree
    class Method
      Nodes = Struct.new(:args, :result, :yields)

      class ArgumentsTree < Struct.new(:args, :kwargs, :blockarg)
        Regular = Struct.new(:name)
        Optional = Struct.new(:name)
        Splat = Struct.new(:name)
        Nested = Struct.new(:args)
      end

      def initialize(scope:, name:, location:, visibility:, args:, nodes:)
        raise ArgumentError.new(visibility) if ![:public, :private, :protected].include?(visibility)

        @name = name
        @location = location
        @visibility = visibility
        @args = args
        @nodes = nodes
        @scope = scope
      end

      attr_reader :name, :location, :scope, :args, :nodes
      attr_accessor :visibility
    end

    class Klass
      class Nodes
        def initialize(instance_variables = {}, class_level_instance_variables = {}, class_variables = {})
          @instance_variables = instance_variables
          @class_level_instance_variables = class_level_instance_variables
          @class_variables = class_variables
        end
        attr_accessor :instance_variables, :class_variables, :class_level_instance_variables
      end

      def initialize(name:, scope:, location:, parent_ref:, nodes: Nodes.new)
        @name = name
        @scope = scope
        @location = location
        @parent_ref = parent_ref
        @nodes = nodes
      end

      attr_reader :name, :scope, :location, :parent_ref, :nodes

      def ==(other)
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

    class Lambda
      Nodes = Struct.new(:args, :result)
      def initialize(id, nodes)
        @id = id
        @nodes = nodes
      end

      attr_reader :id, :nodes
    end

    def initialize
      @constants = []
      @metods = []
      @lambdas = []
      @lambda_counter = 0
    end

    attr_reader :metods, :constants, :nodes

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

    def add_lambda(nodes)
      lamb = Lambda.new(@lambda_counter, nodes)
      @lambda_counter += 1
      @lambdas << lamb
      return lamb
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
  end
end
