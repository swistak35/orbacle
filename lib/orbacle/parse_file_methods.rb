require 'parser/current'
require 'orbacle/nesting_container'

module Orbacle
  class ParseFileMethods < Parser::AST::Processor
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

      attr_reader :scope, :name, :type, :inheritance, :nesting

      def ==(other)
        @scope == other.scope &&
          @name == other.name &&
          @type == other.type &&
          @inheritance == other.inheritance &&
          @nesting == other.nesting
      end
    end

    def process_file(file)
      ast = Parser::CurrentRuby.parse(file)

      reset_file!

      process(ast)

      {
        methods: @methods,
        constants: @constants,
        klasslikes: @klasslikes,
      }
    end

    def on_module(ast)
      module_name_ast, _ = ast.children
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

      super(ast)

      @current_nesting.decrease_nesting
    end

    def on_class(ast)
      klass_name_ast, parent_klass_name_ast, _ = ast.children
      klass_name_ref = ConstRef.from_ast(klass_name_ast)

      @constants << [
        Skope.from_nesting(@current_nesting).increase_by_ref(klass_name_ref).prefix.absolute_str,
        klass_name_ref.name,
        :klass,
        { line: klass_name_ast.loc.line },
      ]

      @klasslikes << Klasslike.build_klass(
        scope: Skope.from_nesting(@current_nesting).increase_by_ref(klass_name_ref).prefix.absolute_str,
        name: klass_name_ref.name,
        inheritance: parent_klass_name_ast.nil? ? nil : AstUtils.const_to_string(parent_klass_name_ast),
        nesting: @current_nesting.get_output_nesting)

      @current_nesting.increase_nesting_const(klass_name_ref)

      super(ast)

      @current_nesting.decrease_nesting
    end

    def on_sclass(ast)
      @current_nesting.increase_nesting_self

      super(ast)

      @current_nesting.decrease_nesting
    end

    def on_def(ast)
      method_name, _ = ast.children

      @methods << [
        Skope.from_nesting(@current_nesting).absolute_str,
        method_name.to_s,
        { line: ast.loc.line, target: @current_nesting.is_selfed? ? :self : :instance }
      ]
    end

    def on_defs(ast)
      method_receiver, method_name, _ = ast.children

      @methods << [
        Skope.from_nesting(@current_nesting).absolute_str,
        method_name.to_s,
        { line: ast.loc.line, target: :self },
      ]
    end

    def on_casgn(ast)
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

    private

    def reset_file!
      @current_nesting = NestingContainer.new
      @methods = []
      @constants = []
      @klasslikes = []
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
  end
end
