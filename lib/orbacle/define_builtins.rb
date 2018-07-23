# frozen_string_literal: true

module Orbacle
  class DefineBuiltins
    def initialize(graph, tree, id_generator)
      @graph = graph
      @tree = tree
      @id_generator = id_generator
    end

    def call
      add_object_klass
      add_dir_klass
      add_file_klass
      add_integer_klass
    end

    private
    attr_reader :id_generator

    def add_object_klass
      klass = @tree.add_klass2(nil)
      @tree.add_constant(
        GlobalTree::Constant.new("Object", Scope.empty, nil, klass.id))

      # BasicObject
      template_just_bool(klass, "==")
      template_just_bool(klass, "!")
      template_just_bool(klass, "!=")
      template_just_bool(klass, "equal?")
      template_just_int(klass, "object_id")
      template_just_int(klass, "__id__")

      # Object
      template_just_bool(klass, "!~")
      template_maybe_int(klass, "<=>")
      template_just_bool(klass, "===")
      template_just_nil(klass, "display")
      template_just_bool(klass, "eql?")
      template_just_bool(klass, "frozen?")
      template_just_bool(klass, "instance_of?")
      template_just_bool(klass, "instance_variable_defined?")
      template_just_bool(klass, "is_a?")
      template_just_str(klass, "inspect")
      template_just_bool(klass, "kind_of?")
      template_just_bool(klass, "nil?")
      template_just_bool(klass, "respond_to?")
      template_just_bool(klass, "respond_to_missing?")
      template_just_bool(klass, "tainted?")
      template_just_bool(klass, "untrusted?")
      template_just_str(klass, "to_s")
    end

    def add_integer_klass
      klass = @tree.add_klass2(nil)
      @tree.add_constant(
        GlobalTree::Constant.new("Integer", Scope.empty, nil, klass.id))

      template_just_int(klass, "succ")
      template_just_int(klass, "+")
      template_just_int(klass, "-")
      template_just_int(klass, "*")
    end

    def add_dir_klass
      klass = @tree.add_klass2(nil)
      @tree.add_constant(
        GlobalTree::Constant.new("Dir", Scope.empty, nil, klass.id))
      eigenclass = @tree.get_eigenclass_of_definition(klass.id)

      template_just_array_of_str(eigenclass, "glob")
    end

    def add_file_klass
      klass = @tree.add_klass2(nil)
      @tree.add_constant(
        GlobalTree::Constant.new("File", Scope.empty, nil, klass.id))
      eigenclass = @tree.get_eigenclass_of_definition(klass.id)

      template_just_str(eigenclass, "read")
    end

    def template_just_int(klass, name)
      metod = template_args(klass, name)
      int_node = Node.new(:int, {})
      @graph.add_edge(int_node, @graph.get_metod_nodes(metod.id).result)
    end

    def template_maybe_int(klass, name)
      metod = template_args(klass, name)
      int_node = Node.new(:int, {})
      nil_node = Node.new(:nil, {})
      @graph.add_edge(int_node, @graph.get_metod_nodes(metod.id).result)
      @graph.add_edge(nil_node, @graph.get_metod_nodes(metod.id).result)
    end

    def template_just_str(klass, name)
      metod = template_args(klass, name)
      str_node = Node.new(:str, {})
      @graph.add_edge(str_node, @graph.get_metod_nodes(metod.id).result)
    end

    def template_just_bool(klass, name)
      metod = template_args(klass, name)
      str_node = Node.new(:bool, {})
      @graph.add_edge(str_node, @graph.get_metod_nodes(metod.id).result)
    end

    def template_just_nil(klass, name)
      metod = template_args(klass, name)
      str_node = Node.new(:nil, {})
      @graph.add_edge(str_node, @graph.get_metod_nodes(metod.id).result)
    end

    def template_just_array_of_str(klass, name)
      metod = template_args(klass, name)
      str_node = Node.new(:str, {})
      array_node = Node.new(:array, {})
      @graph.add_edge(str_node, array_node)
      @graph.add_edge(array_node, @graph.get_metod_nodes(metod.id).result)
    end

    def template_args(klass, name)
      metod = @tree.add_method(GlobalTree::Method.new(
        id: generate_id,
        place_of_definition_id: klass.id,
        name: name,
        location: nil,
        args: GlobalTree::ArgumentsTree.new([], []),
        visibility: :public))
      @graph.store_metod_nodes(metod.id, {})
      metod
    end

    def generate_id
      id_generator.call
    end
  end
end
