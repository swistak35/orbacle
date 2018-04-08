require 'rgl/adjacency'

module Orbacle
  class TypingService
    class DoubleEdgedGraph
      def initialize(graph)
        @original = graph
        @reversed = graph.reverse
      end

      def add_vertex(node)
        @original.add_vertex(node)
        @reversed.add_vertex(node)
      end

      def add_edge(u, v)
        @original.add_edge(u, v)
        @reversed.add_edge(v, u)
      end

      attr_reader :original, :reversed
    end

    class NominalType < Struct.new(:name)
      def each_possible_type
        yield self
      end

      def pretty
        name
      end
    end
    class ClassType < Struct.new(:name)
      def each_possible_type
        yield self
      end

      def pretty
        "class(#{name})"
      end
    end
    class MainType
      def each_possible_type
      end

      def pretty
        "main"
      end
    end
    class UnionType < Struct.new(:types)
      def each_possible_type
        types.each do |type|
          yield type
        end
      end

      def pretty
        "Union(#{types.map {|t| t.nil? ? "nil" : t.pretty }.join(" or ")})"
      end
    end
    class GenericType < Struct.new(:name, :parameters)
      def each_possible_type
        yield self
      end

      def pretty
        "generic(#{name}, [#{parameters.map {|t| t.nil? ? "nil" : t.pretty }.join(", ")}])"
      end
    end

    def call(graph, worklist, tree)
      @graph = DoubleEdgedGraph.new(graph)
      @tree = tree

      @result = {}

      @worklist = Set.new(@graph.original.vertices)
      while !@worklist.empty?
        current_worklist = @worklist
        @worklist = Set.new

        current_worklist.each do |node|
          current_result = @result[node]
          @result[node] = compute_result(node, @graph.reversed.adjacent_vertices(node))
          if current_result != @result[node]
            @graph.original.adjacent_vertices(node).each do |adjacent_node|
              @worklist << adjacent_node
            end
          end
        end

        worklist.message_sends.each do |message_send|
          if message_send.is_a?(Worklist::MessageSend) && satisfied_message_send?(message_send) && !worklist.handled_message_sends.include?(message_send)
            handle_message_send(message_send, graph)
            worklist.handled_message_sends << message_send
          end
        end
      end

      return @result
    end

    def compute_result(node, sources)
      case node.type
      when :int then handle_int(node, sources)
      when :float then handle_float(node, sources)
      when :nil then handle_nil(node, sources)
      when :bool then handle_bool(node, sources)

      when :str then handle_just_string(node, sources)
      when :dstr then handle_just_string(node, sources)

      when :sym then handle_just_symbol(node, sources)
      when :dsym then handle_just_symbol(node, sources)

      when :regexp then handle_regexp(node, sources)

      when :hash_keys then handle_group(node, sources)
      when :hash_values then handle_group(node, sources)
      when :hash then handle_hash(node, sources)

      when :defined then handle_maybe_string(node, sources)

      when :casgn then handle_group(node, sources)

      when :range_from then handle_group(node, sources)
      when :range_to then handle_group(node, sources)
      when :range then handle_range(node, sources)
      when :self then handle_self(node, sources)
      when :lvar then handle_group(node, sources)
      when :array then handle_group_into_array(node, sources)
      when :splat_array then handle_unwrap_array(node, sources)
      when :lvasgn then handle_pass_lte1(node, sources)
      when :call_obj then handle_pass1(node, sources)
      when :call_result then handle_pass_lte1(node, sources)
      when :call_arg then handle_group(node, sources)
      when :formal_arg then handle_group(node, sources)
      when :formal_optarg then handle_group(node, sources)
      when :formal_restarg then handle_group_into_array(node, sources)
      when :formal_kwarg then handle_group(node, sources)
      when :formal_kwoptarg then handle_group(node, sources)
      when :formal_kwrestarg then handle_pass_lte1(node, sources)
      when :block_arg then handle_group(node, sources)
      when :block_result then handle_pass_lte1(node, sources)
      when :primitive_array_map_1 then handle_primitive_array_map_1(node, sources)
      when :primitive_array_map_2 then handle_primitive_array_map_2(node, sources)
      when :unwrap_hash_values then handle_unwrap_hash_values(node, sources)
      when :unwrap_hash_keys then handle_unwrap_hash_keys(node, sources)
      when :const then handle_const(node, sources)
      when :const_definition then handle_group(node, sources)
      when :constructor then handle_constructor(node, sources)
      when :method_result then handle_group(node, sources)

      when :yield then handle_group(node, sources)

      when :gvasgn then handle_group(node, sources)
      when :gvar_definition then handle_group(node, sources)
      when :gvar then handle_pass1(node, sources)
      when :backref then handle_just_string(node, sources)
      when :nthref then handle_just_string(node, sources)

      when :ivasgn then handle_group(node, sources)
      when :ivar_definition then handle_group(node, sources)
      when :clivar_definition then handle_group(node, sources)
      when :ivar then handle_pass1(node, sources)


      # below not really tested
      when :if_result then handle_group(node, sources)

      when :case_result then handle_group(node, sources)

      when :and then handle_bool(node, sources)
      when :or then handle_bool(node, sources)

      when :class then handle_nil(node, sources)

      when :unwrap_array then handle_primitive_array_map_1(node, sources)
      when :rescue then handle_nil(node, sources)

      when :lambda then handle_nil(node, sources)

      else raise ArgumentError.new(node.type)
      end
    end

    def handle_int(node, sources)
      NominalType.new("Integer")
    end

    def handle_regexp(_node, _sources)
      NominalType.new("Regexp")
    end

    def handle_nil(_node, _sources)
      NominalType.new("nil")
    end

    def handle_bool(*args)
      NominalType.new("Boolean")
    end

    def handle_float(*args)
      NominalType.new("Float")
    end

    def handle_just_string(node, sources)
      NominalType.new("String")
    end

    def handle_maybe_string(node, sources)
      build_union([NominalType.new("String"), NominalType.new("nil")])
    end

    def handle_just_symbol(node, sources)
      NominalType.new("Symbol")
    end

    def handle_unwrap_hash_keys(node, sources)
      raise if sources.size > 1
      @result[sources.first]&.parameters&.at(0)
    end

    def handle_unwrap_hash_values(node, sources)
      raise if sources.size > 1
      @result[sources.first]&.parameters&.at(1)
    end

    def handle_group(node, sources)
      sources_types = sources.map {|source_node| @result[source_node] }.compact.uniq
      build_union(sources_types)
    end

    def handle_pass1(node, sources)
      raise if sources.size != 1
      source = sources.first
      @result[source]
    end

    def handle_hash(_node, sources)
      hash_keys_node = sources.find {|s| s.type == :hash_keys }
      hash_values_node = sources.find {|s| s.type == :hash_values }
      GenericType.new("Hash", [@result[hash_keys_node], @result[hash_values_node]])
    end

    def handle_range(node, sources)
      sources_types = sources.map {|source_node| @result[source_node] }.compact.uniq
      GenericType.new("Range", [build_union(sources_types)])
    end

    def handle_self(node, sources)
      selfie = node.params.fetch(:selfie)
      if selfie.klass?
        ClassType.new(selfie.scope.absolute_str)
      elsif selfie.instance?
        NominalType.new(selfie.scope.absolute_str)
      else
        MainType.new
      end
    end

    def handle_group_into_array(_node, sources)
      sources_types = sources.map {|source_node| @result[source_node] }.compact.uniq
      GenericType.new("Array", [build_union(sources_types)])
    end

    def handle_unwrap_array(node, sources)
      types_inside_arrays = sources.select {|s| @result[s] && @result[s].name == "Array" }.map {|s| @result[s].parameters.first }.uniq
      build_union(types_inside_arrays)
    end

    def handle_pass_lte1(_node, sources)
      raise if sources.size > 1
      @result[sources.first]
    end

    def build_union(sources_types)
      if sources_types.size == 0
        nil
      elsif sources_types.size == 1
        sources_types.first
      else
        UnionType.new(sources_types)
      end
    end

    def handle_const(node, sources)
      const_ref = node.params.fetch(:const_ref)
      ref_result = @tree.solve_reference(const_ref)
      if !sources.empty?
        handle_group(node, sources)
      else
        if ref_result && @tree.nodes.constants[ref_result.full_name]
          const_definition_node = @tree.nodes.constants[ref_result.full_name]
          @graph.add_edge(const_definition_node, node)
          @worklist << const_definition_node
          @result[const_definition_node]
        else
          ClassType.new(const_ref.full_name)
        end
      end
    end

    def satisfied_message_send?(message_send)
      @result[message_send.send_obj] &&
        message_send.send_args.all? {|a| @result[a] }
    end

    def handle_message_send(message_send, graph)
      message_name = message_send.message_send
      @result[message_send.send_obj].each_possible_type do |possible_type|
        if constructor_send?(possible_type, message_send.message_send)
          handle_constructor_send(possible_type.name, possible_type.name, message_send)
        else
          handle_instance_send(possible_type.name, message_send)
        end
      end
    end

    def handle_constructor_send(original_class_name, class_name, message_send)
      found_method = @tree.metods.find {|m| m.scope.to_s == class_name && m.name == "initialize" }
      if found_method.nil?
        parent_name = @tree.get_parent_of(class_name)
        if parent_name
          handle_constructor_send(original_class_name, parent_name, message_send)
        else
          node = DataFlowGraph::Node.new(:constructor, { name: original_class_name })
          @graph.add_vertex(node)
          @graph.add_edge(node, message_send.send_result)
          @worklist << node
        end
      else
        handle_custom_message_send(found_method, message_send)

        node = DataFlowGraph::Node.new(:constructor, { name: class_name })
        @graph.add_vertex(node)
        @graph.add_edge(node, message_send.send_result)
        @worklist << node
      end
    end

    def handle_instance_nonprimitive_send(class_name, message_send)
      found_method = @tree.find_instance_method(class_name, message_send.message_send)
      if found_method.nil?
        parent_name = @tree.get_parent_of(class_name)
        if parent_name
          handle_instance_send(parent_name, message_send)
        else
          warn("Method #{message_send.message_send} not found\n")
        end
      else
        handle_custom_message_send(found_method, message_send)

        method_result_node = found_method.nodes.result
        if !@graph.original.has_edge?(method_result_node, message_send.send_result)
          @graph.add_edge(method_result_node, message_send.send_result)
          @worklist << message_send.send_result
        end
      end
    end

    def handle_custom_message_send(found_method, message_send)
      if found_method.args.kwargs.empty?
        regular_args = message_send.send_args[0..-1]
        kwarg_arg = nil
      else
        regular_args = message_send.send_args[0..-2]
        kwarg_arg = message_send.send_args[-1]
      end
      found_method.args.args.each_with_index do |formal_arg, i|
        next if formal_arg.name.nil?
        node_formal_arg = found_method.nodes.args[formal_arg.name]

        case formal_arg
        when GlobalTree::Method::ArgumentsTree::Regular
          @graph.add_edge(regular_args[i], node_formal_arg)
          @worklist << node_formal_arg
        when GlobalTree::Method::ArgumentsTree::Optional
          if regular_args[i]
            @graph.add_edge(regular_args[i], node_formal_arg)
            @worklist << node_formal_arg
          end
        when GlobalTree::Method::ArgumentsTree::Splat
          regular_args[i..-1].each do |send_arg|
            @graph.add_edge(send_arg, node_formal_arg)
            @worklist << node_formal_arg
          end
        else raise
        end
      end

      if kwarg_arg
        unwrapping_node = DataFlowGraph::Node.new(:unwrap_hash_values)
        @graph.add_vertex(unwrapping_node)
        @graph.add_edge(kwarg_arg, unwrapping_node)
        @worklist << unwrapping_node

        found_method.args.kwargs.each do |formal_kwarg|
          next if formal_kwarg.name.nil?
          node_formal_kwarg = found_method.nodes.args[formal_kwarg.name]

          case formal_kwarg
          when GlobalTree::Method::ArgumentsTree::Regular
            @graph.add_edge(unwrapping_node, node_formal_kwarg)
            @worklist << node_formal_kwarg
          when GlobalTree::Method::ArgumentsTree::Optional
            @graph.add_edge(unwrapping_node, node_formal_kwarg)
            @worklist << node_formal_kwarg
          when GlobalTree::Method::ArgumentsTree::Splat
            @graph.add_edge(kwarg_arg, node_formal_kwarg)
            @worklist << node_formal_kwarg
          else raise
          end
        end
      end

      if !found_method.nodes.yields.empty?
        found_method.nodes.yields.each do |node_yield|
          @graph.add_edge(node_yield, message_send.block.args[0])
          @worklist << message_send.block.args[0]
        end
      end
    end

    def handle_instance_send(class_name, message_send)
      if primitive_send?(class_name, message_send.message_send)
        handle_primitive(class_name, message_send)
      else
        handle_instance_nonprimitive_send(class_name, message_send)
      end
    end

    def primitive_mapping
      {
        "Integer" => {
          "succ" => method(:send_primitive_templ_just_int),
          "to_s" => method(:send_primitive_templ_just_str),
          "+" => method(:send_primitive_templ_just_int),
          "-" => method(:send_primitive_templ_just_int),
          "*" => method(:send_primitive_templ_just_int),
        },
        "Array" => {
          "map" => method(:send_primitive_array_map),
        },
      }
    end

    def primitive_send?(class_name, message_name)
      if primitive_mapping[class_name] && primitive_mapping[class_name][message_name]
        true
      else
        false
      end
    end

    def constructor_send?(type, message_name)
      type.is_a?(ClassType) && message_name == "new"
    end

    def handle_primitive(class_name, message_send)
      message_name = message_send.message_send
      primitive_mapping[class_name][message_name].(class_name, message_send)
    end

    def send_constructor(type, message_send)
      already_handled = @graph.original.adjacent_vertices(message_send.send_obj).any? do |adjacent_node|
        adjacent_node.type == :constructor
      end
      return if already_handled

      node = DataFlowGraph::Node.new(:constructor, { name: type.name })
      @graph.add_vertex(node)
      @graph.add_edge(message_send.send_obj, node)
      @worklist << node
      @graph.add_edge(node, message_send.send_result)
      @worklist << message_send.send_result
    end

    def send_primitive_templ_just_int(_class_name, message_send)
      node = DataFlowGraph::Node.new(:int)
      @graph.add_vertex(node)
      @graph.add_edge(node, message_send.send_result)
      @worklist << node
    end

    def send_primitive_templ_just_str(_class_name, message_send)
      node = DataFlowGraph::Node.new(:str)
      @graph.add_vertex(node)
      @graph.add_edge(node, message_send.send_result)
      @worklist << node
    end

    def send_primitive_array_map(_class_name, message_send)
      raise if message_send.block.nil?

      unwrapping_node = DataFlowGraph::Node.new(:primitive_array_map_1)
      @graph.add_vertex(unwrapping_node)
      @graph.add_edge(message_send.send_obj, unwrapping_node)
      @worklist << unwrapping_node
      @graph.add_edge(unwrapping_node, message_send.block.args.first)
      @worklist << message_send.block.args.first

      wrapping_node = DataFlowGraph::Node.new(:primitive_array_map_2)
      @graph.add_vertex(wrapping_node)
      @graph.add_edge(message_send.block.result, wrapping_node)
      @worklist << wrapping_node
      @graph.add_edge(wrapping_node, message_send.send_result)
      @worklist << message_send.send_result
    end

    def handle_primitive_array_map_1(_node, sources)
      raise if sources.size != 1
      source = sources.first
      @result[source].parameters.first
    end

    def handle_primitive_array_map_2(_node, sources)
      raise if sources.size != 1
      source = sources.first
      GenericType.new("Array", [@result[source]])
    end

    def handle_constructor(node, sources)
      NominalType.new(node.params.fetch(:name))
    end

    def warn(msg)
      puts "Warning: #{msg}"
    end
  end
end
