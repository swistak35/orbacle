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

    def with(es)
      Result.new(es + list)
    end
  end

  def call(file)
    ast = Parser::CurrentRuby.parse(file)

    nesting = []
    if ast.type == :module
      parse_module(ast, nesting)
    else
      parse_klass(ast, nesting)
    end
  end

  private

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

  def parse_module(ast, old_nesting)
    ast_const = ast.children.first
    pre_nesting, nesting_name = get_nesting(ast_const)
    current_nesting_element = [:mod, pre_nesting, nesting_name]
    new_nesting = old_nesting + [current_nesting_element]
    child = ast.children[1]
    if child.type == :begin
      child.children.flat_map do |c|
        parse_klass(c, new_nesting).map do |result|
          result.with(nesting_element_to_result(current_nesting_element))
        end
      end
    elsif child.type == :class
      parse_klass(child, new_nesting).map do |result|
        result.with(nesting_element_to_result(current_nesting_element))
      end
    elsif child.type == :module
      parse_module(child, new_nesting).map do |result|
        result.with(nesting_element_to_result(current_nesting_element))
      end
    else
      raise
    end
  end

  def parse_klass(ast, _nesting)
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

  def nesting_element_to_result(current_nesting_element)
    _, pre_nesting, nesting_name = current_nesting_element
    (pre_nesting + [nesting_name]).map {|e| Result::Mod.new(e)}
  end
end

class Swistakbot
end
