module Orbacle
  module DataFlowGraph
    class DefineBuiltins
      def initialize(graph, tree)
        @graph = graph
        @tree = tree
      end

      def call
        add_object_klass
        add_dir_klass
        add_file_klass
      end

      def add_object_klass
        klass = @tree.add_klass(
          GlobalTree::Klass.new(
            name: "Object",
            scope: Scope.empty,
            parent_ref: nil,
            location: nil))

        define_object_opeq
      end

      def add_dir_klass
        klass = @tree.add_klass(
          GlobalTree::Klass.new(
            name: "Dir",
            scope: Scope.empty,
            parent_ref: nil,
            location: nil))

        define_dir_glob
      end

      def add_file_klass
        klass = @tree.add_klass(
          GlobalTree::Klass.new(
            name: "File",
            scope: Scope.empty,
            parent_ref: nil,
            location: nil))

        define_file_read
      end

      def define_object_opeq
        arg_names = build_arg_names(1)
        arg_nodes = build_arg_nodes(arg_names)
        metod = @tree.add_method(GlobalTree::Method.new(
          scope: Scope.new(["Object"], false),
          name: "==",
          location: nil,
          args: build_arg_tree(arg_names),
          visibility: :public,
          nodes: GlobalTree::Method::Nodes.new(build_nodes_hash(arg_nodes), @graph.add_vertex(Node.new(:method_result)), [])))
        bool_node = Node.new(:bool)
        @graph.add_edge(bool_node, metod.nodes.result)
      end

      def define_dir_glob
        arg_names = build_arg_names(1)
        arg_nodes = build_arg_nodes(arg_names)
        metod = @tree.add_method(GlobalTree::Method.new(
          scope: Scope.new(["Dir"], true),
          name: "glob",
          location: nil,
          args: build_arg_tree(arg_names),
          visibility: :public,
          nodes: GlobalTree::Method::Nodes.new(build_nodes_hash(arg_nodes), @graph.add_vertex(Node.new(:method_result)), [])))
        str_node = Node.new(:str)
        array_node = Node.new(:array)
        @graph.add_edge(str_node, array_node)
        @graph.add_edge(array_node, metod.nodes.result)
      end

      def define_file_read
        arg_names = build_arg_names(1)
        arg_nodes = build_arg_nodes(arg_names)
        metod = @tree.add_method(GlobalTree::Method.new(
          scope: Scope.new(["File"], true),
          name: "read",
          location: nil,
          args: build_arg_tree(arg_names),
          visibility: :public,
          nodes: GlobalTree::Method::Nodes.new(build_nodes_hash(arg_nodes), @graph.add_vertex(Node.new(:method_result)), [])))
        str_node = Node.new(:str)
        @graph.add_edge(str_node, metod.nodes.result)
      end

      def build_arg_names(n)
        n.times.map {|i| "_arg#{i}" }
      end

      def build_arg_nodes(arg_names)
        arg_names.map do |arg_name|
          Node.new(:formal_arg, { var_name: arg_name })
        end
      end

      def build_nodes_hash(arg_nodes)
        arg_nodes.each_with_object({}) do |arg_node, h|
          h[arg_node.params.fetch(:var_name)] = arg_node
        end
      end

      def build_arg_tree(arg_names)
        regular_args = arg_names.map do |arg_name|
          GlobalTree::Method::ArgumentsTree::Regular.new(arg_name)
        end
        GlobalTree::Method::ArgumentsTree.new(regular_args, [], nil)
      end
    end
  end
end
