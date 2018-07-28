# frozen_string_literal: true

require 'parser/ruby25'

module Orbacle
  class RubyParser
    Error = Class.new(StandardError)
    SyntaxError = Class.new(Error)
    EncodingError = Class.new(Error)

    def initialize
      @my_parser = Class.new(Parser::Ruby25) do
        def self.default_parser
          my_parser = super()
          my_parser.diagnostics.consumer = nil
          my_parser
        end
      end
    end

    def parse(content)
      @my_parser.parse(content)
    rescue Parser::SyntaxError
      raise SyntaxError
    rescue ::EncodingError
      raise EncodingError
    end
  end
end
