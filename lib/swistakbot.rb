require 'parser/current'

class Swistakbot
  Result = Struct.new(:klass, :method)

  def initialize
  end

  def parse_file_methods(string)
    ast = Parser::CurrentRuby.parse(string)
    raise "Should be a class" if ast.type != :class
    klass_name = ast.children.first.children[1].to_s
    method_name = ast.children.last.children.first.to_s
    return [
      Result.new(klass_name, method_name)
    ]
  end
end
