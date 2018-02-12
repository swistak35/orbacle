module Orbacle
  class GlobalTree
    class Method
      def initialize(name:, line:, visibility:, node_result:, node_formal_arguments:, scope:)
        raise ArgumentError.new(visibility) if ![:public, :private, :protected].include?(visibility)

        @name = name
        @line = line
        @visibility = visibility
        @node_result = node_result
        @node_formal_arguments = node_formal_arguments
        @scope = scope
      end

      attr_reader :name, :line, :node_result, :node_formal_arguments, :scope
      attr_accessor :visibility
    end

    class Klass
      class Nodes
        def initialize(instance_variables = {})
          @instance_variables = instance_variables
        end
        attr_accessor :instance_variables
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
        [scope, @name].reject(&:empty?).join("::")
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

    def initialize
      @constants = []
      @methods = []
    end

    attr_reader :methods, :constants

    def add_method(name:, line:, visibility:, node_result:, node_formal_arguments:, scope:)
      method = Method.new(
        name: name,
        line: line,
        scope: scope,
        visibility: visibility,
        node_result: node_result,
        node_formal_arguments: node_formal_arguments)
      @methods << method
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
