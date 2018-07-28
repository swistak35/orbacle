# frozen_string_literal: true

module Orbacle
  class TypingService
    TypingError = Class.new(StandardError)
    class UnknownNodeKindError < TypingError
      def initialize(node)
        @node = node
      end
      attr_reader :node
    end

    def initialize(logger, stats)
      @logger = logger
      @stats = stats
    end

    def call(graph, worklist, state)
      @worklist = worklist
      @graph = graph
      @state = state

      stats.set_value(:initial_nodes, @graph.vertices.size)
      stats.set_value(:initial_message_sends, @worklist.message_sends.size)

      @graph.vertices.to_a.each {|v| @worklist.enqueue_node(v) }
      while !@worklist.nodes.empty?
        while !@worklist.nodes.empty?
          while !@worklist.nodes.empty?
            node = @worklist.pop_node
            @worklist.count_node(node)
            if !@worklist.limit_exceeded?(node)
              current_result = @state.type_of(node)
              new_result = compute_result(node, @graph.parent_vertices(node))
              raise ArgumentError.new(node) if new_result.nil?
              @state.set_type_of(node, new_result)
              stats.inc(:processed_nodes)
              logger.debug("Processed nodes: #{stats.counter(:processed_nodes)} remaining nodes #{@worklist.nodes.size} msends #{@worklist.handled_message_sends.size} / #{@worklist.message_sends.size}") if stats.counter(:processed_nodes) % 1000 == 0

              if current_result != @state.type_of(node)
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
          else raise "Not handled message send"
          end
        end
      end
    end

    private
    attr_reader :logger, :stats

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
      when :formal_kwrestarg then handle_group(node, sources)
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

      when :for then handle_pass1(node, sources)

      # not really tested
      when :dynamic_const then handle_bottom(node, sources)
      when :unwrap_hash_values then handle_unwrap_hash_values(node, sources)
      when :unwrap_hash_keys then handle_unwrap_hash_keys(node, sources)
      when :const_definition then handle_group(node, sources)
      when :constructor then handle_constructor(node, sources)
      when :method_result then handle_group(node, sources)
      when :extract_class then handle_extract_class(node, sources)
      when :lambda then handle_lambda(node, sources)
      when :definition_by_id then handle_definition_by_id(node, sources)
      when :yield_result then handle_group(node, sources)

      else raise UnknownNodeKindError.new(node)
      end
    rescue UnknownNodeKindError => e
      logger.error("Unknown node kind '#{e.node.type}' at #{e.node.location}")
      raise
    rescue => e
      logger.error("Typing failed with error '#{e.inspect}' at node #{node.type} at #{node.location}")
      raise
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

    def handle_lambda(node, sources)
      ProcType.new(node.params.fetch(:id))
    end

    def handle_unwrap_hash_keys(node, sources)
      raise if sources.size != 1
      source = sources.first
      if @state.type_of(source).is_a?(GenericType)
        @state.type_of(source).parameters.at(0)
      else
        BottomType.new
      end
    end

    def handle_unwrap_hash_values(node, sources)
      raise if sources.size != 1
      source = sources.first
      if @state.type_of(source).is_a?(GenericType)
        @state.type_of(source).parameters.at(1)
      else
        BottomType.new
      end
    end

    def handle_group(node, sources)
      sources_types = sources.map {|source_node| @state.type_of(source_node) }
      build_union(sources_types)
    end

    def handle_pass1(node, sources)
      raise if sources.size != 1
      source = sources.first
      @state.type_of(source)
    end

    def handle_hash(_node, sources)
      hash_keys_node = sources.find {|s| s.type == :hash_keys }
      hash_values_node = sources.find {|s| s.type == :hash_values }
      GenericType.new("Hash", [@state.type_of(hash_keys_node), @state.type_of(hash_values_node)])
    end

    def handle_range(node, sources)
      sources_types = sources.map {|source_node| @state.type_of(source_node) }
      GenericType.new("Range", [build_union(sources_types)])
    end

    def handle_self(node, sources)
      selfie = node.params.fetch(:selfie)
      if selfie.klass?
        if selfie.scope.empty?
          BottomType.new
        else
          ClassType.new(selfie.scope.absolute_str)
        end
      elsif selfie.instance?
        if selfie.scope.empty?
          BottomType.new
        else
          type_from_class_name(selfie.scope.absolute_str)
        end
      elsif selfie.main?
        MainType.new
      else
        raise
      end
    end

    def type_from_class_name(name)
      if ["Array", "Hash", "Range"].include?(name)
        GenericType.new(name, [])
      else
        NominalType.new(name)
      end
    end

    def handle_unwrap_array(node, sources)
      types_inside_arrays = []
      sources
        .each do |s|
          @state.type_of(s).each_possible_type do |t|
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
      GenericType.new("Array", [build_union(sources.map {|s| @state.type_of(s) })])
    end

    def handle_pass_lte1(_node, sources)
      raise if sources.size > 1
      @state.type_of(sources.first)
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
      ref_result = @state.solve_reference(const_ref)
      if ref_result && @graph.constants[ref_result.full_name]
        const_definition_node = @graph.constants[ref_result.full_name]
        @graph.add_edge(const_definition_node, node)
        @worklist.enqueue_node(const_definition_node)
        @state.type_of(const_definition_node)
      elsif ref_result
        ClassType.new(ref_result.full_name)
      else
        ClassType.new(const_ref.relative_name)
      end
    end

    def handle_extract_class(node, sources)
      res = sources.map do |source|
        extract_class(@state.type_of(sources.first))
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
      defined_type?(@state.type_of(message_send.send_obj)) &&
        message_send.send_args.all? {|a| defined_type?(@state.type_of(a)) }
    end

    def satisfied_super_send?(super_send)
      super_send.send_args.all? {|a| defined_type?(@state.type_of(a)) }
    end

    def handle_message_send(message_send)
      @state.type_of(message_send.send_obj).each_possible_type do |possible_type|
        if constructor_send?(possible_type, message_send.message_send)
          handle_constructor_send(possible_type.name, message_send)
        elsif possible_type.instance_of?(ProcType) && message_send.message_send == :call
          handle_proc_call(possible_type, message_send)
        elsif possible_type.is_a?(ClassType)
          handle_class_send(possible_type.name, message_send)
        else
          handle_instance_send(possible_type.name, message_send)
        end
      end
    end

    def handle_proc_call(lambda_type, message_send)
      found_lambda = @state.get_lambda(lambda_type.lambda_id)
      found_lambda_nodes = @graph.get_lambda_nodes(found_lambda.id)
      connect_actual_args_to_formal_args(found_lambda.args, found_lambda_nodes.args, message_send.send_args)
      @graph.add_edge(found_lambda_nodes.result, message_send.send_result)
      @worklist.enqueue_node(message_send.send_result)
    end

    def handle_constructor_send(class_name, message_send)
      found_method = @state.find_deep_instance_method_from_class_name(class_name, :initialize)
      if found_method.nil?
        connect_constructor_to_node(class_name, message_send.send_result)
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
      found_method = @state.find_instance_method_from_class_name(class_name, message_send.message_send)
      if found_method.nil?
        parent_name = @state.get_parent_of(class_name)
        if parent_name
          handle_instance_send(parent_name, message_send)
        else
          # logger.debug("Method #{message_send.message_send} not found in #{class_name} (location: #{message_send.location})\n")
        end
      else
        handle_custom_message_send(found_method, message_send)
        connect_method_result_to_node(found_method.id, message_send.send_result)
      end
    end

    def handle_class_nonprimitive_send(class_name, message_send)
      found_method = @state.find_class_method_from_class_name(class_name, message_send.message_send)
      if found_method.nil?
        parent_name = @state.get_parent_of(class_name)
        if parent_name
          handle_class_send(parent_name, message_send)
        else
          # logger.debug("Method #{message_send.message_send} not found in #{class_name} (location: #{message_send.location})\n")
        end
      else
        handle_custom_message_send(found_method, message_send)
        connect_method_result_to_node(found_method.id, message_send.send_result)
      end
    end

    def connect_actual_args_to_formal_args(found_method_argtree, found_method_nodes, send_args)
      if send_args.last
        if found_method_argtree.kwargs.empty?
          regular_args = send_args
          connect_regular_args(found_method_argtree.args, found_method_nodes, regular_args)
        else
          @state.type_of(send_args.last).each_possible_type do |type|
            if type.name == "Hash"
              regular_args = send_args[0..-2]
              kwarg_arg = send_args.last

              connect_regular_args(found_method_argtree.args, found_method_nodes, regular_args)
              connect_keyword_args(found_method_argtree.kwargs, found_method_nodes, kwarg_arg)
            else
              regular_args = send_args
              connect_regular_args(found_method_argtree.args, found_method_nodes, regular_args)
            end
          end
        end
      end
    end

    def handle_custom_message_send(found_method, message_send)
      found_method_nodes = @graph.get_metod_nodes(found_method.id)
      connect_actual_args_to_formal_args(found_method.args, found_method_nodes.args, message_send.send_args)

      found_method_nodes.zsupers.each do |zsuper_call|
        super_method = @state.find_super_method(found_method.id)
        next if super_method.nil?

        super_method_nodes = @graph.get_metod_nodes(super_method.id)
        connect_actual_args_to_formal_args(super_method.args, super_method_nodes.args, message_send.send_args)
        if zsuper_call.block.nil?
          connect_yields_to_block_lambda(@graph.get_metod_nodes(super_method.id).yields, message_send.block)
        else
          connect_yields_to_block_lambda(@graph.get_metod_nodes(super_method.id).yields, zsuper_call.block)
        end
        connect_method_result_to_node(super_method.id, zsuper_call.send_result)
      end

      connect_yields_to_block_lambda(@graph.get_metod_nodes(found_method.id).yields, message_send.block)
    end

    def lambda_ids_of_block(block)
      case block
      when Worklist::BlockLambda
        [block.lambda_id]
      when Worklist::BlockNode
        @state.type_of(block.node).enum_for(:each_possible_type).map do |possible_type|
          if possible_type.instance_of?(ProcType)
            possible_type.lambda_id
          end
        end.compact
      when NilClass
        []
      else raise
      end
    end

    def connect_yields_to_block_lambda(yields_nodes, block_node)
      yields_nodes.each do |yield_nodes|
        lambda_ids = lambda_ids_of_block(block_node)
        lambda_ids.each do |lambda_id|
          block_lambda = @state.get_lambda(lambda_id)
          block_lambda_nodes = @graph.get_lambda_nodes(lambda_id)
          connect_actual_args_to_formal_args(block_lambda.args, block_lambda_nodes.args, yield_nodes.send_args)

          @graph.add_edge(block_lambda_nodes.result, yield_nodes.send_result)
          @worklist.enqueue_node(yield_nodes.send_result)
        end
      end
    end

    def generate_possible_args(splatsize, send_args)
      if send_args.empty?
        [[]]
      else
        head, *rest = send_args
        tails = generate_possible_args(splatsize, rest)
        if head.type == :call_arg
          tails.map {|tail| [head, *tail] }
        elsif head.type == :call_splatarg
          unwrap_node = Node.new(:unwrap_array, {})
          @graph.add_edge(head, unwrap_node)
          @worklist.enqueue_node(unwrap_node)
          (splatsize + 1).times.flat_map do |splat_array_possible_size|
            unwraps = [unwrap_node] * splat_array_possible_size
            tails.map do |tail|
              [*unwraps, *tail]
            end
          end
        else raise
        end
      end
    end

    def connect_regular_args(found_method_args, found_method_nodes, basic_send_args)
      possible_send_args = generate_possible_args(found_method_args.size, basic_send_args)
      possible_send_args.each do |send_args|
        found_method_args.each_with_index do |formal_arg, i|
          next if formal_arg.name.nil?
          node_formal_arg = found_method_nodes[formal_arg.name]

          next if send_args[i].nil?
          case formal_arg
          when GlobalTree::ArgumentsTree::Regular
            @graph.add_edge(send_args[i], node_formal_arg)
            @worklist.enqueue_node(node_formal_arg)
          when GlobalTree::ArgumentsTree::Optional
            @graph.add_edge(send_args[i], node_formal_arg)
            @worklist.enqueue_node(node_formal_arg)
          when GlobalTree::ArgumentsTree::Splat
            send_args[i..-1].each do |send_arg|
              @graph.add_edge(send_arg, node_formal_arg)
              @worklist.enqueue_node(node_formal_arg)
            end
          else raise
          end
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
      return if super_send.method_id.nil?
      super_method = @state.find_super_method(super_send.method_id)
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
          :map => method(:send_primitive_array_map),
          :each => method(:send_primitive_array_each),
        },
        "Object" => {
          :class => method(:send_primitive_object_class),
          :clone => method(:send_primitive_object_freeze),
          :dup => method(:send_primitive_object_freeze),
          :freeze => method(:send_primitive_object_freeze),
          :itself => method(:send_primitive_object_freeze),
          :taint => method(:send_primitive_object_freeze),
          :trust => method(:send_primitive_object_freeze),
          :untaint => method(:send_primitive_object_freeze),
          :untrust => method(:send_primitive_object_freeze),
        },
      }
    end

    def primitive_class_mapping
      {
        "Object" => {
          :class => method(:send_class_primitive_object_class),
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
      type.is_a?(ClassType) && message_name == :new
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
      unwrapping_node = Node.new(:unwrap_array, {}, nil)
      @graph.add_vertex(unwrapping_node)
      @graph.add_edge(message_send.send_obj, unwrapping_node)
      @worklist.enqueue_node(unwrapping_node)

      wrapping_node = Node.new(:wrap_array, {}, nil)
      @graph.add_vertex(wrapping_node)
      @graph.add_edge(wrapping_node, message_send.send_result)
      @worklist.enqueue_node(message_send.send_result)

      lambda_ids_of_block(message_send.block).each do |lambda_id|
        block_lambda_nodes = @graph.get_lambda_nodes(lambda_id)
        if !block_lambda_nodes.args.values.empty?
          arg_node = block_lambda_nodes.args.values.first
          @graph.add_edge(unwrapping_node, arg_node)
          @worklist.enqueue_node(arg_node)
        end

        @graph.add_edge(block_lambda_nodes.result, wrapping_node)
        @worklist.enqueue_node(wrapping_node)
      end
    end

    def send_primitive_array_each(_class_name, message_send)
      return unless Worklist::BlockLambda === message_send.block

      unwrapping_node = Node.new(:unwrap_array, {}, nil)
      @graph.add_vertex(unwrapping_node)
      @graph.add_edge(message_send.send_obj, unwrapping_node)
      @worklist.enqueue_node(unwrapping_node)
      block_lambda_nodes = @graph.get_lambda_nodes(message_send.block.lambda_id)
      if !block_lambda_nodes.args.values.empty?
        arg_node = block_lambda_nodes.args.values.first
        @graph.add_edge(unwrapping_node, arg_node)
        @worklist.enqueue_node(arg_node)
      end

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
      name = node.params.fetch(:name)
      type_from_class_name(name)
    end

    def handle_definition_by_id(node, sources)
      definition_id = node.params.fetch(:id)
      const = @state.find_constant_for_definition(definition_id)
      const ? ClassType.new(const.full_name) : BottomType.new
    end
  end
end
