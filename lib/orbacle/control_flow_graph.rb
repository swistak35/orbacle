require 'rgl/adjacency'
require 'parser/current'
require 'orbacle/nesting'

module Orbacle
  class ControlFlowGraph
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
    Block = Struct.new(:args, :result)
    CurrentlyAnalyzedKlass = Struct.new(:klass, :method_visibility)

    Result = Struct.new(:graph, :final_lenv, :message_sends, :final_node, :methods, :constants, :tree)

    def process_file(file)
      ast = Parser::CurrentRuby.parse(file)

      @graph = RGL::DirectedAdjacencyGraph.new
      @message_sends = []
      @current_nesting = Nesting.new
      @constants = []
      @tree = GlobalTree.new
      @currently_analyzed_klass = CurrentlyAnalyzedKlass.new(nil, :public)

      initial_local_environment = {}
      final_node, final_local_environment = process(ast, initial_local_environment)

      methods = @tree.methods.map do |m|
        [m.scope.to_s, m.name, { line: m.line }, m.node_formal_arguments, m.node_result]
      end

      constants = @tree.constants.map do |c|
        case c
        when GlobalTree::Klass
          [c.scope, c.name, :klass, { line: c.line }]
        when GlobalTree::Mod
          [c.scope, c.name, :mod, { line: c.line }]
        when GlobalTree::Constant
          [c.scope, c.name, :other, { line: c.line }]
        end
      end

      return Result.new(@graph, final_local_environment, @message_sends, final_node, methods, @tree.constants, @tree)
    end

    private

    def process(ast, lenv)
      case ast.type
      when :lvasgn
        handle_lvasgn(ast, lenv)
      when :int
        handle_int(ast, lenv)
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
      when :begin
        handle_begin(ast, lenv)
      when :lvar
        handle_lvar(ast, lenv)
      when :ivar
        handle_ivar(ast, lenv)
      when :send
        handle_send(ast, lenv)
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
      else
        raise ArgumentError.new(ast)
      end
    end

    def handle_lvasgn(ast, lenv)
      var_name = ast.children[0].to_s
      expr = ast.children[1]

      n1 = Node.new(:lvasgn, { var_name: var_name })
      @graph.add_vertex(n1)

      n2, n2_lenv = process(expr, lenv)

      @graph.add_edge(n2, n1)

      new_lenv = n2_lenv.merge(var_name => n2)

      return [n1, new_lenv]
    end

    def handle_int(ast, lenv)
      value = ast.children[0]
      n = Node.new(:int, { value: value })
      @graph.add_vertex(n)

      return [n, lenv]
    end

    def handle_true(ast, lenv)
      n = Node.new(:bool, { value: true })
      @graph.add_vertex(n)

      return [n, lenv]
    end

    def handle_false(ast, lenv)
      n = Node.new(:bool, { value: false })
      @graph.add_vertex(n)

      return [n, lenv]
    end

    def handle_nil(ast, lenv)
      n = Node.new(:nil)
      @graph.add_vertex(n)

      return [n, lenv]
    end

    def handle_str(ast, lenv)
      value = ast.children[0]
      n = Node.new(:str, { value: value })
      @graph.add_vertex(n)

      return [n, lenv]
    end

    def handle_dstr(ast, lenv)
      node_dstr = Node.new(:dstr)
      @graph.add_vertex(node_dstr)

      final_lenv = ast.children.reduce(lenv) do |current_lenv, ast_child|
        ast_child_node, new_lenv = process(ast_child, current_lenv)
        @graph.add_edge(ast_child_node, node_dstr)
        new_lenv
      end

      return [node_dstr, final_lenv]
    end

    def handle_sym(ast, lenv)
      value = ast.children[0]
      n = Node.new(:sym, { value: value })
      @graph.add_vertex(n)

      return [n, lenv]
    end

    def handle_dsym(ast, lenv)
      node_dsym = Node.new(:dsym)
      @graph.add_vertex(node_dsym)

      final_lenv = ast.children.reduce(lenv) do |current_lenv, ast_child|
        ast_child_node, new_lenv = process(ast_child, current_lenv)
        @graph.add_edge(ast_child_node, node_dsym)
        new_lenv
      end

      return [node_dsym, final_lenv]
    end

    def handle_array(ast, lenv)
      node_array = Node.new(:array)
      @graph.add_vertex(node_array)

      final_lenv = ast.children.reduce(lenv) do |current_lenv, ast_child|
        ast_child_node, new_lenv = process(ast_child, current_lenv)
        @graph.add_edge(ast_child_node, node_array)
        new_lenv
      end

      return [node_array, final_lenv]
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

    def handle_begin(ast, lenv)
      final_node, final_lenv = ast.children.reduce([nil, lenv]) do |(current_node, current_lenv), ast_child|
        process(ast_child, current_lenv)
      end
      return [final_node, final_lenv]
    end

    def handle_lvar(ast, lenv)
      var_name = ast.children[0].to_s

      node_lvar = Node.new(:lvar, { var_name: var_name })
      @graph.add_vertex(node_lvar)

      var_definition_node = lenv.fetch(var_name)
      @graph.add_edge(var_definition_node, node_lvar)

      return [node_lvar, lenv]
    end

    def handle_ivar(ast, lenv)
      ivar_name = ast.children.first.to_s

      # Probably there is some good relation between self

      # It should also not be constants, but some kind of klasslikes
      klass = @tree.constants.find do |c|
        c.name == Scope.from_nesting(@current_nesting).absolute_str
      end

      if !klass.nodes.instance_variables[ivar_name]
        klass.nodes.instance_variables[ivar_name] = Node.new(:ivar_definition)
        @graph.add_vertex(klass.nodes.instance_variables[ivar_name])
      end

      node = Node.new(:ivar)

      @graph.add_edge(klass.nodes.instance_variables[ivar_name], node)

      return [node, lenv]
    end

    def handle_send(ast, lenv)
      obj_expr = ast.children[0]
      message_name = ast.children[1].to_s
      arg_exprs = ast.children[2..-1]

      return handle_send_private(lenv) if obj_expr.nil? && message_name == "private"
      return handle_send_public(lenv) if obj_expr.nil? && message_name == "public"
      return handle_send_protected(lenv) if obj_expr.nil? && message_name == "protected"

      if obj_expr.nil?
        obj_node = lenv.fetch(:self_)
        obj_lenv = lenv
      else
        obj_node, obj_lenv = process(obj_expr, lenv)
      end

      call_arg_nodes = []
      final_lenv = arg_exprs.reduce(obj_lenv) do |current_lenv, ast_child|
        ast_child_node, new_lenv = process(ast_child, current_lenv)
        call_arg_node = Node.new(:call_arg)
        call_arg_nodes << call_arg_node
        @graph.add_vertex(call_arg_node)
        @graph.add_edge(ast_child_node, call_arg_node)
        new_lenv
      end

      call_obj_node = Node.new(:call_obj)
      @graph.add_vertex(call_obj_node)
      @graph.add_edge(obj_node, call_obj_node)

      call_result_node = Node.new(:call_result)
      @graph.add_vertex(call_result_node)

      message_send = MessageSend.new(message_name, call_obj_node, call_arg_nodes, call_result_node, nil)
      @message_sends << message_send

      return [call_result_node, final_lenv, { message_send: message_send }]
    end

    def handle_send_private(lenv)
      handle_changing_visibility(lenv, :private)
    end

    def handle_send_public(lenv)
      handle_changing_visibility(lenv, :public)
    end

    def handle_send_protected(lenv)
      handle_changing_visibility(lenv, :protected)
    end

    def handle_changing_visibility(lenv, new_visibility)
      node = if @currently_analyzed_klass.klass
        @currently_analyzed_klass.method_visibility = new_visibility

        Node.new(:class, { klass: @currently_analyzed_klass.klass })
      else
        # This should actually be reference to Object class
        Node.new(:nil)
      end
      @graph.add_vertex(node)

      return [node, lenv]
    end

    def handle_self(ast, lenv)
      node = lenv.fetch(:self_)
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
        arg_node = Node.new(:block_arg, { var_name: arg_name })
        @graph.add_vertex(arg_node)
        args_ast_nodes << arg_node
        current_lenv.merge(arg_name => arg_node)
      end

      # It's not exactly good - local vars defined in blocks are not available outside (?),
      #     but assignments done in blocks are valid.
      block_final_node, block_result_lenv = process(block_expr, lenv_with_args)
      block_result_node = Node.new(:block_result)
      @graph.add_vertex(block_result_node)
      @graph.add_edge(block_final_node, block_result_node)
      block = Block.new(args_ast_nodes, block_result_node)
      message_send.block = block

      return [send_node, block_result_lenv]
    end

    def handle_def(ast, lenv)
      method_name = ast.children[0]
      formal_arguments = ast.children[1]
      method_body = ast.children[2]

      formal_argument_nodes = []
      formal_arguments_hash = formal_arguments.children.each_with_object({}) do |arg_ast, h|
        arg_name = arg_ast.children[0].to_s
        if arg_ast.type == :arg
          arg_node = Node.new(:formal_arg, { var_name: arg_name })
        elsif arg_ast.type == :restarg
          arg_node = Node.new(:formal_restarg, { var_name: arg_name })
        else raise
        end

        formal_argument_nodes << arg_node
        @graph.add_vertex(arg_node)
        h[arg_name] = arg_node
      end

      new_selfie = Selfie.instance_from_scope(Scope.from_nesting(@current_nesting))
      self_node = Node.new(:self, { selfie: new_selfie })
      @graph.add_vertex(self_node)

      @currently_parsed_method_result_node = Node.new(:method_result)
      @graph.add_vertex(@currently_parsed_method_result_node)
      if method_body
        final_node, _result_lenv = process(method_body, lenv.merge(formal_arguments_hash).merge(self_: self_node))
        @graph.add_edge(final_node, @currently_parsed_method_result_node)
      else
        final_node = Node.new(:nil)
        @graph.add_vertex(final_node)
        @graph.add_edge(final_node, @currently_parsed_method_result_node)
      end

      @tree.add_method(
        name: method_name.to_s,
        line: ast.loc.line,
        visibility: @currently_analyzed_klass.method_visibility,
        node_result: @currently_parsed_method_result_node,
        node_formal_arguments: formal_argument_nodes,
        scope: Scope.from_nesting(@current_nesting))

      node = Node.new(:sym, { value: method_name })
      @graph.add_vertex(node)

      return [node, lenv]
    end

    def handle_hash(ast, lenv)
      node_hash_keys = Node.new(:hash_keys)
      node_hash_values = Node.new(:hash_values)
      node_hash = Node.new(:hash)
      @graph.add_vertex(node_hash)
      @graph.add_vertex(node_hash_keys)
      @graph.add_vertex(node_hash_values)
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
        scope: Scope.from_nesting(@current_nesting).increase_by_ref(klass_name_ref).decrease.absolute_str,
        inheritance_name: parent_klass_name_ast.nil? ? nil : AstUtils.const_to_string(parent_klass_name_ast),
        inheritance_nesting: @current_nesting.get_output_nesting,
        line: klass_name_ast.loc.line)

      switch_currently_analyzed_klass(klass) do
        @current_nesting.increase_nesting_const(klass_name_ref)

        new_selfie = Selfie.klass_from_scope(Scope.from_nesting(@current_nesting))
        self_node = Node.new(:self, { selfie: new_selfie })
        @graph.add_vertex(self_node)

        if klass_body
          process(klass_body, lenv.merge(self_: self_node))
        end

        @current_nesting.decrease_nesting
      end

      node = Node.new(:nil)
      @graph.add_vertex(node)

      return [node, lenv]
    end

    def handle_module(ast, lenv)
      module_name_ast, module_body = ast.children
      module_name_ref = ConstRef.from_ast(module_name_ast)

      @tree.add_mod(
        name: module_name_ref.name,
        scope: Scope.from_nesting(@current_nesting).increase_by_ref(module_name_ref).decrease.absolute_str,
        line: module_name_ast.loc.line)

      @current_nesting.increase_nesting_const(module_name_ref)

      process(module_body, lenv)

      @current_nesting.decrease_nesting
    end

    def handle_sclass(ast, lenv)
      self_name = ast.children[0]
      sklass_body = ast.children[1]
      @current_nesting.increase_nesting_self

      process(sklass_body, lenv)

      @current_nesting.decrease_nesting
    end

    def handle_defs(ast, lenv)
      method_receiver, method_name, method_body = ast.children

      @tree.add_method(
        name: method_name.to_s,
        line: ast.loc.line,
        visibility: :public,
        node_result: nil, #todo
        node_formal_arguments: [], #todo
        scope: Scope.from_nesting(@current_nesting).increase_by_metaklass)

      @current_nesting.increase_nesting_self

      @current_nesting.decrease_nesting
    end

    def handle_casgn(ast, lenv)
      const_prename, const_name, expr = ast.children
      const_name_ref = ConstRef.from_full_name(AstUtils.const_prename_and_name_to_string(const_prename, const_name))

      if expr_is_class_definition?(expr)
        parent_klass_name_ast = expr.children[2]
        @tree.add_klass(
          name: const_name_ref.name,
          scope: Scope.from_nesting(@current_nesting).increase_by_ref(const_name_ref).decrease.absolute_str,
          inheritance_name: parent_klass_name_ast.nil? ? nil : AstUtils.const_to_string(parent_klass_name_ast),
          inheritance_nesting: @current_nesting.get_output_nesting,
          line: ast.loc.line)
      elsif expr_is_module_definition?(expr)
        @tree.add_mod(
          name: const_name_ref.name,
          scope: Scope.from_nesting(@current_nesting).increase_by_ref(const_name_ref).decrease.absolute_str,
          line: ast.loc.line)
      else
        @tree.add_constant(
          name: const_name_ref.name,
          scope: Scope.from_nesting(@current_nesting).increase_by_ref(const_name_ref).decrease.absolute_str,
          line: ast.loc.line)
      end
    end

    def handle_const(ast, lenv)
      const_ref = ConstRef.from_ast(ast)

      node = Node.new(:const, { const_ref: const_ref })
      @graph.add_vertex(node)

      return [node, lenv]
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
  end
end
