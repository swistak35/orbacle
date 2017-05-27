require 'parser/current'

class ParseFileMethods < Parser::AST::Processor
  def initialize
  end

  def process_file(file)
    ast = Parser::CurrentRuby.parse(file)

    reset_file!

    process(ast)

    {
      methods: @methods,
      constants: @constants,
    }
  end

  def reset_file!
    @current_nesting = []
    @methods = []
    @constants = []
  end

  def on_module(ast)
    pre_nesting, nesting_name = get_nesting(ast.children[0])
    current_nesting_element = [:mod, pre_nesting, nesting_name]

    @constants << [ join_nesting_to_scope(nesting_to_scope(@current_nesting), pre_nesting), nesting_name, :mod ]

    @current_nesting << current_nesting_element

    super(ast)

    @current_nesting.pop
  end

  def on_class(ast)
    pre_nesting, nesting_name = get_nesting(ast.children[0])
    current_nesting_element = [:klass, pre_nesting, nesting_name]

    @constants << [ join_nesting_to_scope(nesting_to_scope(@current_nesting), pre_nesting), nesting_name, :klass ]

    @current_nesting << current_nesting_element

    super(ast)

    @current_nesting.pop
  end

  def on_def(ast)
    method_name = ast.children[0].to_s

    @methods << [ nesting_to_scope(@current_nesting), method_name ]

    super(ast)
  end

  def nesting_to_scope(nesting)
    return nil if nesting.empty?

    nesting.map do |type, pre, name|
      pre + [name]
    end.flatten.join("::")
  end

  def join_nesting_to_scope(scope, nesting)
    result = ([scope] + nesting).compact.join("::")
    result.empty? ? nil : result
  end

  def on_casgn(ast)
    scope, name, _expr = ast.children

    @constants << [
      join_nesting_to_scope(nesting_to_scope(@current_nesting), pre_nesting(scope)),
      name.to_s,
      :other
    ]

    super(ast)
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


