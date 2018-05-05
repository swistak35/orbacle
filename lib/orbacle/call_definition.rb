require 'orbacle/some_utils'

module Orbacle
  class CallDefinition
    include SomeUtils

    def initialize(tree, typing_result)
      @tree = tree
      @typing_result = typing_result
    end

    def call(params)
      textDocument = params[:textDocument]
      fileuri = textDocument[:uri]
      # project_path = find_project_root(fileuri)
      # db = @db_adapter.new(project_root: project_path)
      file_content = File.read(URI(fileuri).path)
      searched_line = params[:position][:line]
      searched_character = params[:position][:character]
      searched_constant, found_nesting, found_type = Orbacle::DefinitionProcessor.new.process_file(file_content, searched_line + 1, searched_character + 1)
      if found_type == "constant"
        best_result = @tree.solve_reference(ConstRef.from_full_name(searched_constant, found_nesting))
        return nil if best_result.nil?
        return {
          uri: "file://#{best_result.location.uri}",
          range: {
            start: {
              line: best_result.location.start.line - 1,
              character: 0,
            },
            end: {
              line: best_result.location.end.line - 1,
              character: 1,
            }
          },
          _count: 1,
        }
      elsif found_type == "send"
        results = @tree.find_any_methods(searched_constant)
        best_result = results[0]
        return nil if best_result.nil?
        return {
          uri: "file://#{best_result.location.uri}",
          range: {
            start: {
              line: best_result.location.start.line - 1,
              character: 0,
            },
            end: {
              line: best_result.location.end.line - 1,
              character: 1,
            }
          },
          _count: results.size,
        }
      end
    end

    def generate_nestings(searched_constant, found_nesting)
      results = []
      searched_const_ar = searched_constant.split("::")
      searched_const_ar = searched_const_ar.drop(1) if searched_constant.start_with?("::")
      constant_name = searched_const_ar.last
      if !searched_const_ar[0..-2].empty?
        results.unshift(searched_const_ar[0..-2].join("::"))
      end
      if !searched_constant.start_with?("::")
        found_nesting.reverse.each do |nesting_level|
          nesting_name = nesting_level.split("::").last
          results.unshift([nesting_name, results[0]].compact.join("::"))
        end
      end
      results << ""
      return results, constant_name
    end
  end
end
