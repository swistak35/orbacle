module Orbacle
  class DefineBuiltins
    def initialize(graph, tree)
      @graph = graph
      @tree = tree
    end

    def call
      add_object_klass
      add_dir_klass
      add_file_klass
      add_integer_klass
    end

    def add_object_klass
      klass = @tree.add_klass(GlobalTree::Klass.new(parent_ref: nil))
      @tree.add_constant(
        GlobalTree::Constant.new("Object", Scope.empty, nil, klass.id))

      define_object_opeq(klass)
      template_just_str(klass, "to_s", 0)
      template_just_nil(klass, "display", 0)
    end

    def add_integer_klass
      klass = @tree.add_klass(GlobalTree::Klass.new(parent_ref: nil))
      @tree.add_constant(
        GlobalTree::Constant.new("Integer", Scope.empty, nil, klass.id))

      template_just_int(klass, "succ", 0)
      template_just_int(klass, "+", 1)
      template_just_int(klass, "-", 1)
      template_just_int(klass, "*", 1)
    end

    def add_dir_klass
      klass = @tree.add_klass(GlobalTree::Klass.new(parent_ref: nil))
      @tree.add_constant(
        GlobalTree::Constant.new("Dir", Scope.empty, nil, klass.id))
      eigenklass = @tree.get_eigenclass_of_definition(klass.id)

      define_dir_glob(eigenklass)
    end

    def add_file_klass
      klass = @tree.add_klass(GlobalTree::Klass.new(parent_ref: nil))
      @tree.add_constant(
        GlobalTree::Constant.new("File", Scope.empty, nil, klass.id))
      eigenklass = @tree.get_eigenclass_of_definition(klass.id)

      template_just_str(eigenklass, "read", 1)
    end

    def define_object_opeq(klass)
      arg_names = build_arg_names(1)
      arg_nodes = build_arg_nodes(arg_names)
      metod = @tree.add_method(GlobalTree::Method.new(
        place_of_definition_id: klass.id,
        name: "==",
        location: nil,
        args: build_arg_tree(arg_names),
        visibility: :public))
      @graph.store_metod_nodes(metod.id, build_nodes_hash(arg_nodes))
      bool_node = Node.new(:bool, {})
      @graph.add_edge(bool_node, @graph.get_metod_nodes(metod.id).result)
    end

    def define_dir_glob(klass)
      arg_names = build_arg_names(1)
      arg_nodes = build_arg_nodes(arg_names)
      metod = @tree.add_method(GlobalTree::Method.new(
        place_of_definition_id: klass.id,
        name: "glob",
        location: nil,
        args: build_arg_tree(arg_names),
        visibility: :public))
      @graph.store_metod_nodes(metod.id, build_nodes_hash(arg_nodes))
      str_node = Node.new(:str, {})
      array_node = Node.new(:array, {})
      @graph.add_edge(str_node, array_node)
      @graph.add_edge(array_node, @graph.get_metod_nodes(metod.id).result)
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
        GlobalTree::ArgumentsTree::Regular.new(arg_name)
      end
      GlobalTree::ArgumentsTree.new(regular_args, [], nil)
    end

    def template_just_int(klass, name, args)
      metod = template_args(klass, name, args)
      int_node = Node.new(:int, {})
      @graph.add_edge(int_node, @graph.get_metod_nodes(metod.id).result)
    end

    def template_just_str(klass, name, args)
      metod = template_args(klass, name, args)
      str_node = Node.new(:str, {})
      @graph.add_edge(str_node, @graph.get_metod_nodes(metod.id).result)
    end

    def template_just_nil(klass, name, args)
      metod = template_args(klass, name, args)
      str_node = Node.new(:nil, {})
      @graph.add_edge(str_node, @graph.get_metod_nodes(metod.id).result)
    end

    def template_args(klass, name, args)
      arg_names = build_arg_names(args)
      arg_nodes = build_arg_nodes(arg_names)
      metod = @tree.add_method(GlobalTree::Method.new(
        place_of_definition_id: klass.id,
        name: name,
        location: nil,
        args: build_arg_tree(arg_names),
        visibility: :public))
      @graph.store_metod_nodes(metod.id, build_nodes_hash(arg_nodes))
      return metod
    end
  end
end
