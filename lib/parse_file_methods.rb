require 'parser/current'

class ParseFileMethods
  def call(file)
    ast = Parser::CurrentRuby.parse(file)

    nesting = []
    parse(ast, nesting)
  end

  private

  def parse(ast, nesting)
    case ast.type
    when :module
      parse_module(ast, nesting)
    when :class
      parse_klass(ast, nesting)
    when :begin
      parse_begin(ast, nesting)
    when :def
      parse_def(ast, nesting)
    else raise
    end
  end

  def parse_module(ast, old_nesting)
    ast_const = ast.children.first
    pre_nesting, nesting_name = get_nesting(ast_const)
    current_nesting_element = [:mod, pre_nesting, nesting_name]
    new_nesting = old_nesting + [current_nesting_element]
    child = ast.children[1]
    parse(child, new_nesting).map do |method_parent, method_name|
      build_method_result(current_nesting_element, method_parent, method_name)
    end
  end

  def parse_klass(ast, old_nesting)
    ast_const = ast.children.first
    pre_nesting, nesting_name = get_nesting(ast_const)
    current_nesting_element = [:klass, pre_nesting, nesting_name]
    new_nesting = old_nesting + [current_nesting_element]
    child = ast.children.last
    parse(child, new_nesting).map do |method_parent, method_name|
      build_method_result(current_nesting_element, method_parent, method_name)
    end
  end

  def parse_def(m, _nesting)
    method_name = m.children.first.to_s
    [[nil, method_name]]
  end

  def parse_begin(ast, nesting)
    ast.children.flat_map do |c|
      parse(c, nesting)
    end
  end

  def build_method_result(current_nesting_element, method_parent, method_name)
    _, pre_nesting, nesting_name = current_nesting_element
    new_parent = (pre_nesting + [nesting_name, method_parent]).compact.join("::")
    [new_parent, method_name]
  end

  def pre_nesting(ast_const)
    if ast_const.nil?
      []
    else
      pre_nesting(ast_const.children[0]) + [ast_const.children[1].to_s]
    end
  end

  def get_nesting(ast_const)
    [pre_nesting(ast_const.children[0]), ast_const.children[1].to_s]
  end
end
