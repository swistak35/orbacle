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
    pre_nesting, nesting_name = get_nesting(ast.children[0])
    current_nesting_element = [:mod, pre_nesting, nesting_name]
    new_nesting = old_nesting + [current_nesting_element]
    child_result = parse(ast.children[1], new_nesting)
    {
      methods: child_result[:methods].map do |method_parent, method_name|
        build_method_result(current_nesting_element, method_parent, method_name)
      end,
      constants: child_result[:constants].map do |parent, name, type|
        build_constant_result(current_nesting_element, parent, name, type)
      end + [ [pre_nesting.empty? ? nil : pre_nesting.join("::"), nesting_name, :mod] ]
    }
  end

  def parse_klass(ast, old_nesting)
    pre_nesting, nesting_name = get_nesting(ast.children[0])
    current_nesting_element = [:klass, pre_nesting, nesting_name]
    new_nesting = old_nesting + [current_nesting_element]
    child_result = parse(ast.children[2], new_nesting)
    {
      methods: child_result[:methods].map do |method_parent, method_name|
        build_method_result(current_nesting_element, method_parent, method_name)
      end,
      constants: child_result[:constants].map do |parent, name, type|
        build_constant_result(current_nesting_element, parent, name, type)
      end + [ [pre_nesting.empty? ? nil : pre_nesting.join("::"), nesting_name, :klass] ]
    }
  end

  def parse_def(m, _nesting)
    method_name = m.children[0].to_s
    {
      methods: [[nil, method_name]],
      constants: [],
    }
  end

  def parse_begin(ast, nesting)
    results = ast.children.map {|c| parse(c, nesting) }
    {
      methods: results.flat_map {|r| r[:methods] },
      constants: results.flat_map {|r| r[:constants] },
    }
  end

  def build_method_result(current_nesting_element, method_parent, method_name)
    _, pre_nesting, nesting_name = current_nesting_element
    new_parent = (pre_nesting + [nesting_name, method_parent]).compact.join("::")
    [new_parent, method_name]
  end

  def build_constant_result(current_nesting_element, parent, name, type)
    _, pre_nesting, nesting_name = current_nesting_element
    new_parent = (pre_nesting + [nesting_name, parent]).compact.join("::")
    [new_parent, name, type]
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
