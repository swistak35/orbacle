require 'json'
require 'pathname'
require 'uri'
require 'orbacle/sql_database_adapter'

module Orbacle
  class LangServer
    def initialize(db_adapter:, logger:)
      @db_adapter = db_adapter
      @logger = logger
    end

    def call_method(indexing_result, json)
      request_id = json[:id]
      method_name = json[:method]
      params = json[:params]
      result = case method_name
        when "textDocument/definition"
          call_definition(indexing_result, params)
        else
          logger.info("unsupported_method_called #{method_name}")
          nil
        end
      if result
        return {
          id: request_id,
          result: result,
        }
      end
    rescue => e
      logger.error("error #{e.inspect} #{e.backtrace}")
      e.backtrace.each {|l| logger.error("error #{l}") }
    end

    def call_definition(indexing_result, params)
      call_definition = CallDefinition.new(*indexing_result)
      call_definition.(params)
    end

    private
    attr_reader :logger
  end
end
