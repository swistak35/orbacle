require 'parser/current'

class Orbacle::DefinitionProcessor < Parser::AST::Processor
  def process_file(file, line, character)
    ast = Parser::CurrentRuby.parse(file)

    @searched_line = line
    @searched_character = character

    process(ast)

    return @found_constant
  end

  def on_const(ast)
    name_loc_range = ast.loc.name
    ast_all_ranges = all_ranges(ast)
    require 'byebug'; byebug
    if @searched_line == name_loc_range.line && name_loc_range.column_range.include?(@searched_character)
      @found_constant = ast.children[1].to_s
    end
  end

  def all_ranges(ast)
    if ast.nil?
      []
    elsif ast.type == :cbase
      []
    else
      all_ranges(ast.children[0]) + [ast.loc.name.column_range]
    end
  end

  def const_to_string(ast)
    if ast.nil?
      nil
    elsif ast.type == :cbase
      ""
    else
      [const_to_string(ast.children[0]), ast.children[1]].compact.join("::")
    end
  end

  # def on_module(ast)
  #   ast_name, _ = ast.children
  #   prename, module_name = get_nesting(ast_name)

  #   @constants << [
  #     scope_from_nesting_and_prename(@current_nesting, prename),
  #     module_name,
  #     :mod,
  #     { line: ast_name.loc.line },
  #   ]

  #   current_nesting_element = [:mod, prename, module_name]
  #   @current_nesting << current_nesting_element

  #   super(ast)

  #   @current_nesting.pop
  # end

  # def on_class(ast)
  #   ast_name, _ = ast.children
  #   prename, klass_name = get_nesting(ast_name)

  #   @constants << [
  #     scope_from_nesting_and_prename(@current_nesting, prename),
  #     klass_name,
  #     :klass,
  #     { line: ast_name.loc.line },
  #   ]

  #   current_nesting_element = [:klass, prename, klass_name]
  #   @current_nesting << current_nesting_element

  #   super(ast)

  #   @current_nesting.pop
  # end
end
