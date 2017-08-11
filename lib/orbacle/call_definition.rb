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
      result = db.find_constants([searched_constant])[0]
      return nil if result.nil?
      scope, _name, _type, targetfile, targetline = result
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
        }
      }
    end
  end
end
