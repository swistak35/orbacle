module Orbacle
  class TypingService
    def initialize(logger)
      @logger = logger
    end

    def call(graph, worklist, tree)
      @worklist = worklist
      @graph = graph
      @tree = tree

      @result = Hash.new {|h,k| h[k] = BottomType.new }
      def @result.[]=(key, newvalue)
        raise ArgumentError if newvalue.nil?
        super
      end

      processed_nodes = 0
      timestamp_started_processing = Time.now.to_i

      @graph.vertices.to_a.each {|v| @worklist.enqueue_node(v) }
      while !@worklist.nodes.empty?
        while !@worklist.nodes.empty?
          while !@worklist.nodes.empty?
            node = @worklist.pop_node
            @worklist.count_node(node)
            if !@worklist.limit_exceeded?(node)
              current_result = @result[node]
              @result[node] = compute_result(node, @graph.parent_vertices(node))
              processed_nodes += 1
              puts "Processed nodes: #{processed_nodes} remaining nodes #{@worklist.nodes.size} msends #{@worklist.handled_message_sends.size} / #{@worklist.message_sends.size} #{Time.now.to_i - timestamp_started_processing}" if processed_nodes % 1000 == 0

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
            when Worklist::Super0Send
              if !@worklist.message_send_handled?(message_send)
                handle_super0_send(message_send)
                @worklist.mark_message_send_as_handled(message_send)
              end
            else raise "Not handled message send"
            end
          end
        end

        @worklist.message_sends.each do |message_send|
          case message_send
          when Worklist::MessageSend
            if !@worklist.message_send_handled?(message_send)
              handle_message_send(message_send)
              @worklist.mark_message_send_as_handled(message_send)
            end
          when Worklist::SuperSend
            if !@worklist.message_send_handled?(message_send)
              handle_super_send(message_send)
              @worklist.mark_message_send_as_handled(message_send)
            end
          when Worklist::Super0Send
            if !@worklist.message_send_handled?(message_send)
              handle_super0_send(message_send)
              @worklist.mark_message_send_as_handled(message_send)
            end
          else raise "Not handled message send"
          end
        end
      end

      return @result
    end

    private
    attr_reader :logger

    def compute_result(node, sources)
      case node.type
      when :int then handle_int(node, sources)
      when :float then handle_float(node, sources)
      when :nil then handle_nil(node, sources)
      when :bool then handle_bool(node, sources)
      when :str then handle_just_string(node, sources)
      when :dstr then handle_just_string(node, sources)
      when :xstr then handle_just_string(node, sources)
      when :sym then handle_just_symbol(node, sources)
      when :dsym then handle_just_symbol(node, sources)
      when :regexp then handle_regexp(node, sources)

      when :array then handle_wrap_array(node, sources)
      when :splat_array then handle_unwrap_array(node, sources)

      when :hash_keys then handle_group(node, sources)
      when :hash_values then handle_group(node, sources)
      when :hash then handle_hash(node, sources)

      when :range_from then handle_group(node, sources)
      when :range_to then handle_group(node, sources)
      when :range then handle_range(node, sources)

      when :lvar then handle_group(node, sources)
      when :lvasgn then handle_pass_lte1(node, sources)

      when :ivasgn then handle_group(node, sources)
      when :ivar_definition then handle_group(node, sources)
      when :clivar_definition then handle_group(node, sources)
      when :ivar then handle_pass1(node, sources)

      when :cvasgn then handle_group(node, sources)
      when :cvar_definition then handle_group(node, sources)
      when :cvar then handle_pass1(node, sources)

      when :gvasgn then handle_group(node, sources)
      when :gvar_definition then handle_group(node, sources)
      when :gvar then handle_pass1(node, sources)
      when :backref then handle_just_string(node, sources)
      when :nthref then handle_just_string(node, sources)

      when :defined then handle_maybe_string(node, sources)

      when :casgn then handle_group(node, sources)
      when :const then handle_const(node, sources)

      when :self then handle_self(node, sources)

      when :call_obj then handle_pass1(node, sources)
      when :call_result then handle_group(node, sources)
      when :call_arg then handle_group(node, sources)
      when :call_splatarg then handle_group(node, sources)
      when :formal_arg then handle_group(node, sources)
      when :formal_optarg then handle_group(node, sources)
      when :formal_restarg then handle_wrap_array(node, sources)
      when :formal_kwarg then handle_group(node, sources)
      when :formal_kwoptarg then handle_group(node, sources)
      when :formal_kwrestarg then handle_pass_lte1(node, sources)
      when :formal_blockarg then handle_group(node, sources)
      when :block_result then handle_pass_lte1(node, sources)

      when :loop_operator then handle_bottom(node, sources)

      when :rescue then handle_group(node, sources)
      when :ensure then handle_group(node, sources)
      when :retry then handle_bottom(node, sources)
      when :unwrap_error_array then handle_unwrap_error_array(node, sources)

      when :if_result then handle_group(node, sources)

      when :and then handle_and(node, sources)
      when :or then handle_or(node, sources)

      when :unwrap_array then handle_unwrap_array(node, sources)
      when :wrap_array then handle_wrap_array(node, sources)

      when :case_result then handle_group(node, sources)

      # not really tested
      when :dynamic_const then handle_bottom(node, sources)
      when :unwrap_hash_values then handle_unwrap_hash_values(node, sources)
      when :unwrap_hash_keys then handle_unwrap_hash_keys(node, sources)
      when :const_definition then handle_group(node, sources)
      when :constructor then handle_constructor(node, sources)
      when :method_result then handle_group(node, sources)
      when :yield then handle_group(node, sources)
      when :extract_class then handle_extract_class(node, sources)
      when :lambda then handle_nil(node, sources)
      when :definition_by_id then handle_definition_by_id(node, sources)
      when :yield_result then handle_group(node, sources)

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
      NominalType.new("Nil")
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

    def handle_and(node, sources)
      build_union([
        handle_group(node, sources),
        NominalType.new("Boolean"),
        NominalType.new("Nil"),
      ])
    end

    def handle_or(node, sources)
      build_union([
        handle_group(node, sources),
        NominalType.new("Boolean"),
        NominalType.new("Nil"),
      ])
    end

    def handle_maybe_string(node, sources)
      build_union([NominalType.new("String"), NominalType.new("Nil")])
    end

    def handle_just_symbol(node, sources)
      NominalType.new("Symbol")
    end

    def handle_bottom(node, sources)
      BottomType.new
    end

    def handle_unwrap_hash_keys(node, sources)
      raise if sources.size != 1
      source = sources.first
      if @result[source].is_a?(GenericType)
        @result[source].parameters.at(0)
      else
        BottomType.new
      end
    end

    def handle_unwrap_hash_values(node, sources)
      raise if sources.size != 1
      source = sources.first
      if @result[source].is_a?(GenericType)
        @result[source].parameters.at(1)
      else
        BottomType.new
      end
    end

    def handle_group(node, sources)
      sources_types = sources.map {|source_node| @result[source_node] }
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
      sources_types = sources.map {|source_node| @result[source_node] }
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
        .each do |s|
          @result[s].each_possible_type do |t|
            if t.name == "Array"
              types_inside_arrays << t.parameters.first
            end
          end
        end
      build_union(types_inside_arrays)
    end

    def handle_unwrap_error_array(node, sources)
      result = []
      handle_unwrap_array(node, sources).each_possible_type do |t|
        if t.is_a?(ClassType)
          result << NominalType.new(t.name)
        end
      end
      build_union(result)
    end

    def handle_wrap_array(_node, sources)
      GenericType.new("Array", [build_union(sources.map {|s| @result[s] })])
    end

    def handle_pass_lte1(_node, sources)
      raise if sources.size > 1
      @result[sources.first]
    end

    def build_union(sources_types)
      sources_types_without_unknowns = sources_types.compact.reject(&:bottom?).uniq
      if sources_types_without_unknowns.size == 0
        BottomType.new
      elsif sources_types_without_unknowns.size == 1
        sources_types_without_unknowns.first
      else
        UnionType.new(sources_types_without_unknowns.flat_map {|t| get_possible_types(t) }.uniq)
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

    def defined_type?(t)
      t.class != BottomType
    end

    def satisfied_message_send?(message_send)
      defined_type?(@result[message_send.send_obj]) &&
        message_send.send_args.all? {|a| defined_type?(@result[a]) }
    end

    def satisfied_super_send?(super_send)
      super_send.send_args.all? {|a| defined_type?(@result[a]) }
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
      constructor_node = Node.new(:constructor, { name: class_name }, nil)
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
          logger.warn("Method #{message_send.message_send} not found\n")
        end
      else
        handle_custom_message_send(found_method, message_send)
        connect_method_result_to_node(found_method.id, message_send.send_result)
      end
    end

    def handle_class_nonprimitive_send(class_name, message_send)
      found_method = @tree.find_class_method(class_name, message_send.message_send)
      if found_method.nil?
        parent_name = @tree.get_parent_of(class_name)
        if parent_name
          handle_class_send(parent_name, message_send)
        else
          logger.warn("Method #{message_send.message_send} not found\n")
        end
      else
        handle_custom_message_send(found_method, message_send)
        connect_method_result_to_node(found_method.id, message_send.send_result)
      end
    end

    def handle_custom_message_send(found_method, message_send)

      if message_send.send_args.last
        found_method_nodes = @graph.get_metod_nodes(found_method.id).args

        if found_method.args.kwargs.empty?
          regular_args = message_send.send_args
          connect_regular_args(found_method.args.args, found_method_nodes, regular_args)
        else
          @result[message_send.send_args.last].each_possible_type do |type|
            if type.name == "Hash"
              regular_args = message_send.send_args[0..-2]
              kwarg_arg = message_send.send_args.last

              connect_regular_args(found_method.args.args, found_method_nodes, regular_args)
              connect_keyword_args(found_method.args.kwargs, found_method_nodes, kwarg_arg)
            else
              regular_args = message_send.send_args
              connect_regular_args(found_method.args.args, found_method_nodes, regular_args)
            end
          end
        end
      end

      if !@graph.get_metod_nodes(found_method.id).yields.empty?
        @graph.get_metod_nodes(found_method.id).yields.each do |node_yield|
          block_lambda_nodes = @graph.get_lambda_nodes(message_send.block.lambda_id)
          arg_node = block_lambda_nodes.args.values[0]
          @graph.add_edge(node_yield, arg_node)
          @worklist.enqueue_node(arg_node)
        end
      end
    end

    def connect_regular_args(found_method_args, found_method_nodes, send_args)
      found_method_args.each_with_index do |formal_arg, i|
        next if formal_arg.name.nil?
        node_formal_arg = found_method_nodes[formal_arg.name]

        case formal_arg
        when GlobalTree::ArgumentsTree::Regular
          @graph.add_edge(send_args[i], node_formal_arg)
          @worklist.enqueue_node(node_formal_arg)
        when GlobalTree::ArgumentsTree::Optional
          if send_args[i]
            @graph.add_edge(send_args[i], node_formal_arg)
            @worklist.enqueue_node(node_formal_arg)
          end
        when GlobalTree::ArgumentsTree::Splat
          send_args[i..-1].each do |send_arg|
            @graph.add_edge(send_arg, node_formal_arg)
            @worklist.enqueue_node(node_formal_arg)
          end
        else raise
        end
      end
    end

    def connect_keyword_args(found_method_kwargs, found_method_nodes, kwarg_arg)
      unwrapping_node = Node.new(:unwrap_hash_values, {}, nil)
      @graph.add_vertex(unwrapping_node)
      @graph.add_edge(kwarg_arg, unwrapping_node)
      @worklist.enqueue_node(unwrapping_node)

      found_method_kwargs.each do |formal_kwarg|
        next if formal_kwarg.name.nil?
        node_formal_kwarg = found_method_nodes[formal_kwarg.name]

        case formal_kwarg
        when GlobalTree::ArgumentsTree::Regular
          @graph.add_edge(unwrapping_node, node_formal_kwarg)
          @worklist.enqueue_node(node_formal_kwarg)
        when GlobalTree::ArgumentsTree::Optional
          @graph.add_edge(unwrapping_node, node_formal_kwarg)
          @worklist.enqueue_node(node_formal_kwarg)
        when GlobalTree::ArgumentsTree::Splat
          @graph.add_edge(kwarg_arg, node_formal_kwarg)
          @worklist.enqueue_node(node_formal_kwarg)
        else raise
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

    def handle_super0_send(super_send)
      super_method = @tree.find_super_method(super_send.method_id)
      return if super_method.nil?
      connect_formal_args_to_formal_args(super_send.method_id, super_method.id)
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

      node = Node.new(:constructor, { name: type.name }, nil)
      @graph.add_vertex(node)
      @graph.add_edge(message_send.send_obj, node)
      @worklist.enqueue_node(node)
      @graph.add_edge(node, message_send.send_result)
      @worklist.enqueue_node(message_send.send_result)
    end

    def send_primitive_array_map(_class_name, message_send)
      raise if message_send.block.nil?

      unwrapping_node = Node.new(:unwrap_array, {}, nil)
      @graph.add_vertex(unwrapping_node)
      @graph.add_edge(message_send.send_obj, unwrapping_node)
      @worklist.enqueue_node(unwrapping_node)
      block_lambda_nodes = @graph.get_lambda_nodes(message_send.block.lambda_id)
      arg_node = block_lambda_nodes.args.values.first
      @graph.add_edge(unwrapping_node, arg_node)
      @worklist.enqueue_node(arg_node)

      wrapping_node = Node.new(:wrap_array, {}, nil)
      @graph.add_vertex(wrapping_node)
      @graph.add_edge(block_lambda_nodes.result, wrapping_node)
      @worklist.enqueue_node(wrapping_node)
      @graph.add_edge(wrapping_node, message_send.send_result)
      @worklist.enqueue_node(message_send.send_result)
    end

    def send_primitive_array_each(_class_name, message_send)
      raise if message_send.block.nil?

      unwrapping_node = Node.new(:unwrap_array, {}, nil)
      @graph.add_vertex(unwrapping_node)
      @graph.add_edge(message_send.send_obj, unwrapping_node)
      @worklist.enqueue_node(unwrapping_node)
      block_lambda_nodes = @graph.get_lambda_nodes(message_send.block.lambda_id)
      arg_node = block_lambda_nodes.args.values.first
      @graph.add_edge(unwrapping_node, arg_node)
      @worklist.enqueue_node(arg_node)

      @graph.add_edge(message_send.send_obj, message_send.send_result)
      @worklist.enqueue_node(message_send.send_result)
    end

    def send_primitive_object_freeze(_class_name, message_send)
      @graph.add_edge(message_send.send_obj, message_send.send_result)
      @worklist.enqueue_node(message_send.send_result)
    end

    def send_primitive_object_class(_class_name, message_send)
      extract_class_node = Node.new(:extract_class, {}, nil)
      @graph.add_vertex(extract_class_node)
      @graph.add_edge(message_send.send_obj, extract_class_node)
      @worklist.enqueue_node(extract_class_node)

      @graph.add_edge(extract_class_node, message_send.send_result)
      @worklist.enqueue_node(message_send.send_result)
    end

    def send_class_primitive_object_class(_class_name, message_send)
      extract_class_node = Node.new(:extract_class, {}, nil)
      @graph.add_vertex(extract_class_node)
      @graph.add_edge(message_send.send_obj, extract_class_node)
      @worklist.enqueue_node(extract_class_node)

      @graph.add_edge(extract_class_node, message_send.send_result)
      @worklist.enqueue_node(message_send.send_result)
    end

    def handle_constructor(node, sources)
      NominalType.new(node.params.fetch(:name))
    end

    def handle_definition_by_id(node, sources)
      definition_id = node.params.fetch(:id)
      const = @tree.find_constant_for_definition(definition_id)
      const ? ClassType.new(const.full_name) : nil
    end
  end
end
