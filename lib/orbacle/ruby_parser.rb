# frozen_string_literal: true

require 'parser/ruby25'

module Orbacle
  class RubyParser
    Error = Class.new(StandardError)
    SyntaxError = Class.new(Error)
    EncodingError = Class.new(Error)

    class MyParser < Parser::Ruby25
      def self.default_parser
        my_parser = super
        my_parser.diagnostics.consumer = nil
        my_parser
      end
    end

    def parse(content)
      MyParser.parse(content)
    rescue Parser::SyntaxError
      raise SyntaxError
    rescue ::EncodingError
      raise EncodingError
    end
  end
end
