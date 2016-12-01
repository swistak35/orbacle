require 'parser/current'

class ParseFileMethods
  class Result < Struct.new(:list)
    Mod = Struct.new(:name)
    Klass = Struct.new(:name)
    Method = Struct.new(:name)

    def unshift(e)
      list.unshift(e)
      self
    end
  end

  def call(file)
    ast = Parser::CurrentRuby.parse(file)

    if ast.type == :module
      module_name = ast.children.first.children.last.to_s
      klass_ast = ast.children.last
      parse_klass(klass_ast, module_name).map do |result|
        result.unshift(Result::Mod.new(module_name))
      end
    else
      module_name = nil
      parse_klass(ast, module_name)
    end
  end

  private

  def parse_klass(ast, module_name)
    raise "Should be a class" if ast.type != :class
    methods_block = ast.children.last
    klass_name = ast.children.first.children[1].to_s
    if methods_block.type == :begin
      return methods_block.children.map {|m| parse_method(klass_name, m) }
    elsif methods_block.type == :def
      return [ parse_method(klass_name, methods_block) ]
    else
      raise "Not implemented yet"
    end
  end

  def parse_method(klass_name, m)
    method_name = m.children.first.to_s
    Result.new([ Result::Klass.new(klass_name), Result::Method.new(method_name) ])
  end
end

class Swistakbot
end
