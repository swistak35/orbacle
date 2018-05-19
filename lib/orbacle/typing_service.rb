module Orbacle
  class TypingService
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

      def ==(other)
        self.class == other.class
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
      @worklist = worklist
      @graph = graph
      @tree = tree

      @result = {}

      @worklist.nodes = @graph.vertices.to_a
      while !@worklist.nodes.empty?
        while !@worklist.nodes.empty?
          node = @worklist.nodes.shift
          @worklist.count_node(node)
          if !@worklist.limit_exceeded?(node)
            current_result = @result[node]
            @result[node] = compute_result(node, @graph.parent_vertices(node))
            if current_result != @result[node]
              @graph.adjacent_vertices(node).each do |adjacent_node|
                @worklist.enqueue_node(adjacent_node)
              end
            end
          end
        end

        @worklist.message_sends.each do |message_send|
          case message_send
          when Worklist::MessageSend
            if satisfied_message_send?(message_send) && !@worklist.message_send_handled?(message_send)
              handle_message_send(message_send)
              @worklist.mark_message_send_as_handled(message_send)
            end
          when Worklist::SuperSend
            if satisfied_super_send?(message_send) && !@worklist.message_send_handled?(message_send)
              handle_super_send(message_send)
              @worklist.mark_message_send_as_handled(message_send)
            end
          else raise "Not handled message send"
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
      when :bottom then handle_bottom(node, sources)

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
      when :array then handle_wrap_array(node, sources)
      when :splat_array then handle_unwrap_array(node, sources)
      when :lvasgn then handle_pass_lte1(node, sources)
      when :call_obj then handle_pass1(node, sources)
      when :call_result then handle_group(node, sources)
      when :call_arg then handle_group(node, sources)
      when :formal_arg then handle_group(node, sources)
      when :formal_optarg then handle_group(node, sources)
      when :formal_restarg then handle_wrap_array(node, sources)
      when :formal_kwarg then handle_group(node, sources)
      when :formal_kwoptarg then handle_group(node, sources)
      when :formal_kwrestarg then handle_pass_lte1(node, sources)
      when :block_arg then handle_group(node, sources)
      when :block_result then handle_pass_lte1(node, sources)
      when :unwrap_hash_values then handle_unwrap_hash_values(node, sources)
      when :unwrap_hash_keys then handle_unwrap_hash_keys(node, sources)
      when :const then handle_const(node, sources)
      when :const_definition then handle_group(node, sources)
      when :constructor then handle_constructor(node, sources)
      when :method_result then handle_group(node, sources)
      when :method_caller then handle_group(node, sources)

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
      when :extract_class then handle_extract_class(node, sources)


      # below not really tested
      when :if_result then handle_group(node, sources)

      when :case_result then handle_group(node, sources)

      when :and then handle_bool(node, sources)
      when :or then handle_bool(node, sources)

      when :class then handle_nil(node, sources)

      when :unwrap_array then handle_unwrap_array(node, sources)
      when :wrap_array then handle_wrap_array(node, sources)
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

    def handle_bottom(node, sources)
      nil
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
      elsif selfie.main?
        MainType.new
      else
        raise
      end
    end

    def handle_unwrap_array(node, sources)
      types_inside_arrays = []
      sources
        .select {|s| @result[s] }
        .each do |s|
          @result[s].each_possible_type do |t|
            if t.name == "Array"
              types_inside_arrays << t.parameters.first
            end
          end
        end
      build_union(types_inside_arrays.uniq)
    end

    def handle_wrap_array(_node, sources)
      GenericType.new("Array", [build_union(sources.map {|s| @result[s] }.uniq)])
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
        UnionType.new(sources_types.flat_map {|t| get_possible_types(t) }.uniq)
      end
    end

    def get_possible_types(type)
      case type
      when UnionType then type.types.flat_map {|t| get_possible_types(t) }
      else [type]
      end
    end

    def handle_const(node, sources)
      const_ref = node.params.fetch(:const_ref)
      ref_result = @tree.solve_reference(const_ref)
      if !sources.empty?
        handle_group(node, sources)
      else
        if ref_result && @graph.constants[ref_result.full_name]
          const_definition_node = @graph.constants[ref_result.full_name]
          @graph.add_edge(const_definition_node, node)
          @worklist.enqueue_node(const_definition_node)
          @result[const_definition_node]
        elsif ref_result
          ClassType.new(ref_result.full_name)
        else
          ClassType.new(const_ref.full_name)
        end
      end
    end

    def handle_extract_class(node, sources)
      res = sources.map do |source|
        extract_class(@result[sources.first])
      end
      build_union(res)
    end

    def extract_class(type)
      case type
      when NominalType then ClassType.new(type.name)
      when GenericType then ClassType.new(type.name)
      when ClassType then ClassType.new("Class")
      when UnionType then build_union(type.types.map {|t| extract_class(t) })
      when MainType then ClassType.new("Object")
      end
    end

    def satisfied_message_send?(message_send)
      @result[message_send.send_obj] &&
        message_send.send_args.all? {|a| @result[a] }
    end

    def satisfied_super_send?(super_send)
      super_send.send_args.all? {|a| @result[a] }
    end

    def handle_message_send(message_send)
      @result[message_send.send_obj].each_possible_type do |possible_type|
        if constructor_send?(possible_type, message_send.message_send)
          handle_constructor_send(possible_type.name, possible_type.name, message_send)
        elsif possible_type.is_a?(ClassType)
          handle_class_send(possible_type.name, message_send)
        else
          handle_instance_send(possible_type.name, message_send)
        end
      end
    end

    def handle_constructor_send(original_class_name, class_name, message_send)
      found_method = @tree.find_instance_method(class_name, "initialize")
      if found_method.nil?
        parent_name = @tree.get_parent_of(class_name)
        if parent_name
          handle_constructor_send(original_class_name, parent_name, message_send)
        else
          connect_constructor_to_node(original_class_name, message_send.send_result)
        end
      else
        handle_custom_message_send(found_method, message_send)
        connect_constructor_to_node(class_name, message_send.send_result)
      end
    end

    def connect_constructor_to_node(class_name, node)
      constructor_node = DataFlowGraph::Node.new(:constructor, { name: class_name }, nil)
      @graph.add_vertex(constructor_node)
      @graph.add_edge(constructor_node, node)
      @worklist.enqueue_node(constructor_node)
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
        connect_method_result_to_node(found_method.id, message_send.send_result)

        method_nodes = @graph.get_metod_nodes(found_method.id)
        if !@graph.has_edge?(message_send.send_obj, method_nodes.caller)
          @graph.add_edge(message_send.send_obj, method_nodes.caller)
          @worklist.enqueue_node(method_nodes.caller)
        end
      end
    end

    def handle_class_nonprimitive_send(class_name, message_send)
      found_method = @tree.find_class_method(class_name, message_send.message_send)
      if found_method.nil?
        parent_name = @tree.get_parent_of(class_name)
        if parent_name
          handle_class_send(parent_name, message_send)
        else
          warn("Method #{message_send.message_send} not found\n")
        end
      else
        handle_custom_message_send(found_method, message_send)
        connect_method_result_to_node(found_method.id, message_send.send_result)
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
        found_method_args = @graph.get_metod_nodes(found_method.id).args
        node_formal_arg = found_method_args[formal_arg.name]

        case formal_arg
        when GlobalTree::Method::ArgumentsTree::Regular
          @graph.add_edge(regular_args[i], node_formal_arg)
          @worklist.enqueue_node(node_formal_arg)
        when GlobalTree::Method::ArgumentsTree::Optional
          if regular_args[i]
            @graph.add_edge(regular_args[i], node_formal_arg)
            @worklist.enqueue_node(node_formal_arg)
          end
        when GlobalTree::Method::ArgumentsTree::Splat
          regular_args[i..-1].each do |send_arg|
            @graph.add_edge(send_arg, node_formal_arg)
            @worklist.enqueue_node(node_formal_arg)
          end
        else raise
        end
      end

      if kwarg_arg
        unwrapping_node = DataFlowGraph::Node.new(:unwrap_hash_values, {}, nil)
        @graph.add_vertex(unwrapping_node)
        @graph.add_edge(kwarg_arg, unwrapping_node)
        @worklist.enqueue_node(unwrapping_node)

        found_method.args.kwargs.each do |formal_kwarg|
          next if formal_kwarg.name.nil?
          node_formal_kwarg = @graph.get_metod_nodes(found_method.id).args[formal_kwarg.name]

          case formal_kwarg
          when GlobalTree::Method::ArgumentsTree::Regular
            @graph.add_edge(unwrapping_node, node_formal_kwarg)
            @worklist.enqueue_node(node_formal_kwarg)
          when GlobalTree::Method::ArgumentsTree::Optional
            @graph.add_edge(unwrapping_node, node_formal_kwarg)
            @worklist.enqueue_node(node_formal_kwarg)
          when GlobalTree::Method::ArgumentsTree::Splat
            @graph.add_edge(kwarg_arg, node_formal_kwarg)
            @worklist.enqueue_node(node_formal_kwarg)
          else raise
          end
        end
      end

      if !@graph.get_metod_nodes(found_method.id).yields.empty?
        @graph.get_metod_nodes(found_method.id).yields.each do |node_yield|
          @graph.add_edge(node_yield, message_send.block.args[0])
          @worklist.enqueue_node(message_send.block.args[0])
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

    def handle_class_send(class_name, message_send)
      if primitive_class_send?(class_name, message_send.message_send)
        handle_class_primitive(class_name, message_send)
      else
        handle_class_nonprimitive_send(class_name, message_send)
      end
    end

    def handle_super_send(super_send)
      super_method = @tree.find_super_method(super_send.method_id)
      return if super_method.nil?

      handle_custom_message_send(super_method, super_send)

      connect_method_result_to_node(super_method.id, super_send.send_result)
    end

    def connect_method_result_to_node(method_id, node)
      method_result_node = @graph.get_metod_nodes(method_id).result
      if !@graph.has_edge?(method_result_node, node)
        @graph.add_edge(method_result_node, node)
        @worklist.enqueue_node(node)
      end
    end

    def primitive_mapping
      {
        "Array" => {
          "map" => method(:send_primitive_array_map),
          "each" => method(:send_primitive_array_each),
        },
        "Object" => {
          "freeze" => method(:send_primitive_object_freeze),
          "class" => method(:send_primitive_object_class),
        },
      }
    end

    def primitive_class_mapping
      {
        "Object" => {
          "class" => method(:send_class_primitive_object_class),
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

    def primitive_class_send?(class_name, message_name)
      if primitive_class_mapping[class_name] && primitive_class_mapping[class_name][message_name]
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

    def handle_class_primitive(class_name, message_send)
      message_name = message_send.message_send
      primitive_class_mapping[class_name][message_name].(class_name, message_send)
    end

    def send_constructor(type, message_send)
      already_handled = @graph.adjacent_vertices(message_send.send_obj).any? do |adjacent_node|
        adjacent_node.type == :constructor
      end
      return if already_handled

      node = DataFlowGraph::Node.new(:constructor, { name: type.name }, nil)
      @graph.add_vertex(node)
      @graph.add_edge(message_send.send_obj, node)
      @worklist.enqueue_node(node)
      @graph.add_edge(node, message_send.send_result)
      @worklist.enqueue_node(message_send.send_result)
    end

    def send_primitive_array_map(_class_name, message_send)
      raise if message_send.block.nil?

      unwrapping_node = DataFlowGraph::Node.new(:unwrap_array, {}, nil)
      @graph.add_vertex(unwrapping_node)
      @graph.add_edge(message_send.send_obj, unwrapping_node)
      @worklist.enqueue_node(unwrapping_node)
      @graph.add_edge(unwrapping_node, message_send.block.args.first)
      @worklist.enqueue_node(message_send.block.args.first)

      wrapping_node = DataFlowGraph::Node.new(:wrap_array, {}, nil)
      @graph.add_vertex(wrapping_node)
      @graph.add_edge(message_send.block.result, wrapping_node)
      @worklist.enqueue_node(wrapping_node)
      @graph.add_edge(wrapping_node, message_send.send_result)
      @worklist.enqueue_node(message_send.send_result)
    end

    def send_primitive_array_each(_class_name, message_send)
      raise if message_send.block.nil?

      unwrapping_node = DataFlowGraph::Node.new(:unwrap_array, {}, nil)
      @graph.add_vertex(unwrapping_node)
      @graph.add_edge(message_send.send_obj, unwrapping_node)
      @worklist.enqueue_node(unwrapping_node)
      @graph.add_edge(unwrapping_node, message_send.block.args.first)
      @worklist.enqueue_node(message_send.block.args.first)

      @graph.add_edge(message_send.send_obj, message_send.send_result)
      @worklist.enqueue_node(message_send.send_result)
    end

    def send_primitive_object_freeze(_class_name, message_send)
      @graph.add_edge(message_send.send_obj, message_send.send_result)
      @worklist.enqueue_node(message_send.send_result)
    end

    def send_primitive_object_class(_class_name, message_send)
      extract_class_node = DataFlowGraph::Node.new(:extract_class, {}, nil)
      @graph.add_vertex(extract_class_node)
      @graph.add_edge(message_send.send_obj, extract_class_node)
      @worklist.enqueue_node(extract_class_node)

      @graph.add_edge(extract_class_node, message_send.send_result)
      @worklist.enqueue_node(message_send.send_result)
    end

    def send_class_primitive_object_class(_class_name, message_send)
      extract_class_node = DataFlowGraph::Node.new(:extract_class, {}, nil)
      @graph.add_vertex(extract_class_node)
      @graph.add_edge(message_send.send_obj, extract_class_node)
      @worklist.enqueue_node(extract_class_node)

      @graph.add_edge(extract_class_node, message_send.send_result)
      @worklist.enqueue_node(message_send.send_result)
    end

    def handle_constructor(node, sources)
      NominalType.new(node.params.fetch(:name))
    end

    def warn(msg)
      puts "Warning: #{msg}"
    end
  end
end
