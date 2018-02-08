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

    class Klasslike
      def self.build_module(scope:, name:)
        new(
          scope: scope,
          name: name,
          type: :module,
          inheritance: nil,
          nesting: nil)
      end

      def self.build_klass(scope:, name:, inheritance:, nesting:)
        new(
          scope: scope,
          name: name,
          type: :klass,
          inheritance: inheritance,
          nesting: nesting)
      end

      def initialize(scope:, name:, type:, inheritance:, nesting:)
        @scope = scope
        @name = name
        @type = type
        @inheritance = inheritance
        @nesting = nesting
      end

      attr_reader :scope, :name, :type, :inheritance, :nesting, :node

      def ==(other)
        @scope == other.scope &&
          @name == other.name &&
          @type == other.type &&
          @inheritance == other.inheritance &&
          @nesting == other.nesting
      end

      def set_node(node)
        @node = node
      end
    end

    Result = Struct.new(:graph, :final_lenv, :message_sends, :final_node, :methods, :constants, :klasslikes)

    def process_file(file)
      ast = Parser::CurrentRuby.parse(file)

      @graph = RGL::DirectedAdjacencyGraph.new
      @message_sends = []
      @current_nesting = Nesting.new
      @methods = []
      @constants = []
      @klasslikes = []

      initial_local_environment = {}
      final_node, final_local_environment = process(ast, initial_local_environment)

      return Result.new(@graph, final_local_environment, @message_sends, final_node, @methods, @constants, @klasslikes)
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
      when :sym
        handle_sym(ast, lenv)
      when :begin
        handle_begin(ast, lenv)
      when :lvar
        handle_lvar(ast, lenv)
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

    def handle_sym(ast, lenv)
      value = ast.children[0]
      n = Node.new(:sym, { value: value })
      @graph.add_vertex(n)

      return [n, lenv]
    end

    def handle_array(ast, lenv)
      node_array = Node.new(:array)
      @graph.add_vertex(node_array)

      exprs_nodes = []
      final_lenv = ast.children.reduce(lenv) do |current_lenv, ast_child|
        ast_child_node, new_lenv = process(ast_child, current_lenv)
        exprs_nodes << ast_child_node
        new_lenv
      end
      exprs_nodes.each do |node_expr|
        @graph.add_edge(node_expr, node_array)
      end

      return [node_array, final_lenv]
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

    def handle_send(ast, lenv)
      obj_expr = ast.children[0]
      message_name = ast.children[1]
      arg_exprs = ast.children[2..-1]

      return if obj_expr.nil? # Currently can happen, when calling method on something which is not yet known

      obj_node, obj_lenv = process(obj_expr, lenv)

      arg_nodes = []
      final_lenv = arg_exprs.reduce(obj_lenv) do |current_lenv, ast_child|
        ast_child_node, new_lenv = process(ast_child, current_lenv)
        arg_nodes << ast_child_node
        new_lenv
      end

      call_arg_nodes = []
      arg_nodes.each do |arg_node|
        call_arg_node = Node.new(:call_arg)
        call_arg_nodes << call_arg_node
        @graph.add_vertex(call_arg_node)
        @graph.add_edge(arg_node, call_arg_node)
      end

      call_obj_node = Node.new(:call_obj)
      @graph.add_vertex(call_obj_node)

      @graph.add_edge(obj_node, call_obj_node)

      call_result_node = Node.new(:call_result)
      @graph.add_vertex(call_result_node)

      message_send = MessageSend.new(message_name.to_s, call_obj_node, call_arg_nodes, call_result_node, nil)
      @message_sends << message_send

      return [call_result_node, obj_lenv, { message_send: message_send }]
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

      formal_arguments_hash = formal_arguments.children.each_with_object({}) do |arg_ast, h|
        arg_name = arg_ast.children[0].to_s
        arg_node = Node.new(:formal_arg, { var_name: arg_name })
        h[arg_name] = arg_node
      end

      @currently_parsed_method_result_node = Node.new(:method_result)
      @graph.add_vertex(@currently_parsed_method_result_node)
      if method_body
        final_node, _result_lenv = process(method_body, formal_arguments_hash)
        @graph.add_edge(final_node, @currently_parsed_method_result_node)
      end

      @methods << [
        Skope.from_nesting(@current_nesting).absolute_str,
        method_name.to_s,
        { line: ast.loc.line }
      ]
    end

    def handle_class(ast, lenv)
      klass_name_ast, parent_klass_name_ast, klass_body = ast.children
      klass_name_ref = ConstRef.from_ast(klass_name_ast)

      klasslike = Klasslike.build_klass(
        scope: Skope.from_nesting(@current_nesting).increase_by_ref(klass_name_ref).prefix.absolute_str,
        name: klass_name_ref.name,
        inheritance: parent_klass_name_ast.nil? ? nil : AstUtils.const_to_string(parent_klass_name_ast),
        nesting: @current_nesting.get_output_nesting)

      node = Node.new(:class, { klasslike: klasslike })
      @graph.add_vertex(node)
      klasslike.set_node(node)

      @constants << [
        Skope.from_nesting(@current_nesting).increase_by_ref(klass_name_ref).prefix.absolute_str,
        klass_name_ref.name,
        :klass,
        { line: klass_name_ast.loc.line },
      ]

      @klasslikes << klasslike

      @current_nesting.increase_nesting_const(klass_name_ref)

      if klass_body
        process(klass_body, lenv)
      end

      @current_nesting.decrease_nesting
    end

    def handle_module(ast, lenv)
      module_name_ast, module_body = ast.children
      module_name_ref = ConstRef.from_ast(module_name_ast)

      @constants << [
        Skope.from_nesting(@current_nesting).increase_by_ref(module_name_ref).prefix.absolute_str,
        module_name_ref.name,
        :mod,
        { line: module_name_ast.loc.line },
      ]

      @klasslikes << Klasslike.build_module(
        scope: Skope.from_nesting(@current_nesting).increase_by_ref(module_name_ref).prefix.absolute_str,
        name: module_name_ref.name)

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

      @current_nesting.increase_nesting_self

      @methods << [
        Skope.from_nesting(@current_nesting).absolute_str,
        method_name.to_s,
        { line: ast.loc.line },
      ]

      @current_nesting.decrease_nesting
    end

    def handle_casgn(ast, lenv)
      const_prename, const_name, expr = ast.children
      const_name_ref = ConstRef.new(AstUtils.const_prename_and_name_to_string(const_prename, const_name))

      @constants << [
        Skope.from_nesting(@current_nesting).increase_by_ref(const_name_ref).prefix.absolute_str,
        const_name_ref.name,
        :other,
        { line: ast.loc.line }
      ]

      if expr_is_class_definition?(expr)
        parent_klass_name_ast = expr.children[2]
        @klasslikes << Klasslike.build_klass(
          scope: Skope.from_nesting(@current_nesting).increase_by_ref(const_name_ref).prefix.absolute_str,
          name: const_name_ref.name,
          inheritance: parent_klass_name_ast.nil? ? nil : AstUtils.const_to_string(parent_klass_name_ast),
          nesting: @current_nesting.get_output_nesting)
      elsif expr_is_module_definition?(expr)
        @klasslikes << Klasslike.build_module(
          scope: Skope.from_nesting(@current_nesting).increase_by_ref(const_name_ref).prefix.absolute_str,
          name: const_name_ref.name)
      end
    end

    def handle_const(ast, lenv)
      const_ref = ConstRef.from_ast(ast)
      klasslike = search_for_klasslike(const_ref, @current_nesting)

      # Target implementation:
      # raise "Case not implemented yet" if klasslike.nil?
      # return [klasslike.node, lenv]

      return [klasslike.node, lenv] if klasslike
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

    def search_for_klasslike(const_ref, current_nesting)
      @klasslikes.find do |klasslike|
        klasslike.name == const_ref.full_name
      end
    end
  end
end
