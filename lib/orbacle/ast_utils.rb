module Orbacle
  module AstUtils
    def self.const_to_string(const_ast)
      get_nesting(const_ast).flatten.join("::")
    end

    def self.const_prename_and_name_to_string(prename_ast, name_ast)
      (prename(prename_ast) + [name_ast.to_s]).compact.join("::")
    end

    def self.get_nesting(ast_const)
      [prename(ast_const.children[0]), ast_const.children[1].to_s]
    end

    def self.prename(ast_const)
      if ast_const.nil?
        []
      else
        prename(ast_const.children[0]) + [ast_const.children[1].to_s]
      end
    end

    def build_position_range_from_ast(ast)
      PositionRange.new(
        Position.new(ast.loc.expression.begin.line - 1, ast.loc.expression.begin.column),
        Position.new(ast.loc.expression.end.line - 1, ast.loc.expression.end.column - 1))
    end
  end
end
