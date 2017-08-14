require 'orbacle/some_utils'

module Orbacle
  class CallDefinition
    include SomeUtils

    def initialize(db_adapter:)
      @db_adapter = db_adapter
    end

    def call(params)
      textDocument = params[:textDocument]
      fileuri = textDocument[:uri]
      project_path = find_project_root(fileuri)
      db = @db_adapter.new(project_root: project_path)
      file_content = File.read(URI(fileuri).path)
      searched_line = params[:position][:line]
      searched_character = params[:position][:character]
      searched_constant, found_nesting = Orbacle::DefinitionProcessor.new.process_file(file_content, searched_line + 1, searched_character + 1)
      possible_nestings = searched_constant.start_with?("::") ? [""] : generate_nestings(found_nesting)
      searched_constant_name = extract_constant_name(searched_constant)
      results = db.find_constants(searched_constant_name, possible_nestings)
      best_result = results[0]
      return nil if best_result.nil?
      scope, _name, _type, targetfile, targetline = best_result
      return {
        uri: "file://#{project_path}/#{targetfile}",
        range: {
          start: {
            line: targetline - 1,
            character: 0,
          },
          end: {
            line: targetline - 1,
            character: 1,
          }
        },
        _count: results.size,
      }
    end

    def generate_nestings(found_nesting)
      results = []
      found_nesting.each do |_type, _x, nesting_name|
        results.unshift([results[0], nesting_name].compact.join("::"))
      end
      results << ""
      return results
    end

    def extract_constant_name(searched_constant)
      if searched_constant.start_with?("::")
        searched_constant[2..-1]
      else
        searched_constant
      end
    end
  end
end
