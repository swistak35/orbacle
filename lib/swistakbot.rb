require 'parser/current'

class ParseFileMethods
  Result = Struct.new(:klass, :method)

  def call(file)
    ast = Parser::CurrentRuby.parse(file)
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

  private

  def parse_method(klass_name, m)
    method_name = m.children.first.to_s
    Result.new(klass_name, method_name)
  end
end

class Swistakbot
end
