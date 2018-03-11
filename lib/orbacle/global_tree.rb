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

      def initialize(scope:, name:, line:, visibility:, args:, nodes:)
        raise ArgumentError.new(visibility) if ![:public, :private, :protected].include?(visibility)

        @name = name
        @line = line
        @visibility = visibility
        @args = args
        @nodes = nodes
        @scope = scope
      end

      attr_reader :name, :line, :scope, :args, :nodes
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

      def initialize(name:, scope:, line:, inheritance_name:, inheritance_nesting:, nodes: Nodes.new)
        @name = name
        @scope = scope
        @line = line
        @inheritance_name = inheritance_name
        @inheritance_nesting = inheritance_nesting
        @nodes = nodes
      end

      attr_reader :name, :scope, :line, :inheritance_name, :inheritance_nesting, :nodes

      def ==(other)
        @name == other.name &&
          @scope == other.scope &&
          @inheritance_name == other.inheritance_name &&
          @inheritance_nesting == other.inheritance_nesting &&
          @line == line
      end

      def full_name
        [*scope.elems, @name].join("::")
      end
    end

    class Mod
      def initialize(name:, scope:, line:)
        @name = name
        @scope = scope
        @line = line
      end

      attr_reader :name, :scope, :line

      def ==(other)
        @name == other.name &&
          @scope == other.scope &&
          @line == line
      end

      def full_name
        [*scope.elems, @name].join("::")
      end
    end

    class Constant
      def initialize(name:, scope:, line:)
        @name = name
        @scope = scope
        @line = line
      end

      attr_reader :name, :scope, :line

      def ==(other)
        @name == other.name &&
          @scope == other.scope &&
          @line == line
      end

      def full_name
        [*scope.elems, @name].join("::")
      end
    end

    class Nodes
      def initialize(global_variables = {})
        @global_variables = global_variables
      end
      attr_accessor :global_variables
    end

    def initialize
      @constants = []
      @metods = []
      @nodes = Nodes.new
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

    def solve_reference(const_ref, base_nesting)
      nesting = base_nesting
      while !nesting.empty?
        scope = nesting.to_scope
        @constants.each do |constant|
          return constant if scope.increase_by_ref(const_ref) == Scope.empty.increase_by_ref(ConstRef.from_full_name(constant.full_name))
        end
        nesting = nesting.decrease_nesting
      end
      @constants.find do |constant|
        const_ref == ConstRef.from_full_name(constant.full_name)
      end
    end
  end
end
