# frozen_string_literal: true

require 'spec_helper'

module Orbacle
  RSpec.describe RubyParser do
    specify "parse ruby code" do
      snippet = "42"

      expect(parse(snippet)).to eq(Parser::AST::Node.new(:int, [42]))
    end

    specify "raise syntax error" do
      snippet = "do"

      expect do
        parse(snippet)
      end.to raise_error(RubyParser::SyntaxError)
    end

    specify "syntax error don't end up in stderr" do
      snippet = "do"

      expect($stderr).not_to receive(:puts)

      begin
        parse(snippet)
      rescue RubyParser::SyntaxError
      end
    end

    specify "raise encoding error" do
      snippet = <<-END
      "\xC0\xC0"
      END

      expect do
        parse(snippet)
      end.to raise_error(RubyParser::EncodingError)
    end

    def parse(snippet)
      RubyParser.new.parse(snippet)
    end
  end
end
