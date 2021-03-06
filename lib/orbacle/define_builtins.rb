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
      add_array_klass
    end

    private
    attr_reader :id_generator

    def add_object_klass
      klass = @tree.add_class(nil)
      @tree.add_constant(
        GlobalTree::Constant.new("Object", Scope.empty, nil, klass.id))
      eigenclass = @tree.get_eigenclass_of_definition(klass.id)

      # BasicObject
      template_just_bool(klass, :"==")
      template_just_bool(klass, :"!")
      template_just_bool(klass, :"!=")
      template_just_bool(klass, :equal?)
      template_just_int(klass, :object_id)
      template_just_int(klass, :__id__)

      # Object
      template_just_bool(klass, :"!~")
      template_maybe_int(klass, :"<=>")
      template_just_bool(klass, :"===")
      template_caller_id(klass, :clone)
      addm_object_class(klass)
      template_just_nil(klass, :display)
      template_caller_id(klass, :dup)
      template_just_bool(klass, :eql?)
      template_caller_id(klass, :freeze)
      template_just_bool(klass, :frozen?)
      template_just_bool(klass, :instance_of?)
      template_just_bool(klass, :instance_variable_defined?)
      template_just_bool(klass, :is_a?)
      template_just_str(klass, :inspect)
      template_caller_id(klass, :itself)
      template_just_bool(klass, :kind_of?)
      template_just_bool(klass, :nil?)
      template_just_bool(klass, :respond_to?)
      template_just_bool(klass, :respond_to_missing?)
      template_caller_id(klass, :taint)
      template_caller_id(klass, :trust)
      template_just_bool(klass, :tainted?)
      template_caller_id(klass, :untaint)
      template_caller_id(klass, :untrust)
      template_just_bool(klass, :untrusted?)
      template_just_str(klass, :to_s)

      addm_object_class(eigenclass)
    end

    def add_integer_klass
      klass = @tree.add_class(nil)
      @tree.add_constant(
        GlobalTree::Constant.new("Integer", Scope.empty, nil, klass.id))

      template_just_int(klass, :succ)
      template_just_int(klass, :"+")
      template_just_int(klass, :"-")
      template_just_int(klass, :"*")
    end

    def add_dir_klass
      klass = @tree.add_class(nil)
      @tree.add_constant(
        GlobalTree::Constant.new("Dir", Scope.empty, nil, klass.id))
      eigenclass = @tree.get_eigenclass_of_definition(klass.id)

      template_just_array_of_str(eigenclass, :glob)
    end

    def add_file_klass
      klass = @tree.add_class(nil)
      @tree.add_constant(
        GlobalTree::Constant.new("File", Scope.empty, nil, klass.id))
      eigenclass = @tree.get_eigenclass_of_definition(klass.id)

      template_just_str(eigenclass, :read)
    end

    def add_array_klass
      klass = @tree.add_class(nil)
      @tree.add_constant(GlobalTree::Constant.new("Array", Scope.empty, nil, klass.id))

      add_array_map(klass)
      add_array_each(klass)
    end

    def add_array_map(klass)
      metod = add_method(klass.id, :map, :public, GlobalTree::ArgumentsTree.new([], []))
      caller_node = Node.new(:caller, {})
      result_node = Node.new(:method_result, {})
      yield_arg = Node.new(:call_arg, {})
      yield_result = Node.new(:yield_result, {})
      yields = [Graph::Yield.new([yield_arg], yield_result)]
      unwrap_array = Node.new(:unwrap_array, {})
      wrap_array = Node.new(:wrap_array, {})
      all_nodes = [caller_node, result_node, yield_arg, yield_result, unwrap_array, wrap_array]
      all_edges = [
        [caller_node, unwrap_array],
        [unwrap_array, yield_arg],
        [yield_result, wrap_array],
        [wrap_array, result_node],
      ]
      @graph.store_metod_subgraph(metod.id, {}, caller_node, result_node, yields, all_nodes, all_edges)
    end

    def add_array_each(klass)
      metod = add_method(klass.id, :each, :public, GlobalTree::ArgumentsTree.new([], []))
      caller_node = Node.new(:caller, {})
      result_node = Node.new(:method_result, {})
      yield_arg = Node.new(:call_arg, {})
      yield_result = Node.new(:yield_result, {})
      yields = [Graph::Yield.new([yield_arg], yield_result)]
      unwrap_array = Node.new(:unwrap_array, {})
      all_nodes = [caller_node, result_node, yield_arg, yield_result, unwrap_array]
      all_edges = [
        [caller_node, unwrap_array],
        [unwrap_array, yield_arg],
        [caller_node, result_node],
      ]
      @graph.store_metod_subgraph(metod.id, {}, caller_node, result_node, yields, all_nodes, all_edges)
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

    def template_caller_id(klass, name)
      metod = add_method(klass.id, name, :public, GlobalTree::ArgumentsTree.new([], []))
      caller_node = Node.new(:caller, {})
      result_node = Node.new(:method_result, {})
      all_nodes = [caller_node, result_node]
      all_edges = [
        [caller_node, result_node]
      ]
      @graph.store_metod_subgraph(metod.id, {}, caller_node, result_node, [], all_nodes, all_edges)
    end

    def addm_object_class(klass)
      metod = add_method(klass.id, :class, :public, GlobalTree::ArgumentsTree.new([], []))
      caller_node = Node.new(:caller, {})
      extract_class_node = Node.new(:extract_class, {})
      result_node = Node.new(:method_result, {})
      all_nodes = [caller_node, extract_class_node, result_node]
      all_edges = [
        [caller_node, extract_class_node],
        [extract_class_node, result_node]
      ]
      @graph.store_metod_subgraph(metod.id, {}, caller_node, result_node, [], all_nodes, all_edges)
    end

    def template_args(klass, name)
      metod = add_method(klass.id, name, :public, GlobalTree::ArgumentsTree.new([], []))
      @graph.store_metod_nodes(metod.id, {})
      metod
    end

    def add_method(class_id, name, visibility, args)
      @tree.add_method(generate_id, class_id, name, nil, visibility, args)
    end

    def generate_id
      id_generator.call
    end
  end
end
