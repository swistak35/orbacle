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

    scope = []
    if ast.type == :module
      parse_module(ast, scope)
    else
      parse_klass(ast, scope)
    end
  end

  private

  def constant_to_nesting_list(const)
    return [] if const.nil?
    constant_to_nesting_list(const.children.first) + [const.children.last.to_s]
  end

  def constant_to_nesting(const)
    constant_to_nesting_list(const).join("::")
  end

  def nesting_to_scope(nesting)
    nesting.split("::")
  end

  def parse_module(ast, scope)
    current_scope_element = constant_to_nesting(ast.children.first)
    new_scope = scope + [current_scope_element]
    child = ast.children[1]
    if child.type == :begin
      child.children.flat_map do |c|
        parse_klass(c, new_scope).map do |result|
          result.with(scope_element_to_result(nesting_to_scope(current_scope_element)))
        end
      end
    elsif child.type == :class
      parse_klass(child, new_scope).map do |result|
        result.with(scope_element_to_result(nesting_to_scope(current_scope_element)))
      end
    elsif child.type == :module
      parse_module(child, new_scope).map do |result|
        result.with(scope_element_to_result(nesting_to_scope(current_scope_element)))
      end
    else
      raise
    end
  end

  def parse_klass(ast, _scope)
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

  def scope_element_to_result(scope_element)
    scope_element.map {|e| Result::Mod.new(e) }
  end
end

class Swistakbot
end
