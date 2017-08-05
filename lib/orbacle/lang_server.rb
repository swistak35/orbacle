require 'json'
require 'pathname'
require 'uri'
require 'orbacle/sql_database_adapter'

module Orbacle
  class LangServer
    def initialize(db_adapter:)
      @db_adapter = db_adapter
    end

    def logger(text)
      File.open("/tmp/orbacle.log", "a") {|f| f.puts(text) }
    end

    def call_method(json)
      request_id = json[:id]
      method_name = json[:method]
      params = json[:params]
      case method_name
      when "textDocument/definition"
        result = call_definition(params)
      else
        result = nil
        logger("Called unhandled method '#{method_name}' with params '#{params}'")
      end
      if result
        return {
          id: request_id,
          result: result,
        }
      end
    # rescue => e
    #   logger(e)
    end

    def call_definition(params)
      logger("Definition called with params #{params}!")
      textDocument = params[:textDocument]
      fileuri = textDocument[:uri]
      project_path, db_path = find_closest_db(fileuri)
      db = @db_adapter.open_for_file(fileuri)
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

    def find_closest_db(fileuri)
      dirpath = Pathname(URI(fileuri).path)
      while !dirpath.root?
        dirpath = dirpath.split[0]
        db_path = dirpath.join(".orbacle.db")
        return [dirpath, db_path] if File.exists?(db_path)
      end
      return nil
    end
  end
end
