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
    if @searched_line == name_loc_range.line && ast_all_ranges.any? {|r| r.include?(@searched_character) }
      @found_constant = const_to_string(ast)
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
end
