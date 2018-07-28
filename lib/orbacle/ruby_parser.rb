# frozen_string_literal: true

require 'parser/ruby25'

module Orbacle
  class RubyParser
    Error = Class.new(StandardError)
    SyntaxError = Class.new(Error)
    EncodingError = Class.new(Error)

    def parse(content)
      parser = Parser::Ruby25
      parser.parse(content)
    rescue Parser::SyntaxError
      raise SyntaxError
    rescue ::EncodingError
      raise EncodingError
    end
  end
end
