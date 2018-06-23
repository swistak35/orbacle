require 'stringio'

module Orbacle
  module LanguageServerProtocol
    RSpec.describe FileLanguageServer do
      let(:implementation) { double }
      let(:input) { StringIO.new }
      let(:output) { StringIO.new }

      specify do
        server = FileLanguageServer.new(implementation)
        expect(server.input).to eq($stdin)
        expect(server.output).to eq($stdout)
      end

      specify do
        allow(implementation).to receive(:language_server=)
        server = FileLanguageServer.new(implementation, input, output)

        expect(implementation).to receive(:request).with(42, "someMethod", { foo: 13 })
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
        allow(implementation).to receive(:language_server=)
        server = FileLanguageServer.new(implementation, input, output)

        expect(implementation).to receive(:request).with(42, "someMethod", { foo: 13 })
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
        allow(implementation).to receive(:language_server=)
        server = FileLanguageServer.new(implementation, input, output)

        expect(implementation).to receive(:request).with(42, "someMethod", { foo: 13 })
        expect(implementation).to receive(:request).with(43, "otherMethod", { bar: "baz" })

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

      specify do
        server = FileLanguageServer.new(implementation, input, output)

        expect(implementation).to receive(:language_server=).with(server)

        server.start
      end

      specify do
        fake_implementation = Class.new do
          attr_writer :language_server

          def request(id, method_name, params)
            @language_server.response(id, { foo: "bar" }, { code: -234 })
          end
        end

        server = FileLanguageServer.new(fake_implementation.new, input, output)

        input.print <<-LSP
Content-Length: 423

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

        expected_output = <<-LSP.strip
Content-Length: 54\r
\r
{"id":42,"result":{"foo":"bar"},"error":{"code":-234}}
LSP

        output.rewind
        expect(output.read).to eq(expected_output)
      end
    end
  end
end
