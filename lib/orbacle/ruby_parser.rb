require 'parser/current'

module Orbacle
  class RubyParser
    Error = Class.new(StandardError)
    SyntaxError = Class.new(Error)
    EncodingError = Class.new(Error)

    def parse(content)
      Parser::CurrentRuby.parse(content)
    rescue Parser::SyntaxError
      raise SyntaxError
    rescue ::EncodingError
      raise EncodingError
    end
  end
end
