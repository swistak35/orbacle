require 'rgl/adjacency'
require 'parser/current'
require 'orbacle/nesting'

module Orbacle
  class DataFlowGraph
    ProcessError = Class.new(StandardError)

    class Node
      def initialize(type, params = {})
        @type = type
        @params = params
      end

      attr_reader :type, :params

      def ==(other)
        @type == other.type && @params == other.params
      end

      def to_s
        "#<#{self.class.name}:#{self.object_id} @type=#{@type.inspect}>"
      end
    end

    MessageSend = Struct.new(:message_send, :send_obj, :send_args, :send_result, :block)
    SuperSend = Struct.new(:send_args, :send_result, :block)
    Super0Send = Struct.new(:send_result, :block)

    Block = Struct.new(:args, :result)
    BlockPass = Struct.new(:node)
    CurrentlyAnalyzedKlass = Struct.new(:klass, :method_visibility)

    Result = Struct.new(:graph, :final_lenv, :message_sends, :final_node, :tree)

    def process_file(file)
      ast = Parser::CurrentRuby.parse(file)

      @graph = RGL::DirectedAdjacencyGraph.new
      @message_sends = []
      @current_nesting = Nesting.new
      @current_selfie = Selfie.main
      @tree = GlobalTree.new
      @currently_analyzed_klass = CurrentlyAnalyzedKlass.new(nil, :public)

      initial_local_environment = {}
      if ast
        final_node, final_local_environment = process(ast, initial_local_environment)
      else
        final_node = nil
        final_local_environment = initial_local_environment
      end

      return Result.new(@graph, final_local_environment, @message_sends, final_node, @tree)
    rescue
      puts "Error processing:\n#{file}"
      raise
    end

    private

    attr_reader :current_nesting, :current_selfie

    def process(ast, lenv)
      return [nil, lenv] if ast.nil?

      case ast.type
      when :lvasgn
        handle_lvasgn(ast, lenv)
      when :int
        handle_int(ast, lenv)
      when :float
        handle_float(ast, lenv)
      when :true
        handle_true(ast, lenv)
      when :false
        handle_false(ast, lenv)
      when :nil
        handle_nil(ast, lenv)
      when :self
        handle_self(ast, lenv)
      when :array
        handle_array(ast, lenv)
      when :splat
        handle_splat(ast, lenv)
      when :str
        handle_str(ast, lenv)
      when :dstr
        handle_dstr(ast, lenv)
      when :sym
        handle_sym(ast, lenv)
      when :dsym
        handle_dsym(ast, lenv)
      when :regexp
        handle_regexp(ast, lenv)
      when :hash
        handle_hash(ast, lenv)
      when :irange
        handle_irange(ast, lenv)
      when :erange
        handle_erange(ast, lenv)
      when :back_ref
        handle_ref(ast, lenv, :backref)
      when :nth_ref
        handle_ref(ast, lenv, :nthref)
      when :defined?
        handle_defined(ast, lenv)
      when :begin
        handle_begin(ast, lenv)
      when :kwbegin
        handle_begin(ast, lenv)
      when :lvar
        handle_lvar(ast, lenv)
      when :ivar
        handle_ivar(ast, lenv)
      when :ivasgn
        handle_ivasgn(ast, lenv)
      when :cvar
        handle_cvar(ast, lenv)
      when :cvasgn
        handle_cvasgn(ast, lenv)
      when :gvar
        handle_gvar(ast, lenv)
      when :gvasgn
        handle_gvasgn(ast, lenv)
      when :send
        handle_send(ast, lenv, false)
      when :csend
        handle_send(ast, lenv, true)
      when :block
        handle_block(ast, lenv)
      when :def
        handle_def(ast, lenv)
      when :defs
        handle_defs(ast, lenv)
      when :class
        handle_class(ast, lenv)
      when :sclass
        handle_sclass(ast, lenv)
      when :module
        handle_module(ast, lenv)
      when :casgn
        handle_casgn(ast, lenv)
      when :const
        handle_const(ast, lenv)
      when :and
        handle_and(ast, lenv)
      when :or
        handle_or(ast, lenv)
      when :if
        handle_if(ast, lenv)
      when :return
        handle_return(ast, lenv)
      when :masgn
        handle_masgn(ast, lenv)
      when :mlhs
        handle_mlhs(ast, lenv)
      when :alias
        handle_alias(ast, lenv)
      when :super
        handle_super(ast, lenv)
      when :zsuper
        handle_zsuper(ast, lenv)
      when :when
        handle_when(ast, lenv)
      when :case
        handle_case(ast, lenv)
      when :yield
        handle_yield(ast, lenv)
      when :block_pass
        handle_block_pass(ast, lenv)

      when :while then handle_while(ast, lenv)
      when :until then handle_while(ast, lenv)
      when :while_post then handle_while(ast, lenv)
      when :until_post then handle_while(ast, lenv)
      when :break then handle_break(ast, lenv)
      when :next then handle_break(ast, lenv)
      when :redo then handle_break(ast, lenv)

      when :rescue then handle_rescue(ast, lenv)
      when :resbody then handle_resbody(ast, lenv)
      when :retry then handle_retry(ast, lenv)
      when :ensure then handle_ensure(ast, lenv)

      else
        raise ArgumentError.new(ast.type)
      end
    end

    def handle_lvasgn(ast, lenv)
      var_name = ast.children[0].to_s
      expr = ast.children[1]

      node_lvasgn = add_vertex(Node.new(:lvasgn, { var_name: var_name }))

      if expr
        node_expr, lenv_after_expr = process(expr, lenv)
        @graph.add_edge(node_expr, node_lvasgn)
        final_lenv = lenv_after_expr.merge(var_name => [node_lvasgn])
      else
        final_lenv = lenv.merge(var_name => [node_lvasgn])
      end

      return [node_lvasgn, final_lenv]
    end

    def handle_int(ast, lenv)
      value = ast.children[0]
      n = add_vertex(Node.new(:int, { value: value }))

      return [n, lenv]
    end

    def handle_float(ast, lenv)
      value = ast.children[0]
      n = add_vertex(Node.new(:float, { value: value }))

      return [n, lenv]
    end

    def handle_true(ast, lenv)
      n = add_vertex(Node.new(:bool, { value: true }))

      return [n, lenv]
    end

    def handle_false(ast, lenv)
      n = add_vertex(Node.new(:bool, { value: false }))

      return [n, lenv]
    end

    def handle_nil(ast, lenv)
      n = add_vertex(Node.new(:nil))

      return [n, lenv]
    end

    def handle_str(ast, lenv)
      value = ast.children[0]
      n = add_vertex(Node.new(:str, { value: value }))

      return [n, lenv]
    end

    def handle_dstr(ast, lenv)
      node_dstr = add_vertex(Node.new(:dstr))

      final_lenv = ast.children.reduce(lenv) do |current_lenv, ast_child|
        ast_child_node, new_lenv = process(ast_child, current_lenv)
        @graph.add_edge(ast_child_node, node_dstr)
        new_lenv
      end

      return [node_dstr, final_lenv]
    end

    def handle_sym(ast, lenv)
      value = ast.children[0]
      n = add_vertex(Node.new(:sym, { value: value }))

      return [n, lenv]
    end

    def handle_dsym(ast, lenv)
      node_dsym = add_vertex(Node.new(:dsym))

      final_lenv = ast.children.reduce(lenv) do |current_lenv, ast_child|
        ast_child_node, new_lenv = process(ast_child, current_lenv)
        @graph.add_edge(ast_child_node, node_dsym)
        new_lenv
      end

      return [node_dsym, final_lenv]
    end

    def handle_array(ast, lenv)
      node_array = add_vertex(Node.new(:array))

      final_lenv = ast.children.reduce(lenv) do |current_lenv, ast_child|
        ast_child_node, new_lenv = process(ast_child, current_lenv)
        @graph.add_edge(ast_child_node, node_array)
        new_lenv
      end

      return [node_array, final_lenv]
    end

    def handle_splat(ast, lenv)
      expr = ast.children[0]

      node_expr, lenv_after_expr = process(expr, lenv)

      node_splat = Node.new(:splat_array)
      @graph.add_edge(node_expr, node_splat)

      return [node_splat, lenv_after_expr]
    end

    def handle_regexp(ast, lenv)
      expr_nodes = ast.children[0..-2]
      regopt = ast.children[-1]

      node_regexp = Node.new(:regexp, { regopt: regopt.children })

      final_lenv = expr_nodes.reduce(lenv) do |current_lenv, ast_child|
        ast_child_node, new_lenv = process(ast_child, current_lenv)
        @graph.add_edge(ast_child_node, node_regexp)
        new_lenv
      end

      return [node_regexp, final_lenv]
    end

    def handle_irange(ast, lenv)
      common_range(ast, lenv, true)
    end

    def handle_erange(ast, lenv)
      common_range(ast, lenv, false)
    end

    def common_range(ast, lenv, inclusive)
      range_from_ast = ast.children[0]
      range_to_ast = ast.children[1]

      range_node = Node.new(:range, { inclusive: inclusive })

      range_from_node, lenv2 = process(range_from_ast, lenv)
      from_node = Node.new(:range_from)
      @graph.add_edge(range_from_node, from_node)
      @graph.add_edge(from_node, range_node)

      range_to_node, final_lenv = process(range_to_ast, lenv2)
      to_node = Node.new(:range_to)
      @graph.add_edge(range_to_node, to_node)
      @graph.add_edge(to_node, range_node)

      return [range_node, final_lenv]
    end

    def handle_ref(ast, lenv, node_type)
      ref = ast.children[0].to_s
      node = add_vertex(Node.new(node_type, { ref: ref }))
      return [node, lenv]
    end

    def handle_defined(ast, lenv)
      _expr = ast.children[0]

      node = Node.new(:defined)

      return [node, lenv]
    end

    def handle_begin(ast, lenv)
      final_node, final_lenv = ast.children.reduce([nil, lenv]) do |current, ast_child|
        current_node = current[0]
        current_lenv = current[1]
        process(ast_child, current_lenv)
      end
      return [final_node, final_lenv]
    end

    def handle_lvar(ast, lenv)
      var_name = ast.children[0].to_s

      node_lvar = add_vertex(Node.new(:lvar, { var_name: var_name }))

      lenv.fetch(var_name).each do |var_definition_node|
        @graph.add_edge(var_definition_node, node_lvar)
      end

      return [node_lvar, lenv]
    end

    def handle_ivar(ast, lenv)
      ivar_name = ast.children.first.to_s

      ivar_definition_node = if current_selfie.klass?
        get_class_level_ivar_definition_node(ivar_name)
      elsif current_selfie.instance?
        get_ivar_definition_node(ivar_name)
      else
        raise
      end

      node = Node.new(:ivar)
      @graph.add_edge(ivar_definition_node, node)

      return [node, lenv]
    end

    def handle_ivasgn(ast, lenv)
      ivar_name = ast.children[0].to_s
      expr = ast.children[1]

      node_ivasgn = add_vertex(Node.new(:ivasgn, { var_name: ivar_name }))

      if expr
        node_expr, lenv_after_expr = process(expr, lenv)
        @graph.add_edge(node_expr, node_ivasgn)
      else
        lenv_after_expr = lenv
      end

      ivar_definition_node = if current_selfie.klass?
        get_class_level_ivar_definition_node(ivar_name)
      elsif current_selfie.instance?
        get_ivar_definition_node(ivar_name)
      else
        raise
      end
      @graph.add_edge(node_ivasgn, ivar_definition_node)

      return [node_ivasgn, lenv_after_expr]
    end

    def handle_cvasgn(ast, lenv)
      cvar_name = ast.children[0].to_s
      expr = ast.children[1]

      node_cvasgn = add_vertex(Node.new(:cvasgn, { var_name: cvar_name }))

      if expr
        node_expr, lenv_after_expr = process(expr, lenv)
        @graph.add_edge(node_expr, node_cvasgn)
      else
        lenv_after_expr = lenv
      end

      node_cvar_definition = get_cvar_definition_node(cvar_name)
      @graph.add_edge(node_cvasgn, node_cvar_definition)

      return [node_cvasgn, lenv_after_expr]
    end

    def handle_cvar(ast, lenv)
      cvar_name = ast.children.first.to_s

      cvar_definition_node = get_cvar_definition_node(cvar_name)

      node = Node.new(:cvar)
      @graph.add_edge(cvar_definition_node, node)

      return [node, lenv]
    end

    def handle_gvasgn(ast, lenv)
      gvar_name = ast.children[0].to_s
      expr = ast.children[1]

      node_gvasgn = add_vertex(Node.new(:gvasgn, { var_name: gvar_name }))

      node_expr, lenv_after_expr = process(expr, lenv)
      @graph.add_edge(node_expr, node_gvasgn)

      node_gvar_definition = get_gvar_definition_node(gvar_name)
      @graph.add_edge(node_gvasgn, node_gvar_definition)

      return [node_gvasgn, lenv_after_expr]
    end

    def handle_gvar(ast, lenv)
      gvar_name = ast.children.first.to_s

      gvar_definition_node = get_gvar_definition_node(gvar_name)

      node = add_vertex(Node.new(:gvar))
      @graph.add_edge(gvar_definition_node, node)

      return [node, lenv]
    end

    def handle_send(ast, lenv, csend)
      obj_expr = ast.children[0]
      message_name = ast.children[1].to_s
      arg_exprs = ast.children[2..-1]

      if obj_expr.nil?
        obj_node = add_vertex(Node.new(:self, { selfie: current_selfie }))
        obj_lenv = lenv
      else
        obj_node, obj_lenv = process(obj_expr, lenv)
      end

      call_arg_nodes = []
      final_lenv = arg_exprs.reduce(obj_lenv) do |current_lenv, ast_child|
        ast_child_node, new_lenv = process(ast_child, current_lenv)
        call_arg_node = add_vertex(Node.new(:call_arg))
        call_arg_nodes << call_arg_node
        @graph.add_edge(ast_child_node, call_arg_node)
        new_lenv
      end

      return handle_changing_visibility(lenv, message_name.to_sym, arg_exprs) if obj_expr.nil? && ["public", "protected", "private"].include?(message_name)

      call_obj_node = add_vertex(Node.new(:call_obj))
      @graph.add_edge(obj_node, call_obj_node)

      call_result_node = add_vertex(Node.new(:call_result, { csend: csend }))

      message_send = MessageSend.new(message_name, call_obj_node, call_arg_nodes, call_result_node, nil)
      @message_sends << message_send

      return [call_result_node, final_lenv, { message_send: message_send }]
    end

    def handle_changing_visibility(lenv, new_visibility, arg_exprs)
      node = if @currently_analyzed_klass.klass
        if arg_exprs.empty?
          @currently_analyzed_klass.method_visibility = new_visibility
        else
          methods_to_change_visibility = arg_exprs.map do |arg_expr|
            [:sym, :str].include?(arg_expr.type) ? arg_expr.children[0].to_s : nil
          end.compact
          @tree.methods.each do |m|
            if m.scope == current_scope && methods_to_change_visibility.include?(m.name)
              m.visibility = new_visibility
            end
          end
        end

        Node.new(:class, { klass: @currently_analyzed_klass.klass })
      else
        # This should actually be reference to Object class
        Node.new(:nil)
      end
      add_vertex(node)

      return [node, lenv]
    end

    def handle_self(ast, lenv)
      node = add_vertex(Node.new(:self, { selfie: current_selfie }))
      return [node, lenv]
    end

    def handle_block(ast, lenv)
      send_expr = ast.children[0]
      args_ast = ast.children[1]
      block_expr = ast.children[2]

      send_node, send_lenv, _additional = process(send_expr, lenv)
      message_send = _additional.fetch(:message_send)

      args_ast_nodes = []
      lenv_with_args = args_ast.children.reduce(send_lenv) do |current_lenv, arg_ast|
        arg_name = arg_ast.children[0].to_s
        arg_node = add_vertex(Node.new(:block_arg, { var_name: arg_name }))
        args_ast_nodes << arg_node
        current_lenv.merge(arg_name => [arg_node])
      end

      # It's not exactly good - local vars defined in blocks are not available outside (?),
      #     but assignments done in blocks are valid.
      block_final_node, block_result_lenv = process(block_expr, lenv_with_args)
      block_result_node = add_vertex(Node.new(:block_result))
      @graph.add_edge(block_final_node, block_result_node)
      block = Block.new(args_ast_nodes, block_result_node)
      message_send.block = block

      return [send_node, block_result_lenv]
    end

    def handle_def(ast, lenv)
      method_name = ast.children[0]
      formal_arguments = ast.children[1]
      method_body = ast.children[2]

      formal_arguments_hash, formal_arguments_nodes = build_arguments(formal_arguments, lenv)

      @currently_parsed_method_result_node = add_vertex(Node.new(:method_result))
      if method_body
        with_selfie(Selfie.instance_from_scope(current_scope)) do
          final_node, _result_lenv = process(method_body, lenv.merge(formal_arguments_hash))
          @graph.add_edge(final_node, @currently_parsed_method_result_node)
        end
      else
        final_node = add_vertex(Node.new(:nil))
        @graph.add_edge(final_node, @currently_parsed_method_result_node)
      end

      @tree.add_method(
        name: method_name.to_s,
        line: ast.loc.line,
        visibility: @currently_analyzed_klass.method_visibility,
        node_result: @currently_parsed_method_result_node,
        node_formal_arguments: formal_arguments_nodes,
        scope: current_scope)

      node = add_vertex(Node.new(:sym, { value: method_name }))

      return [node, lenv]
    end

    def handle_hash(ast, lenv)
      node_hash_keys = add_vertex(Node.new(:hash_keys))
      node_hash_values = add_vertex(Node.new(:hash_values))
      node_hash = add_vertex(Node.new(:hash))
      @graph.add_edge(node_hash_keys, node_hash)
      @graph.add_edge(node_hash_values, node_hash)

      final_lenv = ast.children.reduce(lenv) do |current_lenv, ast_child|
        hash_key, hash_value = ast_child.children
        hash_key_node, lenv_for_value = process(hash_key, current_lenv)
        hash_value_node, new_lenv = process(hash_value, lenv_for_value)
        @graph.add_edge(hash_key_node, node_hash_keys)
        @graph.add_edge(hash_value_node, node_hash_values)
        new_lenv
      end

      return [node_hash, final_lenv]
    end

    def handle_class(ast, lenv)
      klass_name_ast, parent_klass_name_ast, klass_body = ast.children
      klass_name_ref = ConstRef.from_ast(klass_name_ast)

      klass = @tree.add_klass(
        name: klass_name_ref.name,
        scope: current_scope.increase_by_ref(klass_name_ref).decrease,
        inheritance_name: parent_klass_name_ast.nil? ? nil : AstUtils.const_to_string(parent_klass_name_ast),
        inheritance_nesting: current_nesting.to_primitive,
        line: klass_name_ast.loc.line)

      switch_currently_analyzed_klass(klass) do
        with_new_nesting(current_nesting.increase_nesting_const(klass_name_ref)) do
          with_selfie(Selfie.klass_from_scope(current_scope)) do
            if klass_body
              process(klass_body, lenv)
            end
          end
        end
      end

      node = add_vertex(Node.new(:nil))

      return [node, lenv]
    end

    def handle_module(ast, lenv)
      module_name_ast = ast.children[0]
      module_body = ast.children[1]

      module_name_ref = ConstRef.from_ast(module_name_ast)

      @tree.add_mod(
        name: module_name_ref.name,
        scope: current_scope.increase_by_ref(module_name_ref).decrease,
        line: module_name_ast.loc.line)

      if module_body
        with_new_nesting(current_nesting.increase_nesting_const(module_name_ref)) do
          process(module_body, lenv)
        end
      end

      return [Node.new(:nil), lenv]
    end

    def handle_sclass(ast, lenv)
      self_name = ast.children[0]
      sklass_body = ast.children[1]
      with_new_nesting(current_nesting.increase_nesting_self) do
        process(sklass_body, lenv)
      end
    end

    def handle_defs(ast, lenv)
      method_receiver = ast.children[0]
      method_name = ast.children[1]
      formal_arguments = ast.children[2]
      method_body = ast.children[3]

      formal_arguments_hash, formal_arguments_nodes = build_arguments(formal_arguments, lenv)

      @currently_parsed_method_result_node = add_vertex(Node.new(:method_result))
      if method_body
        with_selfie(Selfie.klass_from_scope(current_scope)) do
          final_node, _result_lenv = process(method_body, lenv.merge(formal_arguments_hash))
          @graph.add_edge(final_node, @currently_parsed_method_result_node)
        end
      else
        final_node = add_vertex(Node.new(:nil))
        @graph.add_edge(final_node, @currently_parsed_method_result_node)
      end

      @tree.add_method(
        name: method_name.to_s,
        line: ast.loc.line,
        visibility: @currently_analyzed_klass.method_visibility,
        node_result: @currently_parsed_method_result_node,
        node_formal_arguments: formal_arguments_nodes,
        scope: current_scope.increase_by_metaklass)

      node = add_vertex(Node.new(:sym, { value: method_name }))

      return [node, lenv]
    end

    def handle_casgn(ast, lenv)
      const_prename, const_name, expr = ast.children
      const_name_ref = ConstRef.from_full_name(AstUtils.const_prename_and_name_to_string(const_prename, const_name))

      if expr_is_class_definition?(expr)
        parent_klass_name_ast = expr.children[2]
        @tree.add_klass(
          name: const_name_ref.name,
          scope: current_scope.increase_by_ref(const_name_ref).decrease,
          inheritance_name: parent_klass_name_ast.nil? ? nil : AstUtils.const_to_string(parent_klass_name_ast),
          inheritance_nesting: current_nesting.to_primitive,
          line: ast.loc.line)

        return [Node.new(:nil), lenv]
      elsif expr_is_module_definition?(expr)
        @tree.add_mod(
          name: const_name_ref.name,
          scope: current_scope.increase_by_ref(const_name_ref).decrease,
          line: ast.loc.line)

        return [Node.new(:nil), lenv]
      else
        @tree.add_constant(
          name: const_name_ref.name,
          scope: current_scope.increase_by_ref(const_name_ref).decrease,
          line: ast.loc.line)

        return [Node.new(:nil), lenv]
      end
    end

    def handle_const(ast, lenv)
      const_ref = ConstRef.from_ast(ast)

      node = add_vertex(Node.new(:const, { const_ref: const_ref }))

      return [node, lenv]
    end

    def handle_and(ast, lenv)
      handle_binary_operator(:and, ast.children[0], ast.children[1], lenv)
    end

    def handle_or(ast, lenv)
      handle_binary_operator(:or, ast.children[0], ast.children[1], lenv)
    end

    def handle_binary_operator(node_type, expr_left, expr_right, lenv)
      node_left, lenv_after_left = process(expr_left, lenv)
      node_right, lenv_after_right = process(expr_right, lenv_after_left)

      node_or = add_vertex(Node.new(node_type))
      @graph.add_edge(node_left, node_or)
      @graph.add_edge(node_right, node_or)

      return [node_or, lenv_after_right]
    end

    def handle_if(ast, lenv)
      expr_cond = ast.children[0]
      expr_iftrue = ast.children[1]
      expr_iffalse = ast.children[2]

      node_cond, lenv_after_cond = process(expr_cond, lenv)

      if expr_iftrue
        node_iftrue, lenv_after_iftrue = process(expr_iftrue, lenv_after_cond)
      else
        node_iftrue = add_vertex(Node.new(:nil))
        lenv_after_iftrue = lenv
      end

      if expr_iffalse
        node_iffalse, lenv_after_iffalse = process(expr_iffalse, lenv_after_cond)
      else
        node_iffalse = add_vertex(Node.new(:nil))
        lenv_after_iffalse = lenv
      end

      node_if_result = add_vertex(Node.new(:if_result))
      @graph.add_edge(node_iftrue, node_if_result)
      @graph.add_edge(node_iffalse, node_if_result)

      return [node_if_result, merge_lenvs(lenv_after_iftrue, lenv_after_iffalse)]
    end

    def handle_return(ast, lenv)
      expr = ast.children[0]

      if expr.nil?
        node_expr = add_vertex(Node.new(:nil))
        final_lenv = lenv
      else
        node_expr, final_lenv = process(expr, lenv)
      end
      @graph.add_edge(node_expr, @currently_parsed_method_result_node)

      return [node_expr, final_lenv]
    end

    def handle_masgn(ast, lenv)
      mlhs_expr = ast.children[0]
      rhs_expr = ast.children[1]

      node_mlhs, lenv_after_lhs = process(mlhs_expr, lenv)
      node_rhs, lenv_after_rhs = process(rhs_expr, lenv_after_lhs)

      @graph.add_edge(node_rhs, node_mlhs)

      return [node_rhs, lenv_after_rhs]
    end

    def handle_mlhs(ast, lenv)
      node_mlhs = add_vertex(Node.new(:mlhs))

      final_lenv = ast.children.reduce(lenv) do |current_lenv, ast_child|
        ast_child_node, new_lenv = process(ast_child, current_lenv)
        @graph.add_edge(node_mlhs, ast_child_node)
        new_lenv
      end

      return [node_mlhs, final_lenv]
    end

    def handle_alias(ast, lenv)
      node = add_vertex(Node.new(:nil))
      return [node, lenv]
    end

    def handle_super(ast, lenv)
      arg_exprs = ast.children

      call_arg_nodes = []
      final_lenv = arg_exprs.reduce(lenv) do |current_lenv, ast_child|
        ast_child_node, new_lenv = process(ast_child, current_lenv)
        call_arg_node = add_vertex(Node.new(:call_arg))
        call_arg_nodes << call_arg_node
        @graph.add_edge(ast_child_node, call_arg_node)
        new_lenv
      end

      call_result_node = add_vertex(Node.new(:call_result))

      super_send = SuperSend.new(call_arg_nodes, call_result_node, nil)
      @message_sends << super_send

      return [call_result_node, final_lenv, { message_send: super_send }]
    end

    def handle_zsuper(ast, lenv)
      call_result_node = add_vertex(Node.new(:call_result))

      zsuper_send = Super0Send.new(call_result_node, nil)
      @message_sends << zsuper_send

      return [call_result_node, lenv, { message_send: zsuper_send }]
    end

    def handle_while(ast, lenv)
      expr_cond = ast.children[0]
      expr_body = ast.children[1]

      node_cond, new_lenv = process(expr_cond, lenv)
      node_body, final_lenv = process(expr_body, new_lenv)

      node = add_vertex(Node.new(:nil))

      return [node, final_lenv]
    end

    def handle_case(ast, lenv)
      expr_cond = ast.children[0]
      expr_branches = ast.children[1..-1].compact

      node_cond, new_lenv = process(expr_cond, lenv)

      node_case_result = add_vertex(Node.new(:case_result))
      final_lenv = expr_branches.reduce(new_lenv) do |current_lenv, expr_when|
        node_when, next_lenv = process(expr_when, current_lenv)
        @graph.add_edge(node_when, node_case_result)
        next_lenv
      end

      return [node_case_result, final_lenv]
    end

    def handle_yield(ast, lenv)
      exprs = ast.children

      node_yield = add_vertex(Node.new(:yield))
      final_lenv = exprs.reduce(lenv) do |current_lenv, current_expr|
        current_node, next_lenv = process(current_expr, current_lenv)
        @graph.add_edge(current_node, node_yield)
        next_lenv
      end
      result_node = add_vertex(Node.new(:nil))

      return [result_node, final_lenv]
    end

    def handle_when(ast, lenv)
      expr_cond = ast.children[0]
      expr_body = ast.children[1]

      node_cond, lenv_after_cond = process(expr_cond, lenv)
      node_body, lenv_after_body = process(expr_body, lenv_after_cond)

      return [node_body, lenv_after_body]
    end

    def handle_break(ast, lenv)
      return [Node.new(:nil), lenv]
    end

    def handle_block_pass(ast, lenv)
      expr = ast.children[0]

      node_block_pass, next_lenv = process(expr, lenv)

      return [node_block_pass, next_lenv]
    end

    def handle_resbody(ast, lenv)
      error_array_expr = ast.children[0]
      assignment_expr = ast.children[1]
      rescue_body_expr = ast.children[2]

      lenv_after_errors = if error_array_expr
        node_error_array, lenv_after_errors = process(error_array_expr, lenv)
        unwrap_node = add_vertex(Node.new(:unwrap_array))
        @graph.add_edge(node_error_array, unwrap_node)
        lenv_after_errors
      else
        lenv
      end

      lenv_after_assignment = if assignment_expr
        node_assignment, lenv_after_assignment = process(assignment_expr, lenv_after_errors)
        @graph.add_edge(unwrap_node, node_assignment) if unwrap_node
        lenv_after_assignment
      else
        lenv
      end

      if rescue_body_expr
        node_rescue_body, final_lenv = process(rescue_body_expr, lenv_after_assignment)
      else
        node_rescue_body = add_vertex(Node.new(:nil))
        final_lenv = lenv
      end

      return [node_rescue_body, final_lenv]
    end

    def handle_rescue(ast, lenv)
      try_expr = ast.children[0]
      resbody = ast.children[1]
      elsebody = ast.children[2]

      node_try, lenv_after_try = if try_expr
        process(try_expr, lenv)
      else
        [add_vertex(Node.new(:nil)), lenv]
      end

      node_resbody, lenv_after_resbody = process(resbody, lenv_after_try)

      node = add_vertex(Node.new(:rescue))
      @graph.add_edge(node_resbody, node)

      if elsebody
        node_else, lenv_after_else = process(elsebody, lenv_after_try)
        @graph.add_edge(node_else, node)
        return [node, merge_lenvs(lenv_after_resbody, lenv_after_else)]
      else
        @graph.add_edge(node_try, node)
        return [node, lenv_after_resbody]
      end
    end

    def handle_retry(ast, lenv)
      return [add_vertex(Node.new(:nil)), lenv]
    end

    def handle_ensure(ast, lenv)
      expr_pre = ast.children[0]
      expr_ensure_body = ast.children[1]

      node_ensure = add_vertex(Node.new(:ensure))

      node_pre, lenv_after_pre = process(expr_pre, lenv)
      @graph.add_edge(node_pre, node_ensure) if node_pre

      node_ensure_body, lenv_after_ensure_body = process(expr_ensure_body, lenv_after_pre)
      @graph.add_edge(node_ensure_body, node_ensure) if node_ensure_body

      return [node_ensure, lenv_after_ensure_body]
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

    def switch_currently_analyzed_klass(klass)
      previous = @currently_analyzed_klass
      @currently_analyzed_klass = CurrentlyAnalyzedKlass.new(klass, :public)
      yield
      @currently_analyzed_klass = previous
    end

    def get_ivar_definition_node(ivar_name)
      klass = @tree.constants.find do |c|
        c.full_name == current_scope.absolute_str
      end

      raise if klass.nil?

      if !klass.nodes.instance_variables[ivar_name]
        klass.nodes.instance_variables[ivar_name] = add_vertex(Node.new(:ivar_definition))
      end

      return klass.nodes.instance_variables[ivar_name]
    end

    def get_class_level_ivar_definition_node(ivar_name)
      klass = @tree.constants.find do |c|
        c.full_name == current_scope.absolute_str
      end

      raise if klass.nil?

      if !klass.nodes.class_level_instance_variables[ivar_name]
        klass.nodes.class_level_instance_variables[ivar_name] = add_vertex(Node.new(:ivar_definition))
      end

      return klass.nodes.class_level_instance_variables[ivar_name]
    end

    def get_cvar_definition_node(cvar_name)
      klass = @tree.constants.find do |c|
        c.full_name == current_scope.absolute_str
      end

      raise if klass.nil?

      if !klass.nodes.class_variables[cvar_name]
        klass.nodes.class_variables[cvar_name] = add_vertex(Node.new(:cvar_definition))
      end

      return klass.nodes.class_variables[cvar_name]
    end

    def get_gvar_definition_node(gvar_name)
      if !@tree.nodes.global_variables[gvar_name]
        @tree.nodes.global_variables[gvar_name] = add_vertex(Node.new(:gvar_definition))
      end

      return @tree.nodes.global_variables[gvar_name]
    end

    def build_arguments(formal_arguments, lenv)
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
          node_arg_default, _lenv = process(maybe_arg_default_expr, lenv)
          @graph.add_edge(node_arg_default, arg_node)
        end

        formal_arguments_nodes << arg_node
        add_vertex(arg_node)
        h[arg_name] = [arg_node]
      end
      return [formal_arguments_hash, formal_arguments_nodes]
    end

    def with_new_nesting(new_nesting)
      previous = @current_nesting
      @current_nesting = new_nesting
      yield
      @current_nesting = previous
    end

    def with_selfie(new_selfie)
      previous = @current_selfie
      @current_selfie = new_selfie
      yield
      @current_selfie = previous
    end

    def current_scope
      current_nesting.to_scope
    end

    def merge_lenvs(lenv1, lenv2)
      final_lenv = {}

      var_names = (lenv1.keys + lenv2.keys).uniq
      var_names.each do |var_name|
        final_lenv[var_name] = lenv1.fetch(var_name, []) + lenv2.fetch(var_name, [])
      end

      final_lenv
    end

    def add_vertex(node)
      @graph.add_vertex(node)
      node
    end
  end
end
