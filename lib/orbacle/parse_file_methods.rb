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
          inheritance: nil)
      end

      def self.build_klass(scope:, name:, inheritance:)
        new(
          scope: scope,
          name: name,
          type: :klass,
          inheritance: inheritance)
      end

      def initialize(scope:, name:, type:, inheritance:)
        @scope = scope
        @name = name
        @type = type
        @inheritance = inheritance
      end

      attr_reader :scope, :name, :type, :inheritance

      def ==(other)
        @scope == other.scope &&
          @name == other.name &&
          @type == other.type &&
          @inheritance == other.inheritance
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
      ast_name, _ = ast.children
      prename, module_name = @current_nesting.get_nesting(ast_name)

      @constants << [
        scope_from_nesting_and_prename(@current_nesting.get_current_nesting, prename),
        module_name,
        :mod,
        { line: ast_name.loc.line },
      ]

      @klasslikes << Klasslike.build_module(
        scope: scope_from_nesting_and_prename(@current_nesting.get_current_nesting, prename),
        name: module_name)

      @current_nesting.increase_nesting_mod(ast_name)

      super(ast)

      @current_nesting.decrease_nesting
    end

    def on_class(ast)
      ast_name, parent_klass_name_ast, _ = ast.children
      prename, klass_name = @current_nesting.get_nesting(ast_name)

      @constants << [
        scope_from_nesting_and_prename(@current_nesting.get_current_nesting, prename),
        klass_name,
        :klass,
        { line: ast_name.loc.line },
      ]

      @klasslikes << Klasslike.build_klass(
        scope: scope_from_nesting_and_prename(@current_nesting.get_current_nesting, prename),
        name: klass_name,
        inheritance: parent_klass_name_ast.nil? ? nil : @current_nesting.get_nesting(parent_klass_name_ast).flatten.join("::"))

      @current_nesting.increase_nesting_class(ast_name)

      super(ast)

      @current_nesting.decrease_nesting
    end

    def on_def(ast)
      method_name, _ = ast.children

      @methods << [
        nesting_to_scope(@current_nesting.get_current_nesting),
        method_name.to_s,
        { line: ast.loc.line }
      ]
    end

    def on_casgn(ast)
      const_prename, const_name, _ = ast.children

      @constants << [
        scope_from_nesting_and_prename(@current_nesting.get_current_nesting, @current_nesting.prename(const_prename)),
        const_name.to_s,
        :other,
        { line: ast.loc.line }
      ]
    end

    private

    def reset_file!
      @current_nesting = NestingContainer.new
      @methods = []
      @constants = []
      @klasslikes = []
    end

    def nesting_to_scope(nesting)
      return nil if nesting.empty?

      nesting.map do |_type, pre, name|
        pre + [name]
      end.join("::")
    end

    def scope_from_nesting_and_prename(nesting, prename)
      scope_from_nesting = nesting_to_scope(nesting)

      if prename.at(0).eql?("")
        result = prename.drop(1).join("::")
      else
        result = ([scope_from_nesting] + prename).compact.join("::")
      end
      result if !result.empty?
    end
  end
end
