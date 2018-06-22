require 'stringio'

module Orbacle
  module LanguageServerProtocol
    RSpec.describe FileLanguageServer do
      let(:implementation) { double }
      let(:input) { StringIO.new }
      let(:output) { StringIO.new }

      specify do
        FileLanguageServer.new(implementation)
      end

      specify do
        server = FileLanguageServer.new(implementation, input, output)

        expect(implementation).to receive(:request).with(42, "someMethod", { "foo" => 13 })
        input.print <<-LSP
Content-Length: 423\r

{
  "id": 42,
  "method": "someMethod",
  "params": {
    "foo": 13
  }
}
        LSP

        input.rewind
        server.start
      end

      specify "optional header" do
        server = FileLanguageServer.new(implementation, input, output)

        expect(implementation).to receive(:request).with(42, "someMethod", { "foo" => 13 })
        input.print <<-LSP
        Content-Length: 423\r
        Content-Type: application/vscode-jsonrpc; charset=utf-8\r

        {
          "id": 42,
          "method": "someMethod",
          "params": {
            "foo": 13
          }
        }
        LSP

        input.rewind
        server.start
      end

      specify do
        server = FileLanguageServer.new(implementation, input, output)

        expect(implementation).to receive(:request).with(42, "someMethod", { "foo" => 13 })
        expect(implementation).to receive(:request).with(43, "otherMethod", { "bar" => "baz" })

        msg1 = <<-END.strip
{
  "id": 42,
  "method": "someMethod",
  "params": {
    "foo": 13
  }
}
        END

        msg2 = <<-END.strip
{
  "id": 43,
  "method": "otherMethod",
  "params": {
    "bar": "baz"
  }
}
        END

        input.print <<-LSP
Content-Length: #{msg1.size}

#{msg1}
Content-Length: #{msg2.size}

#{msg2}
        LSP

        input.rewind
        server.start
      end
    end
  end
end
