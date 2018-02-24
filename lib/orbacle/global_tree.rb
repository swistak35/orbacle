module Orbacle
  class GlobalTree
    class Method
      Nodes = Struct.new(:args, :result, :yields)

      def initialize(scope:, name:, line:, visibility:, nodes:)
        raise ArgumentError.new(visibility) if ![:public, :private, :protected].include?(visibility)

        @name = name
        @line = line
        @visibility = visibility
        @nodes = nodes
        @scope = scope
      end

      attr_reader :name, :line, :scope, :nodes
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

    def add_klass(name:, scope:, line:, inheritance_name:, inheritance_nesting:)
      klass = Klass.new(name: name, scope: scope, line: line, inheritance_name: inheritance_name, inheritance_nesting: inheritance_nesting)
      @constants << klass
      klass
    end

    def add_mod(name:, scope:, line:)
      mod = Mod.new(name: name, scope: scope, line: line)
      @constants << mod
    end

    def add_constant(name:, scope:, line:)
      constant = Constant.new(name: name, scope: scope, line: line)
      @constants << constant
    end
  end
end
