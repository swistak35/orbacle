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
      call_definition = CallDefinition.new(db_adapter: @db_adapter)
      call_definition.(params)
    end
  end
end
