module Orbacle
  class Builder
    BuilderError = Class.new(StandardError)
    class Result
      def initialize(node, context, data = {})
        @node = node
        @context = context.freeze
        @data = data.freeze
      end
      attr_reader :node, :context, :data
    end

    def initialize(graph, worklist, tree)
      @graph = graph
      @worklist = worklist
      @tree = tree
    end

    def process_file(file, filepath)
      ast = Parser::CurrentRuby.parse(file)
      initial_context = Context.new(filepath, Selfie.main, Nesting.empty, Context::AnalyzedKlass.new(nil, :public), nil, {})
      return process(ast, initial_context)
    end

    private

    def process(ast, context)
      return Result.new(nil, context) if ast.nil?

      process_result = case ast.type

        # primitives
      when :int
        handle_int(ast, context)
      when :float
        handle_float(ast, context)
      when :true
        handle_true(ast, context)
      when :false
        handle_false(ast, context)
      when :nil
        handle_nil(ast, context)
      when :str
        handle_str(ast, context)
      when :dstr
        handle_dstr(ast, context)
      when :xstr
        handle_xstr(ast, context)
      when :sym
        handle_sym(ast, context)
      when :dsym
        handle_dsym(ast, context)
      when :regexp
        handle_regexp(ast, context)

        # arrays
      when :array
        handle_array(ast, context)
      when :splat
        handle_splat(ast, context)

        # ranges
      when :irange
        handle_irange(ast, context)
      when :erange
        handle_erange(ast, context)

        # hashes
      when :hash
        handle_hash(ast, context)

        # local variables
      when :lvar
        handle_lvar(ast, context)
      when :lvasgn
        handle_lvasgn(ast, context)

        # global variables
      when :gvar
        handle_gvar(ast, context)
      when :gvasgn
        handle_gvasgn(ast, context)

        # instance variables
      when :ivar
        handle_ivar(ast, context)
      when :ivasgn
        handle_ivasgn(ast, context)

      when :self
        handle_self(ast, context)
      when :back_ref
        handle_ref(ast, context, :backref)
      when :nth_ref
        handle_ref(ast, context, :nthref)
      when :defined?
        handle_defined(ast, context)
      when :begin
        handle_begin(ast, context)
      when :kwbegin
        handle_begin(ast, context)
      when :cvar
        handle_cvar(ast, context)
      when :cvasgn
        handle_cvasgn(ast, context)
      when :send
        handle_send(ast, context, false)
      when :csend
        handle_send(ast, context, true)
      when :block
        handle_block(ast, context)
      when :def
        handle_def(ast, context)
      when :defs
        handle_defs(ast, context)
      when :class
        handle_class(ast, context)
      when :sclass
        handle_sclass(ast, context)
      when :module
        handle_module(ast, context)
      when :casgn
        handle_casgn(ast, context)
      when :const
        handle_const(ast, context)
      when :and
        handle_and(ast, context)
      when :or
        handle_or(ast, context)
      when :if
        handle_if(ast, context)
      when :return
        handle_return(ast, context)
      when :masgn
        handle_masgn(ast, context)
      when :alias
        handle_alias(ast, context)
      when :super
        handle_super(ast, context)
      when :zsuper
        handle_zsuper(ast, context)
      when :case
        handle_case(ast, context)
      when :yield
        handle_yield(ast, context)
      when :block_pass
        handle_block_pass(ast, context)

      when :while then handle_while(ast, context)
      when :until then handle_while(ast, context)
      when :while_post then handle_while(ast, context)
      when :until_post then handle_while(ast, context)
      when :break then handle_loop_operator(ast, context)
      when :next then handle_loop_operator(ast, context)
      when :redo then handle_loop_operator(ast, context)

      when :rescue then handle_rescue(ast, context)
      when :resbody then handle_resbody(ast, context)
      when :retry then handle_retry(ast, context)
      when :ensure then handle_ensure(ast, context)

      when :op_asgn then handle_op_asgn(ast, context)
      when :or_asgn then handle_or_asgn(ast, context)
      when :and_asgn then handle_and_asgn(ast, context)

      when :match_with_lvasgn then handle_match_with_lvasgn(ast, context)

      else raise ArgumentError.new(ast.type)
      end

      if process_result.node && !process_result.node.location
        process_result.node.location = build_location_from_ast(context, ast)
      end
      return process_result
    rescue BuilderError
      raise
    rescue => e
      puts "Error #{e} happened when parsing file #{context.filepath}"
      puts ast
      puts e.backtrace
      raise BuilderError
    end

    include OperatorAssignmentProcessors

    def handle_lvasgn(ast, context)
      var_name = ast.children[0].to_s
      expr = ast.children[1]

      node_lvasgn = add_vertex(Node.new(:lvasgn, { var_name: var_name }, build_location_from_ast(context, ast)))

      if expr
        expr_result = process(expr, context)
        @graph.add_edge(expr_result.node, node_lvasgn)
        final_context = expr_result.context.merge_lenv(var_name => [node_lvasgn])
      else
        final_context = context.merge_lenv(var_name => [node_lvasgn])
      end

      return Result.new(node_lvasgn, final_context)
    end

    def handle_int(ast, context)
      value = ast.children[0]
      n = add_vertex(Node.new(:int, { value: value }, build_location_from_ast(context, ast)))

      return Result.new(n, context)
    end

    def handle_float(ast, context)
      value = ast.children[0]
      n = add_vertex(Node.new(:float, { value: value }, build_location_from_ast(context, ast)))

      return Result.new(n, context)
    end

    def handle_true(ast, context)
      n = add_vertex(Node.new(:bool, { value: true }, build_location_from_ast(context, ast)))

      return Result.new(n, context)
    end

    def handle_false(ast, context)
      n = add_vertex(Node.new(:bool, { value: false }, build_location_from_ast(context, ast)))

      return Result.new(n, context)
    end

    def handle_nil(ast, context)
      n = add_vertex(Node.new(:nil, {}, build_location_from_ast(context, ast)))

      return Result.new(n, context)
    end

    def handle_str(ast, context)
      value = ast.children[0]
      n = add_vertex(Node.new(:str, { value: value }, build_location_from_ast(context, ast)))

      return Result.new(n, context)
    end

    def handle_dstr(ast, context)
      node_dstr = add_vertex(Node.new(:dstr, {}, build_location_from_ast(context, ast)))

      final_context, nodes = fold_context(ast.children, context)
      add_edges(nodes, node_dstr)

      return Result.new(node_dstr, final_context)
    end

    def handle_xstr(ast, context)
      node_xstr = add_vertex(Node.new(:xstr, {}, build_location_from_ast(context, ast)))

      final_context, nodes = fold_context(ast.children, context)
      add_edges(nodes, node_xstr)

      return Result.new(node_xstr, final_context)
    end

    def handle_sym(ast, context)
      value = ast.children[0]
      n = add_vertex(Node.new(:sym, { value: value }, build_location_from_ast(context, ast)))

      return Result.new(n, context)
    end

    def handle_dsym(ast, context)
      node_dsym = add_vertex(Node.new(:dsym, {}, build_location_from_ast(context, ast)))

      final_context, nodes = fold_context(ast.children, context)
      add_edges(nodes, node_dsym)

      return Result.new(node_dsym, final_context)
    end

    def handle_array(ast, context)
      node_array = add_vertex(Node.new(:array, {}, build_location_from_ast(context, ast)))

      final_context, nodes = fold_context(ast.children, context)
      add_edges(nodes, node_array)

      return Result.new(node_array, final_context)
    end

    def handle_splat(ast, context)
      expr = ast.children[0]

      expr_result = process(expr, context)

      node_splat = Node.new(:splat_array, {}, build_location_from_ast(context, ast))
      @graph.add_edge(expr_result.node, node_splat)

      return Result.new(node_splat, expr_result.context)
    end

    def handle_regexp(ast, context)
      expr_nodes = ast.children[0..-2]
      regopt = ast.children[-1]

      node_regexp = Node.new(:regexp, { regopt: regopt.children }, build_location_from_ast(context, ast))

      final_context, nodes = fold_context(expr_nodes, context)
      add_edges(nodes, node_regexp)

      return Result.new(node_regexp, final_context)
    end

    def handle_irange(ast, context)
      common_range(ast, context, true)
    end

    def handle_erange(ast, context)
      common_range(ast, context, false)
    end

    def common_range(ast, context, inclusive)
      range_from_ast = ast.children[0]
      range_to_ast = ast.children[1]

      range_node = Node.new(:range, { inclusive: inclusive }, build_location_from_ast(context, ast))

      range_from_ast_result = process(range_from_ast, context)
      from_node = Node.new(:range_from, {})
      @graph.add_edge(range_from_ast_result.node, from_node)
      @graph.add_edge(from_node, range_node)

      range_to_ast_result = process(range_to_ast, range_from_ast_result.context)
      to_node = Node.new(:range_to, {})
      @graph.add_edge(range_to_ast_result.node, to_node)
      @graph.add_edge(to_node, range_node)

      return Result.new(range_node, range_to_ast_result.context)
    end

    def handle_ref(ast, context, node_type)
      ref = if node_type == :backref
        ast.children[0].to_s[1..-1]
      elsif node_type == :nthref
        ast.children[0].to_s
      else
        raise
      end
      node = add_vertex(Node.new(node_type, { ref: ref }, build_location_from_ast(context, ast)))
      return Result.new(node, context)
    end

    def handle_defined(ast, context)
      _expr = ast.children[0]

      node = add_vertex(Node.new(:defined, {}, build_location_from_ast(context, ast)))

      return Result.new(node, context)
    end

    def handle_begin(ast, context)
      final_context, nodes = fold_context(ast.children, context)
      if ast.children.empty?
        return Result.new(add_vertex(Node.new(:nil, {}, ast)), context)
      else
        return Result.new(nodes.last, final_context)
      end
    end

    def handle_lvar(ast, context)
      var_name = ast.children[0].to_s

      node_lvar = add_vertex(Node.new(:lvar, { var_name: var_name }, build_location_from_ast(context, ast)))

      context.lenv_fetch(var_name).each do |var_definition_node|
        @graph.add_edge(var_definition_node, node_lvar)
      end

      return Result.new(node_lvar, context)
    end

    def handle_ivar(ast, context)
      ivar_name = ast.children.first.to_s

      ivar_definition_node = if context.selfie.klass?
        @graph.get_class_level_ivar_definition_node(context.scope, ivar_name)
      elsif context.selfie.instance?
        @graph.get_ivar_definition_node(context.scope, ivar_name)
      elsif context.selfie.main?
        @graph.get_main_ivar_definition_node(ivar_name)
      else
        raise
      end

      node = Node.new(:ivar, { var_name: ivar_name }, build_location_from_ast(context, ast))
      @graph.add_edge(ivar_definition_node, node)

      return Result.new(node, context)
    end

    def handle_ivasgn(ast, context)
      ivar_name = ast.children[0].to_s
      expr = ast.children[1]

      node_ivasgn = add_vertex(Node.new(:ivasgn, { var_name: ivar_name }, build_location_from_ast(context, ast)))

      if expr
        expr_result = process(expr, context)
        @graph.add_edge(expr_result.node, node_ivasgn)
        context_after_expr = expr_result.context
      else
        context_after_expr = context
      end

      ivar_definition_node = if context.selfie.klass?
        @graph.get_class_level_ivar_definition_node(context.scope, ivar_name)
      elsif context.selfie.instance?
        @graph.get_ivar_definition_node(context_after_expr.scope, ivar_name)
      elsif context.selfie.main?
        @graph.get_main_ivar_definition_node(ivar_name)
      else
        raise
      end
      @graph.add_edge(node_ivasgn, ivar_definition_node)

      return Result.new(node_ivasgn, context_after_expr)
    end

    def handle_cvasgn(ast, context)
      cvar_name = ast.children[0].to_s
      expr = ast.children[1]

      node_cvasgn = add_vertex(Node.new(:cvasgn, { var_name: cvar_name }, build_location_from_ast(context, ast)))

      if expr
        expr_result = process(expr, context)
        @graph.add_edge(expr_result.node, node_cvasgn)
        context_after_expr = expr_result.context
      else
        context_after_expr = context
      end

      node_cvar_definition = @graph.get_cvar_definition_node(context.scope, cvar_name)
      @graph.add_edge(node_cvasgn, node_cvar_definition)

      return Result.new(node_cvasgn, context_after_expr)
    end

    def handle_cvar(ast, context)
      cvar_name = ast.children.first.to_s

      cvar_definition_node = @graph.get_cvar_definition_node(context.scope, cvar_name)

      node = Node.new(:cvar, { var_name: cvar_name }, build_location_from_ast(context, ast))
      @graph.add_edge(cvar_definition_node, node)

      return Result.new(node, context)
    end

    def handle_gvasgn(ast, context)
      gvar_name = ast.children[0].to_s
      expr = ast.children[1]

      node_gvasgn = add_vertex(Node.new(:gvasgn, { var_name: gvar_name }, build_location_from_ast(context, ast)))

      expr_result = process(expr, context)
      @graph.add_edge(expr_result.node, node_gvasgn)

      node_gvar_definition = @graph.get_gvar_definition_node(gvar_name)
      @graph.add_edge(node_gvasgn, node_gvar_definition)

      return Result.new(node_gvasgn, expr_result.context)
    end

    def handle_gvar(ast, context)
      gvar_name = ast.children.first.to_s

      gvar_definition_node = @graph.get_gvar_definition_node(gvar_name)

      node = add_vertex(Node.new(:gvar, { var_name: gvar_name }, build_location_from_ast(context, ast)))
      @graph.add_edge(gvar_definition_node, node)

      return Result.new(node, context)
    end

    def handle_send(ast, context, csend)
      obj_expr = ast.children[0]
      message_name = ast.children[1].to_s
      arg_exprs = ast.children[2..-1]

      if obj_expr.nil?
        obj_node = add_vertex(Node.new(:self, { selfie: context.selfie }))
        obj_context = context
      else
        expr_result = process(obj_expr, context)
        obj_node = expr_result.node
        obj_context = expr_result.context
      end

      final_context, call_arg_nodes, block_node = prepare_argument_nodes(obj_context, arg_exprs)

      return handle_changing_visibility(context, message_name.to_sym, arg_exprs) if obj_expr.nil? && ["public", "protected", "private"].include?(message_name)
      return handle_custom_attr_reader_send(context, arg_exprs, ast) if obj_expr.nil? && message_name == "attr_reader"
      return handle_custom_attr_writer_send(context, arg_exprs, ast) if obj_expr.nil? && message_name == "attr_writer"
      return handle_custom_attr_accessor_send(context, arg_exprs, ast) if obj_expr.nil? && message_name == "attr_accessor"

      call_obj_node = add_vertex(Node.new(:call_obj, {}))
      @graph.add_edge(obj_node, call_obj_node)

      call_result_node = add_vertex(Node.new(:call_result, { csend: csend }))

      message_send = Worklist::MessageSend.new(message_name, call_obj_node, call_arg_nodes, call_result_node, block_node)
      @worklist.add_message_send(message_send)

      return Result.new(call_result_node, final_context, { message_send: message_send })
    end

    def prepare_argument_nodes(context, arg_exprs)
      call_arg_nodes = []
      block_node = nil
      final_context = arg_exprs.reduce(context) do |current_context, ast_child|
        case ast_child.type
        when :block_pass
          block_pass_result = process(ast_child.children[0], current_context)
          block_node = Worklist::BlockNode.new(block_pass_result.node)
          block_pass_result.context
        when :splat
          ast_child_result = process(ast_child.children[0], current_context)
          call_arg_node = add_vertex(Node.new(:call_splatarg, {}))
          call_arg_nodes << call_arg_node
          @graph.add_edge(ast_child_result.node, call_arg_node)
          ast_child_result.context
        else
          ast_child_result = process(ast_child, current_context)
          call_arg_node = add_vertex(Node.new(:call_arg, {}))
          call_arg_nodes << call_arg_node
          @graph.add_edge(ast_child_result.node, call_arg_node)
          ast_child_result.context
        end
      end
      return final_context, call_arg_nodes, block_node
    end

    def handle_changing_visibility(context, new_visibility, arg_exprs)
      if context.analyzed_klass_id && arg_exprs.empty?
        final_node = add_vertex(Node.new(:definition_by_id, { id: context.analyzed_klass_id }))
        return Result.new(final_node, context.with_visibility(new_visibility))
      elsif context.analyzed_klass_id
        methods_to_change_visibility = arg_exprs.map do |arg_expr|
          [:sym, :str].include?(arg_expr.type) ? arg_expr.children[0].to_s : nil
        end.compact
        methods_to_change_visibility.each do |name|
          @tree.change_metod_visibility(context.analyzed_klass_id, name, new_visibility)
        end

        final_node = add_vertex(Node.new(:definition_by_id, { id: context.analyzed_klass_id }))
        return Result.new(final_node, context)
      else
        final_node = add_vertex(Node.new(:const, { const_ref: ConstRef.from_full_name("Object", Nesting.empty) }))
        return Result.new(final_node, context)
      end
    end

    def handle_custom_attr_reader_send(context, arg_exprs, ast)
      location = build_location_from_ast(context, ast)
      ivar_names = arg_exprs.select {|s| [:sym, :str].include?(s.type) }.map {|s| s.children.first }.map(&:to_s)
      ivar_names.each do |ivar_name|
        define_attr_reader_method(context, ivar_name, location)
      end

      return Result.new(Node.new(:nil, {}), context)
    end

    def handle_custom_attr_writer_send(context, arg_exprs, ast)
      location = build_location_from_ast(context, ast)
      ivar_names = arg_exprs.select {|s| [:sym, :str].include?(s.type) }.map {|s| s.children.first }.map(&:to_s)
      ivar_names.each do |ivar_name|
        define_attr_writer_method(context, ivar_name, location)
      end

      return Result.new(Node.new(:nil, {}), context)
    end

    def handle_custom_attr_accessor_send(context, arg_exprs, ast)
      location = build_location_from_ast(context, ast)
      ivar_names = arg_exprs.select {|s| [:sym, :str].include?(s.type) }.map {|s| s.children.first }.map(&:to_s)
      ivar_names.each do |ivar_name|
        define_attr_reader_method(context, ivar_name, location)
        define_attr_writer_method(context, ivar_name, location)
      end

      return Result.new(Node.new(:nil, {}), context)
    end

    def define_attr_reader_method(context, ivar_name, location)
      ivar_definition_node = @graph.get_ivar_definition_node(context.scope, "@#{ivar_name}")

      metod = @tree.add_method(
        GlobalTree::Method.new(
          place_of_definition_id: context.analyzed_klass_id,
          name: ivar_name,
          location: location,
          args: GlobalTree::ArgumentsTree.new([], [], nil),
          visibility: context.analyzed_klass.method_visibility))
      @graph.store_metod_nodes(metod.id, [])
      @graph.add_edge(ivar_definition_node, @graph.get_metod_nodes(metod.id).result)
    end

    def define_attr_writer_method(context, ivar_name, location)
      ivar_definition_node = @graph.get_ivar_definition_node(context.scope, "@#{ivar_name}")

      arg_name = "_attr_writer"
      arg_node = add_vertex(Node.new(:formal_arg, { var_name: arg_name }))
      metod = @tree.add_method(
        GlobalTree::Method.new(
          place_of_definition_id: context.analyzed_klass_id,
          name: "#{ivar_name}=",
          location: location,
          args: GlobalTree::ArgumentsTree.new([GlobalTree::ArgumentsTree::Regular.new(arg_name)], [], nil),
          visibility: context.analyzed_klass.method_visibility))
      @graph.store_metod_nodes(metod.id, { arg_name => arg_node })
      @graph.add_edge(arg_node, ivar_definition_node)
      @graph.add_edge(ivar_definition_node, @graph.get_metod_nodes(metod.id).result)
    end

    def handle_self(ast, context)
      node = add_vertex(Node.new(:self, { selfie: context.selfie }, build_location_from_ast(context, ast)))
      return Result.new(node, context)
    end

    def handle_block(ast, context)
      send_expr = ast.children[0]
      args_ast = ast.children[1]
      block_expr = ast.children[2]

      if send_expr == Parser::AST::Node.new(:send, [nil, :lambda])
        send_context = context
      else
        send_expr_result = process(send_expr, context)
        message_send = send_expr_result.data[:message_send]
        if message_send
          send_node = send_expr_result.node
          send_context = send_expr_result.context
        else
          return Result.new(Node.new(:nil, {}), context)
        end
      end

      arguments_tree, context_with_args, args_ast_nodes = build_def_arguments(args_ast.children, send_context)

      # It's not exactly good - local vars defined in blocks are not available outside (?),
      #     but assignments done in blocks are valid.
      if block_expr
        block_expr_result = process(block_expr, context_with_args)
        block_final_node = block_expr_result.node
        block_result_context = block_expr_result.context
      else
        block_final_node = Node.new(:nil, {})
        block_result_context = context_with_args
      end
      block_result_node = add_vertex(Node.new(:block_result, {}))
      @graph.add_edge(block_final_node, block_result_node)


      lamba = @tree.add_lambda(arguments_tree)
      @graph.store_lambda_nodes(lamba.id, args_ast_nodes, block_result_node)

      if lambda_ast?(send_expr)
        lambda_node = add_vertex(Node.new(:lambda, { id: lamba.id }))
        return Result.new(lambda_node, block_result_context)
      else
        message_send.block = Worklist::BlockLambda.new(lamba.id)
        return Result.new(send_node, block_result_context)
      end
    end

    def handle_def(ast, context)
      method_name = ast.children[0]
      formal_arguments = ast.children[1]
      method_body = ast.children[2]

      arguments_tree, arguments_context, arguments_nodes = build_def_arguments(formal_arguments.children, context)

      metod = @tree.add_method(
        GlobalTree::Method.new(
          place_of_definition_id: context.analyzed_klass_id,
          name: method_name.to_s,
          location: build_location_from_ast(context, ast),
          args: arguments_tree,
          visibility: context.analyzed_klass.method_visibility))
      @graph.store_metod_nodes(metod.id, arguments_nodes)

      context.with_analyzed_method(metod.id).tap do |context2|
        if method_body
          context2.with_selfie(Selfie.instance_from_scope(context2.scope)).tap do |context3|
            final_node = process(method_body, context3.merge_lenv(arguments_context.lenv)).node
            @graph.add_edge(final_node, @graph.get_metod_nodes(context3.analyzed_method).result)
          end
        else
          final_node = add_vertex(Node.new(:nil, {}))
          @graph.add_edge(final_node, @graph.get_metod_nodes(context2.analyzed_method).result)
        end
      end

      node = add_vertex(Node.new(:sym, { value: method_name }, build_location_from_ast(context, ast)))

      return Result.new(node, context)
    end

    def handle_hash(ast, context)
      node_hash_keys = add_vertex(Node.new(:hash_keys, {}))
      node_hash_values = add_vertex(Node.new(:hash_values, {}))
      node_hash = add_vertex(Node.new(:hash, {}))
      @graph.add_edge(node_hash_keys, node_hash)
      @graph.add_edge(node_hash_values, node_hash)

      final_context = ast.children.reduce(context) do |current_context, ast_child|
        case ast_child.type
        when :pair
          hash_key, hash_value = ast_child.children
          hash_key_result = process(hash_key, current_context)
          hash_value_result = process(hash_value, hash_key_result.context)
          @graph.add_edge(hash_key_result.node, node_hash_keys)
          @graph.add_edge(hash_value_result.node, node_hash_values)
          hash_value_result.context
        when :kwsplat
          kwsplat_expr = ast_child.children[0]

          kwsplat_expr_result = process(kwsplat_expr, context)

          node_unwrap_hash_keys = Node.new(:unwrap_hash_keys, {})
          node_unwrap_hash_values = Node.new(:unwrap_hash_values, {})

          @graph.add_edge(kwsplat_expr_result.node, node_unwrap_hash_keys)
          @graph.add_edge(kwsplat_expr_result.node, node_unwrap_hash_values)

          @graph.add_edge(node_unwrap_hash_keys, node_hash_keys)
          @graph.add_edge(node_unwrap_hash_values, node_hash_values)

          kwsplat_expr_result.context
        else raise ArgumentError.new(ast)
        end
      end

      return Result.new(node_hash, final_context)
    end

    def handle_class(ast, context)
      klass_name_ast, parent_klass_name_ast, klass_body = ast.children
      klass_name_ref = ConstRef.from_ast(klass_name_ast, context.nesting)
      parent_name_ref = if parent_klass_name_ast.nil? || !simple_constant?(parent_klass_name_ast)
        nil
      elsif simple_constant?(parent_klass_name_ast)
        ConstRef.from_ast(parent_klass_name_ast, context.nesting)
      end

      klass = @tree.add_klass(GlobalTree::Klass.new(parent_ref: parent_name_ref))
      klass_constant = @tree.add_constant(
        GlobalTree::Constant.new(klass_name_ref.name, context.scope.increase_by_ref(klass_name_ref).decrease, build_location_from_ast(context, ast), klass.id))

      new_context = context
        .with_analyzed_klass(klass.id)
        .with_nesting(context.nesting.increase_nesting_const(klass_name_ref))
        .with_selfie(Selfie.klass_from_scope(context.scope))
      if klass_body
        process(klass_body, new_context)
      end

      node = add_vertex(Node.new(:nil, {}))

      return Result.new(node, context)
    end

    def handle_module(ast, context)
      module_name_ast = ast.children[0]
      module_body = ast.children[1]

      module_name_ref = ConstRef.from_ast(module_name_ast, context.nesting)

      mod = @tree.add_mod(GlobalTree::Mod.new)
      @tree.add_constant(
        GlobalTree::Constant.new(
          module_name_ref.name, context.scope.increase_by_ref(module_name_ref).decrease, build_location_from_ast(context, ast), mod.id))

      if module_body
        context
          .with_analyzed_klass(mod.id)
          .with_nesting(context.nesting.increase_nesting_const(module_name_ref)).tap do |context2|
            process(module_body, context2)
          end
      end

      return Result.new(Node.new(:nil, {}), context)
    end

    def handle_sclass(ast, context)
      self_name = ast.children[0]
      sklass_body = ast.children[1]

      eigenclass_of_analyzed_definition = @tree.get_eigenclass_of_definition(context.analyzed_klass_id)
      context
        .with_nesting(context.nesting.increase_nesting_self)
        .with_analyzed_klass(eigenclass_of_analyzed_definition.id).tap do |context2|
          process(sklass_body, context2)
        end

      return Result.new(Node.new(:nil, {}), context)
    end

    def handle_defs(ast, context)
      method_receiver = ast.children[0]
      method_name = ast.children[1]
      formal_arguments = ast.children[2]
      method_body = ast.children[3]

      arguments_tree, arguments_context, arguments_nodes = build_def_arguments(formal_arguments.children, context)

      if context.analyzed_klass_id
        eigenclass_of_analyzed_definition = @tree.get_eigenclass_of_definition(context.analyzed_klass_id)
        place_of_definition_id = eigenclass_of_analyzed_definition.id
      else
        place_of_definition_id = nil
      end
      metod = @tree.add_method(
        GlobalTree::Method.new(
          place_of_definition_id: place_of_definition_id,
          name: method_name.to_s,
          location: build_location_from_ast(context, ast),
          args: arguments_tree,
          visibility: context.analyzed_klass.method_visibility))
      @graph.store_metod_nodes(metod.id, arguments_nodes)

      context.with_analyzed_method(metod.id).tap do |context2|
        if method_body
          context2.with_selfie(Selfie.klass_from_scope(context2.scope)).tap do |context3|
            final_node = process(method_body, context3.merge_lenv(arguments_context.lenv)).node
            @graph.add_edge(final_node, @graph.get_metod_nodes(context3.analyzed_method).result)
          end
        else
          final_node = add_vertex(Node.new(:nil, {}))
          @graph.add_edge(final_node, @graph.get_metod_nodes(context2.analyzed_method).result)
        end
      end

      node = add_vertex(Node.new(:sym, { value: method_name }))

      return Result.new(node, context)
    end

    def handle_casgn(ast, context)
      const_prename, const_name, expr = ast.children
      const_name_ref = ConstRef.from_full_name(AstUtils.const_prename_and_name_to_string(const_prename, const_name), context.nesting)

      if expr_is_class_definition?(expr)
        parent_klass_name_ast = expr.children[2]
        parent_name_ref = parent_klass_name_ast.nil? ? nil : ConstRef.from_ast(parent_klass_name_ast, context.nesting)
        klass = @tree.add_klass(GlobalTree::Klass.new(parent_ref: parent_name_ref))
        @tree.add_constant(
          GlobalTree::Constant.new(
            const_name_ref.name, context.scope.increase_by_ref(const_name_ref).decrease, build_location_from_ast(context, ast), klass.id))

        return Result.new(Node.new(:nil, {}), context)
      elsif expr_is_module_definition?(expr)
        mod = @tree.add_mod(GlobalTree::Mod.new)
        @tree.add_constant(
          GlobalTree::Constant.new(
            const_name_ref.name, context.scope.increase_by_ref(const_name_ref).decrease, build_location_from_ast(context, ast), mod.id))

        return Result.new(Node.new(:nil, {}), context)
      else
        @tree.add_constant(
          GlobalTree::Constant.new(
            const_name_ref.name, context.scope.increase_by_ref(const_name_ref).decrease, build_location_from_ast(context, ast)))

        expr_result = process(expr, context)

        final_node = Node.new(:casgn, { const_ref: const_name_ref })
        @graph.add_edge(expr_result.node, final_node)

        const_name = context.scope.increase_by_ref(const_name_ref).to_const_name
        node_const_definition = @graph.get_constant_definition_node(const_name.to_string)
        @graph.add_edge(final_node, node_const_definition)

        return Result.new(final_node, expr_result.context)
      end
    end

    def handle_const(ast, context)
      if simple_constant?(ast)
        const_ref = ConstRef.from_ast(ast, context.nesting)

        node = add_vertex(Node.new(:const, { const_ref: const_ref }))

        return Result.new(node, context)
      else
        node = add_vertex(Node.new(:dynamic_const, {}))

        return Result.new(node, context)
      end
    end

    def handle_and(ast, context)
      handle_binary_operator(:and, ast.children[0], ast.children[1], context)
    end

    def handle_or(ast, context)
      handle_binary_operator(:or, ast.children[0], ast.children[1], context)
    end

    def handle_binary_operator(node_type, expr_left, expr_right, context)
      expr_left_result = process(expr_left, context)
      expr_right_result = process(expr_right, expr_left_result.context)

      node_or = add_vertex(Node.new(node_type, {}))
      @graph.add_edge(expr_left_result.node, node_or)
      @graph.add_edge(expr_right_result.node, node_or)

      return Result.new(node_or, expr_right_result.context)
    end

    def handle_if(ast, context)
      expr_cond = ast.children[0]
      expr_iftrue = ast.children[1]
      expr_iffalse = ast.children[2]

      expr_cond_result = process(expr_cond, context)

      if expr_iftrue
        expr_iftrue_result = process(expr_iftrue, expr_cond_result.context)

        node_iftrue = expr_iftrue_result.node
        context_after_iftrue = expr_iftrue_result.context
      else
        node_iftrue = add_vertex(Node.new(:nil, {}))
        context_after_iftrue = context
      end

      if expr_iffalse
        expr_iffalse_result = process(expr_iffalse, expr_cond_result.context)

        node_iffalse = expr_iffalse_result.node
        context_after_iffalse = expr_iffalse_result.context
      else
        node_iffalse = add_vertex(Node.new(:nil, {}))
        context_after_iffalse = context
      end

      node_if_result = add_vertex(Node.new(:if_result, {}))
      @graph.add_edge(node_iftrue, node_if_result)
      @graph.add_edge(node_iffalse, node_if_result)

      return Result.new(node_if_result, merge_contexts(context_after_iftrue, context_after_iffalse))
    end

    def handle_return(ast, context)
      exprs = ast.children

      if exprs.size == 0
        node_expr = add_vertex(Node.new(:nil, {}))
        final_context = context
      elsif exprs.size == 1
        expr_result = process(exprs[0], context)
        node_expr = expr_result.node
        final_context = expr_result.context
      else
        node_expr = add_vertex(Node.new(:array, {}))
        final_context, nodes = fold_context(ast.children, context)
        add_edges(nodes, node_expr)
      end

      if context.analyzed_method
        @graph.add_edge(node_expr, @graph.get_metod_nodes(context.analyzed_method).result)
      end

      return Result.new(node_expr, final_context)
    end

    def handle_masgn(ast, context)
      mlhs_expr = ast.children[0]
      rhs_expr = ast.children[1]

      rhs_expr_result = process(rhs_expr, context)
      node_rhs = rhs_expr_result.node
      context_after_rhs = rhs_expr_result.context

      mlhs_result = handle_mlhs_for_masgn(mlhs_expr, context, rhs_expr)

      return mlhs_result
    end

    def handle_mlhs_for_masgn(ast, context, rhs_expr)
      result_node = add_vertex(Node.new(:array, {}))

      i = 0
      final_context = ast.children.reduce(context) do |current_context, ast_child|
        if ast_child.type == :mlhs
          new_rhs_expr = Parser::AST::Node.new(:send, [rhs_expr, :[], Parser::AST::Node.new(:int, [i])])
          ast_child_result = handle_mlhs_for_masgn(ast_child, current_context, new_rhs_expr)
          node_child = ast_child_result.node
          context_after_child = ast_child_result.context
        else
          new_ast_child = ast_child.append(Parser::AST::Node.new(:send, [rhs_expr, :[], Parser::AST::Node.new(:int, [i])]))
          new_ast_child_result = process(new_ast_child, current_context)
          node_child = new_ast_child_result.node
          context_after_child = new_ast_child_result.context
        end

        @graph.add_edge(node_child, result_node)
        i += 1
        context_after_child
      end

      return Result.new(result_node, final_context)
    end

    def handle_alias(ast, context)
      node = add_vertex(Node.new(:nil, {}))
      return Result.new(node, context)
    end

    def handle_super(ast, context)
      arg_exprs = ast.children

      final_context, call_arg_nodes, block_node = prepare_argument_nodes(context, arg_exprs)

      call_result_node = add_vertex(Node.new(:call_result, {}))

      super_send = Worklist::SuperSend.new(call_arg_nodes, call_result_node, block_node, final_context.analyzed_method)
      @worklist.add_message_send(super_send)

      return Result.new(call_result_node, final_context, { message_send: super_send })
    end

    def handle_zsuper(ast, context)
      call_result_node = add_vertex(Node.new(:call_result, {}))

      zsuper_send = Worklist::Super0Send.new(call_result_node, nil, context.analyzed_method)
      @worklist.add_message_send(zsuper_send)

      return Result.new(call_result_node, context, { message_send: zsuper_send })
    end

    def handle_while(ast, context)
      expr_cond = ast.children[0]
      expr_body = ast.children[1]

      new_context = process(expr_cond, context).context
      final_context = process(expr_body, new_context).context

      node = add_vertex(Node.new(:nil, {}))

      return Result.new(node, final_context)
    end

    def handle_case(ast, context)
      expr_cond = ast.children[0]
      expr_branches = ast.children[1..-1].compact

      new_context = process(expr_cond, context).context

      node_case_result = add_vertex(Node.new(:case_result, {}))
      final_context = expr_branches.reduce(new_context) do |current_context, expr_when|
        if expr_when.type == :when
          expr_cond, expr_body = expr_when.children
          context_after_cond = process(expr_cond, current_context).context

          if expr_body.nil?
            @graph.add_edge(Node.new(:nil, {}), node_case_result)
            context_after_cond
          else
            expr_body_result = process(expr_body, context_after_cond)
            @graph.add_edge(expr_body_result.node, node_case_result)
            expr_body_result.context
          end
        else
          expr_body_result = process(expr_when, current_context)
          @graph.add_edge(expr_body_result.node, node_case_result)
          expr_body_result.context
        end
      end

      return Result.new(node_case_result, final_context)
    end

    def handle_yield(ast, context)
      exprs = ast.children

      node_yield = add_vertex(Node.new(:yield, {}))
      final_context = if exprs.empty?
        @graph.add_edge(Node.new(:nil, {}), node_yield)
        context
      else
        exprs.reduce(context) do |current_context, current_expr|
          current_expr_result = process(current_expr, current_context)
          @graph.add_edge(current_expr_result.node, node_yield)
          current_expr_result.context
        end
      end
      result_node = add_vertex(Node.new(:yield_result, {}))
      if context.analyzed_method
        method_nodes = @graph.get_metod_nodes(context.analyzed_method)
        method_nodes.yields << node_yield
        method_nodes.yield_results << result_node
      end

      return Result.new(result_node, final_context)
    end

    def handle_loop_operator(ast, context)
      return Result.new(Node.new(:loop_operator, {}), context)
    end

    def handle_resbody(ast, context)
      error_array_expr = ast.children[0]
      assignment_expr = ast.children[1]
      rescue_body_expr = ast.children[2]

      context_after_errors = if error_array_expr
        error_array_expr_result = process(error_array_expr, context)
        unwrap_node = add_vertex(Node.new(:unwrap_error_array, {}))
        @graph.add_edge(error_array_expr_result.node, unwrap_node)
        error_array_expr_result.context
      else
        context
      end

      context_after_assignment = if assignment_expr
        assignment_expr_result = process(assignment_expr, context_after_errors)
        @graph.add_edge(unwrap_node, assignment_expr_result.node) if unwrap_node
        assignment_expr_result.context
      else
        context
      end

      if rescue_body_expr
        rescue_body_expr_result = process(rescue_body_expr, context_after_assignment)
        node_rescue_body = rescue_body_expr_result.node
        final_context = rescue_body_expr_result.context
      else
        node_rescue_body = add_vertex(Node.new(:nil, {}))
        final_context = context
      end

      return Result.new(node_rescue_body, final_context)
    end

    def handle_rescue(ast, context)
      try_expr = ast.children[0]
      resbody = ast.children[1]
      elsebody = ast.children[2]

      if try_expr
        try_expr_result = process(try_expr, context)
        node_try = try_expr_result.node
        context_after_try = try_expr_result.context
      else
        node_try = add_vertex(Node.new(:nil, {}))
        context_after_try = context
      end

      resbody_result = process(resbody, context_after_try)
      node_resbody = resbody_result.node
      context_after_resbody = resbody_result.context

      node = add_vertex(Node.new(:rescue, {}))
      @graph.add_edge(node_resbody, node)

      if elsebody
        elsebody_result = process(elsebody, context_after_try)
        node_else = elsebody_result.node
        context_after_else = elsebody_result.context
        @graph.add_edge(node_else, node)
        return Result.new(node, merge_contexts(context_after_resbody, context_after_else))
      else
        @graph.add_edge(node_try, node)
        return Result.new(node, context_after_resbody)
      end
    end

    def handle_retry(ast, context)
      return Result.new(add_vertex(Node.new(:retry, {})), context)
    end

    def handle_ensure(ast, context)
      expr_pre = ast.children[0]
      expr_ensure_body = ast.children[1]

      node_ensure = add_vertex(Node.new(:ensure, {}))

      expr_pre_result = process(expr_pre, context)
      @graph.add_edge(expr_pre_result.node, node_ensure) if expr_pre_result.node

      expr_ensure_body_result = process(expr_ensure_body, expr_pre_result.context)

      return Result.new(node_ensure, expr_ensure_body_result.context)
    end

    def expr_is_class_definition?(expr)
      expr.type == :send &&
        expr.children[0] == Parser::AST::Node.new(:const, [nil, :Class]) &&
        expr.children[1] == :new
    end

    def expr_is_module_definition?(expr)
      expr.type == :send &&
        expr.children[0] == Parser::AST::Node.new(:const, [nil, :Module]) &&
        expr.children[1] == :new
    end

    def build_def_arguments(formal_arguments, context)
      args = []
      kwargs = []
      blockarg = nil

      nodes = {}

      final_context = formal_arguments.reduce(context) do |current_context, arg_ast|
        arg_name = arg_ast.children[0]&.to_s
        maybe_arg_default_expr = arg_ast.children[1]
        location = build_location_from_ast(current_context, arg_ast)

        case arg_ast.type
        when :arg
          args << GlobalTree::ArgumentsTree::Regular.new(arg_name)
          nodes[arg_name] = add_vertex(Node.new(:formal_arg, { var_name: arg_name }, location))
          current_context.merge_lenv(arg_name => [nodes[arg_name]])
        when :optarg
          args << GlobalTree::ArgumentsTree::Optional.new(arg_name)
          maybe_arg_default_expr_result = process(maybe_arg_default_expr, current_context)
          nodes[arg_name] = add_vertex(Node.new(:formal_optarg, { var_name: arg_name }, location))
          @graph.add_edge(maybe_arg_default_expr_result.node, nodes[arg_name])
          maybe_arg_default_expr_result.context.merge_lenv(arg_name => [nodes[arg_name]])
        when :restarg
          args << GlobalTree::ArgumentsTree::Splat.new(arg_name)
          nodes[arg_name] = add_vertex(Node.new(:formal_restarg, { var_name: arg_name }, location))
          current_context.merge_lenv(arg_name => [nodes[arg_name]])
        when :kwarg
          kwargs << GlobalTree::ArgumentsTree::Regular.new(arg_name)
          nodes[arg_name] = add_vertex(Node.new(:formal_kwarg, { var_name: arg_name }, location))
          current_context.merge_lenv(arg_name => [nodes[arg_name]])
        when :kwoptarg
          kwargs << GlobalTree::ArgumentsTree::Optional.new(arg_name)
          maybe_arg_default_expr_result = process(maybe_arg_default_expr, current_context)
          nodes[arg_name] = add_vertex(Node.new(:formal_kwoptarg, { var_name: arg_name }, location))
          @graph.add_edge(maybe_arg_default_expr_result.node, nodes[arg_name])
          maybe_arg_default_expr_result.context.merge_lenv(arg_name => [nodes[arg_name]])
        when :kwrestarg
          kwargs << GlobalTree::ArgumentsTree::Splat.new(arg_name)
          nodes[arg_name] = add_vertex(Node.new(:formal_kwrestarg, { var_name: arg_name }, location))
          current_context.merge_lenv(arg_name => [nodes[arg_name]])
        when :mlhs
          nested_arg, next_context = build_def_arguments_nested(arg_ast.children, nodes, current_context)
          args << nested_arg
          next_context
        when :blockarg
          blockarg = arg_name
          nodes[arg_name] = add_vertex(Node.new(:formal_blockarg, { var_name: arg_name }, location))
          current_context.merge_lenv(arg_name => [nodes[arg_name]])
        else raise
        end
      end

      return GlobalTree::ArgumentsTree.new(args, kwargs, blockarg), final_context, nodes
    end

    def build_def_arguments_nested(arg_asts, nodes, context)
      args = []

      final_context = arg_asts.reduce(context) do |current_context, arg_ast|
        arg_name = arg_ast.children[0]&.to_s

        case arg_ast.type
        when :arg
          args << GlobalTree::ArgumentsTree::Regular.new(arg_name)
          nodes[arg_name] = add_vertex(Node.new(:formal_arg, { var_name: arg_name }))
          current_context.merge_lenv(arg_name => [nodes[arg_name]])
        when :restarg
          args << GlobalTree::ArgumentsTree::Splat.new(arg_name)
          nodes[arg_name] = add_vertex(Node.new(:formal_restarg, { var_name: arg_name }))
          current_context.merge_lenv(arg_name => [nodes[arg_name]])
        when :mlhs
          nested_arg, next_context = build_def_arguments_nested(arg_ast.children, nodes, current_context)
          args << nested_arg
          next_context
        else raise
        end
      end

      return GlobalTree::ArgumentsTree::Nested.new(args), final_context
    end

    def handle_match_with_lvasgn(ast, context)
      return Result.new(add_vertex(Node.new(:str, {})), context)
    end

    def merge_contexts(context1, context2)
      raise if !context1.almost_equal?(context2)
      final_lenv = {}

      var_names = (context1.lenv.keys + context2.lenv.keys).uniq
      var_names.each do |var_name|
        final_lenv[var_name] = (context1.lenv.fetch(var_name, []) + context2.lenv.fetch(var_name, [])).uniq
      end

      context1.with_lenv(final_lenv)
    end

    def fold_context(exprs, context)
      nodes = []
      final_context = exprs.reduce(context) do |current_context, ast_child|
        child_result = process(ast_child, current_context)
        nodes << child_result.node
        child_result.context
      end
      return final_context, nodes
    end

    def build_location_from_ast(context, ast)
      if ast.loc
        Location.new(
          context.filepath,
          PositionRange.new(
            Position.new(ast.loc.expression.begin.line - 1, ast.loc.expression.begin.column),
            Position.new(ast.loc.expression.end.line - 1, ast.loc.expression.end.column - 1)),
          ast.loc.expression.length)
      end
    end

    def add_vertex(v)
      @graph.add_vertex(v)
    end

    def add_edges(xs, ys)
      @graph.add_edges(xs, ys)
    end

    def simple_constant?(c)
      c.type == :const &&
        (c.children[0].nil? ||
         c.children[0].type == :cbase ||
         c.children[0].type == :const)
    end

    def lambda_ast?(send_expr)
      send_expr == Parser::AST::Node.new(:send, [nil, :lambda])
    end
  end
end
