require 'parser/current'
require 'orbacle/nesting_container'

class Orbacle::DefinitionProcessor < Parser::AST::Processor
  def process_file(file, line, character)
    ast = Parser::CurrentRuby.parse(file)

    @current_nesting = Orbacle::NestingContainer.new
    @searched_line = line
    @searched_character = character

    process(ast)

    return [@found_constant, @found_nesting, @found_type]
  end

  def on_const(ast)
    name_loc_range = ast.loc.name
    ast_all_ranges = all_ranges(ast)
    if @searched_line == name_loc_range.line && ast_all_ranges.any? {|r| r.include?(@searched_character) }
      @found_type = "constant"
      @found_constant = const_to_string(ast)
      @found_nesting = @current_nesting.get_output_nesting
    end
  end

  def on_module(ast)
    ast_name, _ = ast.children

    @current_nesting.increase_nesting_mod(ast_name)

    super(ast)

    @current_nesting.decrease_nesting
  end

  def on_class(ast)
    ast_name, _ = ast.children

    @current_nesting.increase_nesting_class(ast_name)

    super(ast)

    @current_nesting.decrease_nesting
  end

  def on_send(ast)
    selector_loc = ast.loc.selector
    if @searched_line == selector_loc.line && selector_loc.column_range.include?(@searched_character)
      @found_type = "send"
      @found_constant = ast.children[1].to_s
      @found_nesting = @current_nesting.get_output_nesting
    end

    super(ast)
  end

  private

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
end
