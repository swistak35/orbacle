require 'parser/current'
require 'orbacle/nesting'

module Orbacle
  module DataFlowGraph
    class Builder
      class Result
        def initialize(node, context, data = {})
          @node = node
          @context = context
          @data = data
        end
        attr_reader :node, :context, :data
      end

      class Context
        AnalyzedKlass = Struct.new(:klass, :method_visibility)

        def initialize(filepath, selfie, nesting, analyzed_klass, analyzed_method, lenv)
          @filepath = filepath.freeze
          @selfie = selfie.freeze
          @nesting = nesting.freeze
          @analyzed_klass = analyzed_klass
          @analyzed_method = analyzed_method
          @lenv = lenv.freeze
        end

        attr_reader :filepath, :selfie, :nesting, :analyzed_klass, :analyzed_method, :lenv

        def with_selfie(new_selfie)
          self.class.new(filepath, new_selfie, nesting, analyzed_klass, analyzed_method, lenv)
        end

        def with_nesting(new_nesting)
          self.class.new(filepath, selfie, new_nesting, analyzed_klass, analyzed_method, lenv)
        end

        def scope
          nesting.to_scope
        end

        def with_analyzed_klass(new_klass)
          self.class.new(filepath, selfie, nesting, AnalyzedKlass.new(new_klass, :public), analyzed_method, lenv)
        end

        def with_analyzed_method(new_analyzed_method)
          self.class.new(filepath, selfie, nesting, analyzed_klass, new_analyzed_method, lenv)
        end

        def merge_lenv(new_lenv)
          self.class.new(filepath, selfie, nesting, analyzed_klass, analyzed_method, lenv.merge(new_lenv))
        end

        def lenv_fetch(key)
          lenv.fetch(key)
        end

        def with_lenv(new_lenv)
          self.class.new(filepath, selfie, nesting, analyzed_klass, analyzed_method, new_lenv)
        end

        def almost_equal?(other)
          filepath == other.filepath &&
            selfie == other.selfie &&
            nesting == other.nesting &&
            analyzed_klass == other.analyzed_klass &&
            analyzed_method == other.analyzed_method
        end
      end

      def initialize(graph, worklist, tree)
        @graph = graph
        @worklist = worklist
        @tree = tree
      end

      def process_file(file, filepath)
        ast = Parser::CurrentRuby.parse(file)
        context = Context.new(filepath, Selfie.main, Nesting.empty, Context::AnalyzedKlass.new(nil, :public), nil, {})

        final_node, final_context, _data = process(ast, context)

        return Result.new(final_node, final_context)
      end

      private

      def process(ast, context)
        return [nil, context] if ast.nil?

        process_result = case ast.type
        when :lvasgn
          handle_lvasgn(ast, context)
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
        when :self
          handle_self(ast, context)
        when :array
          handle_array(ast, context)
        when :splat
          handle_splat(ast, context)
        when :str
          handle_str(ast, context)
        when :dstr
          handle_dstr(ast, context)
        when :sym
          handle_sym(ast, context)
        when :dsym
          handle_dsym(ast, context)
        when :regexp
          handle_regexp(ast, context)
        when :hash
          handle_hash(ast, context)
        when :irange
          handle_irange(ast, context)
        when :erange
          handle_erange(ast, context)
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
        when :lvar
          handle_lvar(ast, context)
        when :ivar
          handle_ivar(ast, context)
        when :ivasgn
          handle_ivasgn(ast, context)
        when :cvar
          handle_cvar(ast, context)
        when :cvasgn
          handle_cvasgn(ast, context)
        when :gvar
          handle_gvar(ast, context)
        when :gvasgn
          handle_gvasgn(ast, context)
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
        when :when
          handle_when(ast, context)
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
        when :break then handle_break(ast, context)
        when :next then handle_break(ast, context)
        when :redo then handle_break(ast, context)

        when :rescue then handle_rescue(ast, context)
        when :resbody then handle_resbody(ast, context)
        when :retry then handle_retry(ast, context)
        when :ensure then handle_ensure(ast, context)

        when :op_asgn then handle_op_asgn(ast, context)
        when :or_asgn then handle_or_asgn(ast, context)
        when :and_asgn then handle_and_asgn(ast, context)

        else
          raise ArgumentError.new(ast.type)
        end

        if process_result[0] && ast.loc && !process_result[0].location
          process_result[0].location = build_location_from_ast(context, ast)
        end
        process_result
      end

      def handle_lvasgn(ast, context)
        var_name = ast.children[0].to_s
        expr = ast.children[1]

        node_lvasgn = add_vertex(Node.new(:lvasgn, { var_name: var_name }))

        if expr
          node_expr, context_after_expr = process(expr, context)
          @graph.add_edge(node_expr, node_lvasgn)
          final_context = context_after_expr.merge_lenv(var_name => [node_lvasgn])
        else
          final_context = context.merge_lenv(var_name => [node_lvasgn])
        end

        return [node_lvasgn, final_context]
      end

      def handle_int(ast, context)
        value = ast.children[0]
        n = add_vertex(Node.new(:int, { value: value }))

        return [n, context]
      end

      def handle_float(ast, context)
        value = ast.children[0]
        n = add_vertex(Node.new(:float, { value: value }))

        return [n, context]
      end

      def handle_true(ast, context)
        n = add_vertex(Node.new(:bool, { value: true }))

        return [n, context]
      end

      def handle_false(ast, context)
        n = add_vertex(Node.new(:bool, { value: false }))

        return [n, context]
      end

      def handle_nil(ast, context)
        n = add_vertex(Node.new(:nil))

        return [n, context]
      end

      def handle_str(ast, context)
        value = ast.children[0]
        n = add_vertex(Node.new(:str, { value: value }))

        return [n, context]
      end

      def handle_dstr(ast, context)
        node_dstr = add_vertex(Node.new(:dstr))

        final_context, nodes = fold_context(ast.children, context)
        add_edges(nodes, node_dstr)

        return [node_dstr, final_context]
      end

      def handle_sym(ast, context)
        value = ast.children[0]
        n = add_vertex(Node.new(:sym, { value: value }))

        return [n, context]
      end

      def handle_dsym(ast, context)
        node_dsym = add_vertex(Node.new(:dsym))

        final_context, nodes = fold_context(ast.children, context)
        add_edges(nodes, node_dsym)

        return [node_dsym, final_context]
      end

      def handle_array(ast, context)
        node_array = add_vertex(Node.new(:array))

        final_context, nodes = fold_context(ast.children, context)
        add_edges(nodes, node_array)

        return [node_array, final_context]
      end

      def handle_splat(ast, context)
        expr = ast.children[0]

        node_expr, context_after_expr = process(expr, context)

        node_splat = Node.new(:splat_array)
        @graph.add_edge(node_expr, node_splat)

        return [node_splat, context_after_expr]
      end

      def handle_regexp(ast, context)
        expr_nodes = ast.children[0..-2]
        regopt = ast.children[-1]

        node_regexp = Node.new(:regexp, { regopt: regopt.children })

        final_context, nodes = fold_context(expr_nodes, context)
        add_edges(nodes, node_regexp)

        return [node_regexp, final_context]
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

        range_node = Node.new(:range, { inclusive: inclusive })

        range_from_node, context2 = process(range_from_ast, context)
        from_node = Node.new(:range_from)
        @graph.add_edge(range_from_node, from_node)
        @graph.add_edge(from_node, range_node)

        range_to_node, final_context = process(range_to_ast, context2)
        to_node = Node.new(:range_to)
        @graph.add_edge(range_to_node, to_node)
        @graph.add_edge(to_node, range_node)

        return [range_node, final_context]
      end

      def handle_ref(ast, context, node_type)
        ref = ast.children[0].to_s
        node = add_vertex(Node.new(node_type, { ref: ref }))
        return [node, context]
      end

      def handle_defined(ast, context)
        _expr = ast.children[0]

        node = add_vertex(Node.new(:defined))

        return [node, context]
      end

      def handle_begin(ast, context)
        final_context, nodes = fold_context(ast.children, context)
        return [nodes.last, final_context]
      end

      def handle_lvar(ast, context)
        var_name = ast.children[0].to_s

        node_lvar = add_vertex(Node.new(:lvar, { var_name: var_name }))

        context.lenv_fetch(var_name).each do |var_definition_node|
          @graph.add_edge(var_definition_node, node_lvar)
        end

        return [node_lvar, context]
      end

      def handle_ivar(ast, context)
        ivar_name = ast.children.first.to_s

        ivar_definition_node = if context.selfie.klass?
          get_class_level_ivar_definition_node(context, ivar_name)
        elsif context.selfie.instance?
          get_ivar_definition_node(context, ivar_name)
        else
          raise
        end

        node = Node.new(:ivar)
        @graph.add_edge(ivar_definition_node, node)

        return [node, context]
      end

      def handle_ivasgn(ast, context)
        ivar_name = ast.children[0].to_s
        expr = ast.children[1]

        node_ivasgn = add_vertex(Node.new(:ivasgn, { var_name: ivar_name }))

        if expr
          node_expr, context_after_expr = process(expr, context)
          @graph.add_edge(node_expr, node_ivasgn)
        else
          context_after_expr = context
        end

        ivar_definition_node = if context.selfie.klass?
          get_class_level_ivar_definition_node(context, ivar_name)
        elsif context.selfie.instance?
          get_ivar_definition_node(context_after_expr, ivar_name)
        else
          raise
        end
        @graph.add_edge(node_ivasgn, ivar_definition_node)

        return [node_ivasgn, context_after_expr]
      end

      def handle_cvasgn(ast, context)
        cvar_name = ast.children[0].to_s
        expr = ast.children[1]

        node_cvasgn = add_vertex(Node.new(:cvasgn, { var_name: cvar_name }))

        if expr
          node_expr, context_after_expr = process(expr, context)
          @graph.add_edge(node_expr, node_cvasgn)
        else
          context_after_expr = context
        end

        node_cvar_definition = get_cvar_definition_node(context, cvar_name)
        @graph.add_edge(node_cvasgn, node_cvar_definition)

        return [node_cvasgn, context_after_expr]
      end

      def handle_cvar(ast, context)
        cvar_name = ast.children.first.to_s

        cvar_definition_node = get_cvar_definition_node(context, cvar_name)

        node = Node.new(:cvar)
        @graph.add_edge(cvar_definition_node, node)

        return [node, context]
      end

      def handle_gvasgn(ast, context)
        gvar_name = ast.children[0].to_s
        expr = ast.children[1]

        node_gvasgn = add_vertex(Node.new(:gvasgn, { var_name: gvar_name }))

        node_expr, context_after_expr = process(expr, context)
        @graph.add_edge(node_expr, node_gvasgn)

        node_gvar_definition = @graph.get_gvar_definition_node(gvar_name)
        @graph.add_edge(node_gvasgn, node_gvar_definition)

        return [node_gvasgn, context_after_expr]
      end

      def handle_gvar(ast, context)
        gvar_name = ast.children.first.to_s

        gvar_definition_node = @graph.get_gvar_definition_node(gvar_name)

        node = add_vertex(Node.new(:gvar))
        @graph.add_edge(gvar_definition_node, node)

        return [node, context]
      end

      def handle_send(ast, context, csend)
        obj_expr = ast.children[0]
        message_name = ast.children[1].to_s
        arg_exprs = ast.children[2..-1]

        if obj_expr.nil?
          obj_node = add_vertex(Node.new(:self, { selfie: context.selfie }))
          obj_context = context
        else
          obj_node, obj_context = process(obj_expr, context)
        end

        call_arg_nodes = []
        final_context = arg_exprs.reduce(obj_context) do |current_context, ast_child|
          ast_child_node, new_context = process(ast_child, current_context)
          call_arg_node = add_vertex(Node.new(:call_arg))
          call_arg_nodes << call_arg_node
          @graph.add_edge(ast_child_node, call_arg_node)
          new_context
        end

        return handle_changing_visibility(context, message_name.to_sym, arg_exprs) if obj_expr.nil? && ["public", "protected", "private"].include?(message_name)
        return handle_custom_attr_reader_send(context, arg_exprs, ast) if obj_expr.nil? && message_name == "attr_reader"
        return handle_custom_attr_writer_send(context, arg_exprs, ast) if obj_expr.nil? && message_name == "attr_writer"
        return handle_custom_attr_accessor_send(context, arg_exprs, ast) if obj_expr.nil? && message_name == "attr_accessor"
        return handle_custom_class_send(context, obj_node) if message_name == "class"
        return handle_custom_freeze_send(context, obj_node) if message_name == "freeze"

        call_obj_node = add_vertex(Node.new(:call_obj))
        @graph.add_edge(obj_node, call_obj_node)

        call_result_node = add_vertex(Node.new(:call_result, { csend: csend }))

        message_send = Worklist::MessageSend.new(message_name, call_obj_node, call_arg_nodes, call_result_node, nil)
        @worklist.add_message_send(message_send)

        return [call_result_node, final_context, { message_send: message_send }]
      end

      def handle_custom_class_send(context, obj_node)
        extract_class_node = @graph.add_vertex(Node.new(:extract_class))
        @graph.add_edge(obj_node, extract_class_node)

        return [extract_class_node, context]
      end

      def handle_custom_freeze_send(context, obj_node)
        freeze_node = @graph.add_vertex(Node.new(:freeze))
        @graph.add_edge(obj_node, freeze_node)

        return [freeze_node, context]
      end

      def handle_changing_visibility(context, new_visibility, arg_exprs)
        node = if context.analyzed_klass.klass
          if arg_exprs.empty?
            context.analyzed_klass.method_visibility = new_visibility
          else
            methods_to_change_visibility = arg_exprs.map do |arg_expr|
              [:sym, :str].include?(arg_expr.type) ? arg_expr.children[0].to_s : nil
            end.compact
            @tree.metods.each do |m|
              if m.scope == context.scope && methods_to_change_visibility.include?(m.name)
                m.visibility = new_visibility
              end
            end
          end

          Node.new(:class, { klass: context.analyzed_klass.klass })
        else
          # This should actually be reference to Object class
          Node.new(:nil)
        end
        add_vertex(node)

        return [node, context]
      end

      def handle_custom_attr_reader_send(context, arg_exprs, ast)
        location = build_location_from_ast(context, ast)
        ivar_names = arg_exprs.select {|s| [:sym, :str].include?(s.type) }.map {|s| s.children.first }.map(&:to_s)
        ivar_names.each do |ivar_name|
          define_attr_reader_method(context, ivar_name, location)
        end

        return [Node.new(:nil), context]
      end

      def handle_custom_attr_writer_send(context, arg_exprs, ast)
        location = build_location_from_ast(context, ast)
        ivar_names = arg_exprs.select {|s| [:sym, :str].include?(s.type) }.map {|s| s.children.first }.map(&:to_s)
        ivar_names.each do |ivar_name|
          define_attr_writer_method(context, ivar_name, location)
        end

        return [Node.new(:nil), context]
      end

      def handle_custom_attr_accessor_send(context, arg_exprs, ast)
        location = build_location_from_ast(context, ast)
        ivar_names = arg_exprs.select {|s| [:sym, :str].include?(s.type) }.map {|s| s.children.first }.map(&:to_s)
        ivar_names.each do |ivar_name|
          define_attr_reader_method(context, ivar_name, location)
          define_attr_writer_method(context, ivar_name, location)
        end

        return [Node.new(:nil), context]
      end

      def define_attr_reader_method(context, ivar_name, location)
        ivar_definition_node = get_ivar_definition_node(context, "@#{ivar_name}")

        metod = @tree.add_method(
          GlobalTree::Method.new(
            scope: context.scope,
            name: ivar_name,
            location: location,
            args: GlobalTree::Method::ArgumentsTree.new([], [], nil),
            visibility: context.analyzed_klass.method_visibility,
            nodes: GlobalTree::Method::Nodes.new([], add_vertex(Node.new(:method_result)), [])))
        @graph.add_edge(ivar_definition_node, metod.nodes.result)
      end

      def define_attr_writer_method(context, ivar_name, location)
        ivar_definition_node = get_ivar_definition_node(context, "@#{ivar_name}")

        arg_name = "_attr_writer"
        arg_node = add_vertex(Node.new(:formal_arg, { var_name: arg_name }))
        metod = @tree.add_method(
          GlobalTree::Method.new(
            scope: context.scope,
            name: "#{ivar_name}=",
            location: location,
            args: GlobalTree::Method::ArgumentsTree.new([GlobalTree::Method::ArgumentsTree::Regular.new(arg_name)], [], nil),
            visibility: context.analyzed_klass.method_visibility,
            nodes: GlobalTree::Method::Nodes.new({arg_name => arg_node}, add_vertex(Node.new(:method_result)), [])))
        @graph.add_edge(arg_node, ivar_definition_node)
        @graph.add_edge(ivar_definition_node, metod.nodes.result)
      end

      def handle_self(ast, context)
        node = add_vertex(Node.new(:self, { selfie: context.selfie }))
        return [node, context]
      end

      def handle_block(ast, context)
        send_expr = ast.children[0]
        args_ast = ast.children[1]
        block_expr = ast.children[2]

        if send_expr == Parser::AST::Node.new(:send, [nil, :lambda])
          send_context = context
        else
          send_node, send_context, _additional = process(send_expr, context)
          message_send = _additional.fetch(:message_send)
        end

        args_ast_nodes = []
        context_with_args = args_ast.children.reduce(send_context) do |current_context, arg_ast|
          arg_node = add_vertex(Node.new(:block_arg))
          args_ast_nodes << arg_node
          case arg_ast.type
          when :arg
            arg_name = arg_ast.children[0].to_s
            current_context.merge_lenv(arg_name => [arg_node])
          when :mlhs
            handle_mlhs_for_block(arg_ast, current_context, arg_node)
          else raise RuntimeError.new(ast)
          end
        end

        # It's not exactly good - local vars defined in blocks are not available outside (?),
        #     but assignments done in blocks are valid.
        block_final_node, block_result_context = process(block_expr, context_with_args)
        block_result_node = add_vertex(Node.new(:block_result))
        @graph.add_edge(block_final_node, block_result_node)

        if send_expr == Parser::AST::Node.new(:send, [nil, :lambda])
          lamb = @tree.add_lambda(GlobalTree::Lambda::Nodes.new(args_ast_nodes, block_result_node))
          lambda_node = add_vertex(Node.new(:lambda, { id: lamb.id }))
          return [lambda_node, block_result_context]
        else
          block = Block.new(args_ast_nodes, block_result_node)
          message_send.block = block
          return [send_node, block_result_context]
        end
      end

      def handle_mlhs_for_block(ast, context, node)
        unwrap_array_node = Node.new(:unwrap_array)
        @graph.add_edge(node, unwrap_array_node)

        final_context = ast.children.reduce(context) do |current_context, ast_child|
          case ast_child.type
          when :arg
            arg_name = ast_child.children[0].to_s
            current_context.merge_lenv(arg_name => [unwrap_array_node])
          when :mlhs
            handle_mlhs_for_block(ast_child, current_context, unwrap_array_node)
          else raise
          end
        end

        return final_context
      end

      def handle_lambda(ast, context)
        send_expr = ast.children[0]
        args_ast = ast.children[1]
        block_expr = ast.children[2]
      end

      def handle_def(ast, context)
        method_name = ast.children[0]
        formal_arguments = ast.children[1]
        method_body = ast.children[2]

        arguments_tree, arguments_context, arguments_nodes = build_def_arguments(formal_arguments.children, context)

        metod = @tree.add_method(
          GlobalTree::Method.new(
            scope: context.scope,
            name: method_name.to_s,
            location: build_location(context, Position.new(ast.loc.line, nil), Position.new(ast.loc.line, nil)),
            args: arguments_tree,
            visibility: context.analyzed_klass.method_visibility,
            nodes: GlobalTree::Method::Nodes.new(arguments_nodes, add_vertex(Node.new(:method_result)), [])))

        context2 = context.with_analyzed_method(metod)
        if method_body
          context3 = context2.with_selfie(Selfie.instance_from_scope(context2.scope))
          final_node, _result_context = process(method_body, context3.merge_lenv(arguments_context.lenv))
          @graph.add_edge(final_node, context3.analyzed_method.nodes.result)
        else
          final_node = add_vertex(Node.new(:nil))
          @graph.add_edge(final_node, context2.analyzed_method.nodes.result)
        end

        node = add_vertex(Node.new(:sym, { value: method_name }))

        return [node, context]
      end

      def handle_hash(ast, context)
        node_hash_keys = add_vertex(Node.new(:hash_keys))
        node_hash_values = add_vertex(Node.new(:hash_values))
        node_hash = add_vertex(Node.new(:hash))
        @graph.add_edge(node_hash_keys, node_hash)
        @graph.add_edge(node_hash_values, node_hash)

        final_context = ast.children.reduce(context) do |current_context, ast_child|
          case ast_child.type
          when :pair
            hash_key, hash_value = ast_child.children
            hash_key_node, context_for_value = process(hash_key, current_context)
            hash_value_node, new_context = process(hash_value, context_for_value)
            @graph.add_edge(hash_key_node, node_hash_keys)
            @graph.add_edge(hash_value_node, node_hash_values)
            new_context
          when :kwsplat
            kwsplat_expr = ast_child.children[0]

            node_kwsplat, context_after_kwsplat = process(kwsplat_expr, context)

            node_unwrap_hash_keys = Node.new(:unwrap_hash_keys)
            node_unwrap_hash_values = Node.new(:unwrap_hash_values)

            @graph.add_edge(node_kwsplat, node_unwrap_hash_keys)
            @graph.add_edge(node_kwsplat, node_unwrap_hash_values)

            @graph.add_edge(node_unwrap_hash_keys, node_hash_keys)
            @graph.add_edge(node_unwrap_hash_values, node_hash_values)

            context_after_kwsplat
          else raise ArgumentError.new(ast)
          end
        end

        return [node_hash, final_context]
      end

      def handle_class(ast, context)
        klass_name_ast, parent_klass_name_ast, klass_body = ast.children
        klass_name_ref = ConstRef.from_ast(klass_name_ast, context.nesting)
        parent_name_ref = parent_klass_name_ast.nil? ? nil : ConstRef.from_ast(parent_klass_name_ast, context.nesting)

        klass = @tree.add_klass(
          GlobalTree::Klass.new(
            name: klass_name_ref.name,
            scope: context.scope.increase_by_ref(klass_name_ref).decrease,
            parent_ref: parent_name_ref,
            location: build_location(context, Position.new(klass_name_ast.loc.line, nil), Position.new(klass_name_ast.loc.line, nil))))

        new_context = context
          .with_analyzed_klass(klass)
          .with_nesting(context.nesting.increase_nesting_const(klass_name_ref))
          .with_selfie(Selfie.klass_from_scope(context.scope))
        if klass_body
          process(klass_body, new_context)
        end

        node = add_vertex(Node.new(:nil))

        return [node, context]
      end

      def handle_module(ast, context)
        module_name_ast = ast.children[0]
        module_body = ast.children[1]

        module_name_ref = ConstRef.from_ast(module_name_ast, context.nesting)

        @tree.add_mod(
          GlobalTree::Mod.new(
            name: module_name_ref.name,
            scope: context.scope.increase_by_ref(module_name_ref).decrease,
            location: build_location(context, Position.new(module_name_ast.loc.line, nil), Position.new(module_name_ast.loc.line, nil))))

        if module_body
          context2 = context.with_nesting(context.nesting.increase_nesting_const(module_name_ref))
          process(module_body, context2)
        end

        return [Node.new(:nil), context]
      end

      def handle_sclass(ast, context)
        self_name = ast.children[0]
        sklass_body = ast.children[1]
        process(sklass_body, context.with_nesting(context.nesting.increase_nesting_self))

        return [Node.new(:nil), context]
      end

      def handle_defs(ast, context)
        method_receiver = ast.children[0]
        method_name = ast.children[1]
        formal_arguments = ast.children[2]
        method_body = ast.children[3]

        arguments_tree, arguments_context, arguments_nodes = build_def_arguments(formal_arguments.children, context)

        metod = @tree.add_method(
          GlobalTree::Method.new(
            scope: context.scope.increase_by_metaklass,
            name: method_name.to_s,
            location: build_location(context, Position.new(ast.loc.line, nil), Position.new(ast.loc.line, nil)),
            args: arguments_tree,
            visibility: context.analyzed_klass.method_visibility,
            nodes: GlobalTree::Method::Nodes.new(arguments_nodes, add_vertex(Node.new(:method_result)), [])))

        context2 = context.with_analyzed_method(metod)
        if method_body
          context3 = context2.with_selfie(Selfie.klass_from_scope(context2.scope))
          final_node, _result_context = process(method_body, context3.merge_lenv(arguments_context.lenv))
          @graph.add_edge(final_node, context3.analyzed_method.nodes.result)
        else
          final_node = add_vertex(Node.new(:nil))
          @graph.add_edge(final_node, context2.analyzed_method.nodes.result)
        end

        node = add_vertex(Node.new(:sym, { value: method_name }))

        return [node, context]
      end

      def handle_casgn(ast, context)
        const_prename, const_name, expr = ast.children
        const_name_ref = ConstRef.from_full_name(AstUtils.const_prename_and_name_to_string(const_prename, const_name), context.nesting)

        if expr_is_class_definition?(expr)
          parent_klass_name_ast = expr.children[2]
          parent_name_ref = parent_klass_name_ast.nil? ? nil : ConstRef.from_ast(parent_klass_name_ast, context.nesting)
          @tree.add_klass(
            GlobalTree::Klass.new(
              name: const_name_ref.name,
              scope: context.scope.increase_by_ref(const_name_ref).decrease,
              parent_ref: parent_name_ref,
              location: build_location(context, Position.new(ast.loc.line, nil), Position.new(ast.loc.line, nil))))

          return [Node.new(:nil), context]
        elsif expr_is_module_definition?(expr)
          @tree.add_mod(
            GlobalTree::Mod.new(
              name: const_name_ref.name,
              scope: context.scope.increase_by_ref(const_name_ref).decrease,
              location: build_location(context, Position.new(ast.loc.line, nil), Position.new(ast.loc.line, nil))))

          return [Node.new(:nil), context]
        else
          @tree.add_constant(
            GlobalTree::Constant.new(
              name: const_name_ref.name,
              scope: context.scope.increase_by_ref(const_name_ref).decrease,
              location: build_location(context, Position.new(ast.loc.line, nil), Position.new(ast.loc.line, nil))))

          node_expr, final_context = process(expr, context)

          final_node = Node.new(:casgn, { const_ref: const_name_ref })
          @graph.add_edge(node_expr, final_node)

          const_name = context.scope.increase_by_ref(const_name_ref).to_const_name
          node_const_definition = @graph.get_constant_definition_node(const_name.to_string)
          @graph.add_edge(final_node, node_const_definition)

          return [final_node, final_context]
        end
      end

      def handle_const(ast, context)
        const_ref = ConstRef.from_ast(ast, context.nesting)

        node = add_vertex(Node.new(:const, { const_ref: const_ref }))

        return [node, context]
      end

      def handle_and(ast, context)
        handle_binary_operator(:and, ast.children[0], ast.children[1], context)
      end

      def handle_or(ast, context)
        handle_binary_operator(:or, ast.children[0], ast.children[1], context)
      end

      def handle_binary_operator(node_type, expr_left, expr_right, context)
        node_left, context_after_left = process(expr_left, context)
        node_right, context_after_right = process(expr_right, context_after_left)

        node_or = add_vertex(Node.new(node_type))
        @graph.add_edge(node_left, node_or)
        @graph.add_edge(node_right, node_or)

        return [node_or, context_after_right]
      end

      def handle_if(ast, context)
        expr_cond = ast.children[0]
        expr_iftrue = ast.children[1]
        expr_iffalse = ast.children[2]

        node_cond, context_after_cond = process(expr_cond, context)

        if expr_iftrue
          node_iftrue, context_after_iftrue = process(expr_iftrue, context_after_cond)
        else
          node_iftrue = add_vertex(Node.new(:nil))
          context_after_iftrue = context
        end

        if expr_iffalse
          node_iffalse, context_after_iffalse = process(expr_iffalse, context_after_cond)
        else
          node_iffalse = add_vertex(Node.new(:nil))
          context_after_iffalse = context
        end

        node_if_result = add_vertex(Node.new(:if_result))
        @graph.add_edge(node_iftrue, node_if_result)
        @graph.add_edge(node_iffalse, node_if_result)

        return [node_if_result, merge_contexts(context_after_iftrue, context_after_iffalse)]
      end

      def handle_return(ast, context)
        exprs = ast.children

        if exprs.size == 0
          node_expr, final_context = add_vertex(Node.new(:nil)), context
        elsif exprs.size == 1
          node_expr, final_context = process(exprs[0], context)
        else
          node_expr = add_vertex(Node.new(:array))
          final_context, nodes = fold_context(ast.children, context)
          add_edges(nodes, node_expr)
        end
        @graph.add_edge(node_expr, context.analyzed_method.nodes.result)

        return [node_expr, final_context]
      end

      def handle_masgn(ast, context)
        mlhs_expr = ast.children[0]
        rhs_expr = ast.children[1]

        node_rhs, context_after_rhs = process(rhs_expr, context)

        result_node, result_context = handle_mlhs_for_masgn(mlhs_expr, context, rhs_expr)

        return [result_node, result_context]
      end

      def handle_mlhs_for_masgn(ast, context, rhs_expr)
        result_node = add_vertex(Node.new(:array))

        i = 0
        final_context = ast.children.reduce(context) do |current_context, ast_child|
          if ast_child.type == :mlhs
            new_rhs_expr = Parser::AST::Node.new(:send, [rhs_expr, :[], Parser::AST::Node.new(:int, [i])])
            node_child, context_after_child = handle_mlhs_for_masgn(ast_child, current_context, new_rhs_expr)
          else
            new_ast_child = ast_child.append(Parser::AST::Node.new(:send, [rhs_expr, :[], Parser::AST::Node.new(:int, [i])]))
            node_child, context_after_child = process(new_ast_child, current_context)
          end

          @graph.add_edge(node_child, result_node)
          i += 1
          context_after_child
        end

        return [result_node, final_context]
      end

      def handle_alias(ast, context)
        node = add_vertex(Node.new(:nil))
        return [node, context]
      end

      def handle_super(ast, context)
        arg_exprs = ast.children

        call_arg_nodes = []
        final_context = arg_exprs.reduce(context) do |current_context, ast_child|
          ast_child_node, new_context = process(ast_child, current_context)
          call_arg_node = add_vertex(Node.new(:call_arg))
          call_arg_nodes << call_arg_node
          @graph.add_edge(ast_child_node, call_arg_node)
          new_context
        end

        call_result_node = add_vertex(Node.new(:call_result))

        super_send = Worklist::SuperSend.new(call_arg_nodes, call_result_node, nil)
        @worklist.add_message_send(super_send)

        return [call_result_node, final_context, { message_send: super_send }]
      end

      def handle_zsuper(ast, context)
        call_result_node = add_vertex(Node.new(:call_result))

        zsuper_send = Worklist::Super0Send.new(call_result_node, nil)
        @worklist.add_message_send(zsuper_send)

        return [call_result_node, context, { message_send: zsuper_send }]
      end

      def handle_while(ast, context)
        expr_cond = ast.children[0]
        expr_body = ast.children[1]

        node_cond, new_context = process(expr_cond, context)
        node_body, final_context = process(expr_body, new_context)

        node = add_vertex(Node.new(:nil))

        return [node, final_context]
      end

      def handle_case(ast, context)
        expr_cond = ast.children[0]
        expr_branches = ast.children[1..-1].compact

        node_cond, new_context = process(expr_cond, context)

        node_case_result = add_vertex(Node.new(:case_result))
        final_context = expr_branches.reduce(new_context) do |current_context, expr_when|
          node_when, next_context = process(expr_when, current_context)
          @graph.add_edge(node_when, node_case_result)
          next_context
        end

        return [node_case_result, final_context]
      end

      def handle_yield(ast, context)
        exprs = ast.children

        node_yield = add_vertex(Node.new(:yield))
        final_context = if exprs.empty?
          @graph.add_edge(Node.new(:nil), node_yield)
          context
        else
          exprs.reduce(context) do |current_context, current_expr|
            current_node, next_context = process(current_expr, current_context)
            @graph.add_edge(current_node, node_yield)
            next_context
          end
        end
        if context.analyzed_method
          context.analyzed_method.nodes.yields << node_yield
        end
        result_node = add_vertex(Node.new(:nil))

        return [result_node, final_context]
      end

      def handle_when(ast, context)
        expr_cond = ast.children[0]
        expr_body = ast.children[1]

        node_cond, context_after_cond = process(expr_cond, context)
        node_body, context_after_body = process(expr_body, context_after_cond)

        return [node_body, context_after_body]
      end

      def handle_break(ast, context)
        return [Node.new(:nil), context]
      end

      def handle_block_pass(ast, context)
        expr = ast.children[0]

        node_block_pass, next_context = process(expr, context)

        return [node_block_pass, next_context]
      end

      def handle_resbody(ast, context)
        error_array_expr = ast.children[0]
        assignment_expr = ast.children[1]
        rescue_body_expr = ast.children[2]

        context_after_errors = if error_array_expr
          node_error_array, context_after_errors = process(error_array_expr, context)
          unwrap_node = add_vertex(Node.new(:unwrap_array))
          @graph.add_edge(node_error_array, unwrap_node)
          context_after_errors
        else
          context
        end

        context_after_assignment = if assignment_expr
          node_assignment, context_after_assignment = process(assignment_expr, context_after_errors)
          @graph.add_edge(unwrap_node, node_assignment) if unwrap_node
          context_after_assignment
        else
          context
        end

        if rescue_body_expr
          node_rescue_body, final_context = process(rescue_body_expr, context_after_assignment)
        else
          node_rescue_body = add_vertex(Node.new(:nil))
          final_context = context
        end

        return [node_rescue_body, final_context]
      end

      def handle_rescue(ast, context)
        try_expr = ast.children[0]
        resbody = ast.children[1]
        elsebody = ast.children[2]

        node_try, context_after_try = if try_expr
          process(try_expr, context)
        else
          [add_vertex(Node.new(:nil)), context]
        end

        node_resbody, context_after_resbody = process(resbody, context_after_try)

        node = add_vertex(Node.new(:rescue))
        @graph.add_edge(node_resbody, node)

        if elsebody
          node_else, context_after_else = process(elsebody, context_after_try)
          @graph.add_edge(node_else, node)
          return [node, merge_contexts(context_after_resbody, context_after_else)]
        else
          @graph.add_edge(node_try, node)
          return [node, context_after_resbody]
        end
      end

      def handle_retry(ast, context)
        return [add_vertex(Node.new(:nil)), context]
      end

      def handle_ensure(ast, context)
        expr_pre = ast.children[0]
        expr_ensure_body = ast.children[1]

        node_ensure = add_vertex(Node.new(:ensure))

        node_pre, context_after_pre = process(expr_pre, context)
        @graph.add_edge(node_pre, node_ensure) if node_pre

        node_ensure_body, context_after_ensure_body = process(expr_ensure_body, context_after_pre)
        @graph.add_edge(node_ensure_body, node_ensure) if node_ensure_body

        return [node_ensure, context_after_ensure_body]
      end

      def handle_op_asgn(ast, context)
        expr_partial_asgn = ast.children[0]
        method_name = ast.children[1]
        expr_argument = ast.children[2]

        case expr_partial_asgn.type
        when :lvasgn
          var_name = expr_partial_asgn.children[0]
          expr_full_rhs = Parser::AST::Node.new(:send,
                                                [Parser::AST::Node.new(:lvar, [var_name]), method_name, expr_argument])
          expr_full_asgn = expr_partial_asgn.append(expr_full_rhs)
        when :ivasgn
          var_name = expr_partial_asgn.children[0]
          expr_full_rhs = Parser::AST::Node.new(:send,
                                                [Parser::AST::Node.new(:ivar, [var_name]), method_name, expr_argument])
          expr_full_asgn = expr_partial_asgn.append(expr_full_rhs)
        when :cvasgn
          var_name = expr_partial_asgn.children[0]
          expr_full_rhs = Parser::AST::Node.new(:send,
                                                [Parser::AST::Node.new(:cvar, [var_name]), method_name, expr_argument])
          expr_full_asgn = expr_partial_asgn.append(expr_full_rhs)
        when :casgn
          scope = expr_partial_asgn.children[0]
          var_name = expr_partial_asgn.children[1]
          expr_full_rhs = Parser::AST::Node.new(:send,
                                                [Parser::AST::Node.new(:const, [scope, var_name]), method_name, expr_argument])
          expr_full_asgn = expr_partial_asgn.append(expr_full_rhs)
        when :send
          send_obj = expr_partial_asgn.children[0]
          asgn_method_name = expr_partial_asgn.children[1]
          args = expr_partial_asgn.children[2..-1]
          expr_full_rhs = Parser::AST::Node.new(:send,
                                                [Parser::AST::Node.new(:send, [send_obj, asgn_method_name, *args]), method_name, expr_argument])
          expr_full_asgn = expr_partial_asgn.updated(nil, [send_obj, "#{asgn_method_name}=", expr_full_rhs])
        else raise ArgumentError
        end
        final_node, final_context = process(expr_full_asgn, context)

        return [final_node, final_context]
      end

      def handle_or_asgn(ast, context)
        expr_partial_asgn = ast.children[0]
        expr_argument = ast.children[1]

        case expr_partial_asgn.type
        when :lvasgn
          var_name = expr_partial_asgn.children[0]
          expr_full_rhs = Parser::AST::Node.new(:or,
                                                [Parser::AST::Node.new(:lvar, [var_name]), expr_argument])
          expr_full_asgn = expr_partial_asgn.append(expr_full_rhs)
        when :ivasgn
          var_name = expr_partial_asgn.children[0]
          expr_full_rhs = Parser::AST::Node.new(:or,
                                                [Parser::AST::Node.new(:ivar, [var_name]), expr_argument])
          expr_full_asgn = expr_partial_asgn.append(expr_full_rhs)
        when :cvasgn
          var_name = expr_partial_asgn.children[0]
          expr_full_rhs = Parser::AST::Node.new(:or,
                                                [Parser::AST::Node.new(:cvar, [var_name]), expr_argument])
          expr_full_asgn = expr_partial_asgn.append(expr_full_rhs)
        when :casgn
          scope = expr_partial_asgn.children[0]
          var_name = expr_partial_asgn.children[1]
          expr_full_rhs = Parser::AST::Node.new(:or,
                                                [Parser::AST::Node.new(:const, [scope, var_name]), expr_argument])
          expr_full_asgn = expr_partial_asgn.append(expr_full_rhs)
        when :send
          send_obj = expr_partial_asgn.children[0]
          asgn_method_name = expr_partial_asgn.children[1]
          args = expr_partial_asgn.children[2..-1]
          expr_full_rhs = Parser::AST::Node.new(:or,
                                                [Parser::AST::Node.new(:send, [send_obj, asgn_method_name, *args]), expr_argument])
          expr_full_asgn = expr_partial_asgn.updated(nil, [send_obj, "#{asgn_method_name}=", expr_full_rhs])
        else raise ArgumentError
        end
        final_node, final_context = process(expr_full_asgn, context)

        return [final_node, final_context]
      end

      def handle_and_asgn(ast, context)
        expr_partial_asgn = ast.children[0]
        expr_argument = ast.children[1]

        case expr_partial_asgn.type
        when :lvasgn
          var_name = expr_partial_asgn.children[0]
          expr_full_rhs = Parser::AST::Node.new(:and,
                                                [Parser::AST::Node.new(:lvar, [var_name]), expr_argument])
          expr_full_asgn = expr_partial_asgn.append(expr_full_rhs)
        when :ivasgn
          var_name = expr_partial_asgn.children[0]
          expr_full_rhs = Parser::AST::Node.new(:and,
                                                [Parser::AST::Node.new(:ivar, [var_name]), expr_argument])
          expr_full_asgn = expr_partial_asgn.append(expr_full_rhs)
        when :cvasgn
          var_name = expr_partial_asgn.children[0]
          expr_full_rhs = Parser::AST::Node.new(:and,
                                                [Parser::AST::Node.new(:cvar, [var_name]), expr_argument])
          expr_full_asgn = expr_partial_asgn.append(expr_full_rhs)
        when :casgn
          scope = expr_partial_asgn.children[0]
          var_name = expr_partial_asgn.children[1]
          expr_full_rhs = Parser::AST::Node.new(:and,
                                                [Parser::AST::Node.new(:const, [scope, var_name]), expr_argument])
          expr_full_asgn = expr_partial_asgn.append(expr_full_rhs)
        when :send
          send_obj = expr_partial_asgn.children[0]
          asgn_method_name = expr_partial_asgn.children[1]
          args = expr_partial_asgn.children[2..-1]
          expr_full_rhs = Parser::AST::Node.new(:and,
                                                [Parser::AST::Node.new(:send, [send_obj, asgn_method_name, *args]), expr_argument])
          expr_full_asgn = expr_partial_asgn.updated(nil, [send_obj, "#{asgn_method_name}=", expr_full_rhs])
        else raise ArgumentError
        end
        final_node, final_context = process(expr_full_asgn, context)

        return [final_node, final_context]
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

      def get_ivar_definition_node(context, ivar_name)
        klass = @tree.constants.find do |c|
          c.full_name == context.scope.absolute_str
        end

        raise if klass.nil?

        if !klass.nodes.instance_variables[ivar_name]
          klass.nodes.instance_variables[ivar_name] = add_vertex(Node.new(:ivar_definition))
        end

        return klass.nodes.instance_variables[ivar_name]
      end

      def get_class_level_ivar_definition_node(context, ivar_name)
        klass = @tree.constants.find do |c|
          c.full_name == context.scope.absolute_str
        end

        raise if klass.nil?

        if !klass.nodes.class_level_instance_variables[ivar_name]
          klass.nodes.class_level_instance_variables[ivar_name] = add_vertex(Node.new(:clivar_definition))
        end

        return klass.nodes.class_level_instance_variables[ivar_name]
      end

      def get_cvar_definition_node(context, cvar_name)
        klass = @tree.constants.find do |c|
          c.full_name == context.scope.absolute_str
        end

        raise if klass.nil?

        if !klass.nodes.class_variables[cvar_name]
          klass.nodes.class_variables[cvar_name] = add_vertex(Node.new(:cvar_definition))
        end

        return klass.nodes.class_variables[cvar_name]
      end

      def build_arguments(formal_arguments, context)
        formal_arguments_nodes = []
        formal_arguments_hash = formal_arguments.children.each_with_object({}) do |arg_ast, h|
          arg_name = arg_ast.children[0]&.to_s
          maybe_arg_default_expr = arg_ast.children[1]

          arg_node = if arg_ast.type == :arg
            Node.new(:formal_arg, { var_name: arg_name })
          elsif arg_ast.type == :optarg
            Node.new(:formal_optarg, { var_name: arg_name })
          elsif arg_ast.type == :restarg
            Node.new(:formal_restarg, { var_name: arg_name })
          elsif arg_ast.type == :kwarg
            Node.new(:formal_kwarg, { var_name: arg_name })
          elsif arg_ast.type == :kwoptarg
            Node.new(:formal_kwoptarg, { var_name: arg_name })
          elsif arg_ast.type == :kwrestarg
            Node.new(:formal_kwrestarg, { var_name: arg_name })
          else raise
          end

          if maybe_arg_default_expr
            node_arg_default, _context = process(maybe_arg_default_expr, context)
            @graph.add_edge(node_arg_default, arg_node)
          end

          formal_arguments_nodes << arg_node
          add_vertex(arg_node)
          h[arg_name] = [arg_node]
        end
        return [formal_arguments_hash, formal_arguments_nodes]
      end

      def build_def_arguments(formal_arguments, context)
        args = []
        kwargs = []
        blockarg = nil

        nodes = {}

        final_context = formal_arguments.reduce(context) do |current_context, arg_ast|
          arg_name = arg_ast.children[0]&.to_s
          maybe_arg_default_expr = arg_ast.children[1]

          case arg_ast.type
          when :arg
            args << GlobalTree::Method::ArgumentsTree::Regular.new(arg_name)
            nodes[arg_name] = add_vertex(Node.new(:formal_arg, { var_name: arg_name }))
            current_context.merge_lenv(arg_name => [nodes[arg_name]])
          when :optarg
            args << GlobalTree::Method::ArgumentsTree::Optional.new(arg_name)
            arg_node, next_context = process(maybe_arg_default_expr, current_context)
            nodes[arg_name] = add_vertex(Node.new(:formal_optarg, { var_name: arg_name }))
            @graph.add_edge(arg_node, nodes[arg_name])
            next_context.merge_lenv(arg_name => [nodes[arg_name]])
          when :restarg
            args << GlobalTree::Method::ArgumentsTree::Splat.new(arg_name)
            nodes[arg_name] = add_vertex(Node.new(:formal_restarg, { var_name: arg_name }))
            current_context.merge_lenv(arg_name => [nodes[arg_name]])
          when :kwarg
            kwargs << GlobalTree::Method::ArgumentsTree::Regular.new(arg_name)
            nodes[arg_name] = add_vertex(Node.new(:formal_kwarg, { var_name: arg_name }))
            current_context.merge_lenv(arg_name => [nodes[arg_name]])
          when :kwoptarg
            kwargs << GlobalTree::Method::ArgumentsTree::Optional.new(arg_name)
            arg_node, next_context = process(maybe_arg_default_expr, current_context)
            nodes[arg_name] = add_vertex(Node.new(:formal_kwoptarg, { var_name: arg_name }))
            @graph.add_edge(arg_node, nodes[arg_name])
            next_context.merge_lenv(arg_name => [nodes[arg_name]])
          when :kwrestarg
            kwargs << GlobalTree::Method::ArgumentsTree::Splat.new(arg_name)
            nodes[arg_name] = add_vertex(Node.new(:formal_kwrestarg, { var_name: arg_name }))
            current_context.merge_lenv(arg_name => [nodes[arg_name]])
          when :mlhs
            mlhs_node = add_vertex(Node.new(:formal_mlhs))
            nested_arg, next_context = build_def_arguments_nested(arg_ast.children, nodes, current_context, mlhs_node)
            args << nested_arg
            next_context
          else raise
          end
        end

        return GlobalTree::Method::ArgumentsTree.new(args, kwargs, blockarg), final_context, nodes
      end

      def build_def_arguments_nested(arg_asts, nodes, context, mlhs_node)
        args = []

        final_context = arg_asts.reduce(context) do |current_context, arg_ast|
          arg_name = arg_ast.children[0]&.to_s

          case arg_ast.type
          when :arg
            args << GlobalTree::Method::ArgumentsTree::Regular.new(arg_name)
            nodes[arg_name] = add_vertex(Node.new(:formal_arg, { var_name: arg_name }))
            current_context.merge(arg_name => [nodes[arg_name]])
          when :restarg
            args << GlobalTree::Method::ArgumentsTree::Splat.new(arg_name)
            nodes[arg_name] = add_vertex(Node.new(:formal_restarg, { var_name: arg_name }))
            current_context.merge(arg_name => [nodes[arg_name]])
          when :mlhs
            mlhs_node = add_vertex(Node.new(:formal_mlhs))
            nested_arg, next_context = build_def_arguments_nested(arg_ast.children, nodes, current_context, mlhs_node)
            args << nested_arg
            next_context
          else raise
          end
        end

        return ArgumentsTree::Nested.new(args), final_context
      end

      def merge_contexts(context1, context2)
        raise if !context1.almost_equal?(context2)
        final_lenv = {}

        var_names = (context1.lenv.keys + context2.lenv.keys).uniq
        var_names.each do |var_name|
          final_lenv[var_name] = context1.lenv.fetch(var_name, []) + context2.lenv.fetch(var_name, [])
        end

        context1.with_lenv(final_lenv)
      end

      def fold_context(exprs, context)
        nodes = []
        final_context = exprs.reduce(context) do |current_context, ast_child|
          ast_child_node, new_context = process(ast_child, current_context)
          nodes << ast_child_node
          new_context
        end
        return final_context, nodes
      end

      def build_location(context, pstart, pend)
        Location.new(context.filepath, PositionRange.new(pstart, pend))
      end

      def build_location_from_ast(context, ast)
        Location.new(
          context.filepath,
          PositionRange.new(
            Position.new(ast.loc.expression.begin.line, ast.loc.expression.begin.column + 1),
            Position.new(ast.loc.expression.end.line, ast.loc.expression.end.column + 1)))
      end

      def add_vertex(v)
        @graph.add_vertex(v)
      end

      def add_edges(xs, ys)
        @graph.add_edges(xs, ys)
      end
    end
  end
end
