module Orbacle
  module AstUtils
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
  end
end
