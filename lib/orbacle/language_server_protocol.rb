module Orbacle
  module LanguageServerProtocol
    class FileLanguageServer
      def initialize(implementation, input = $stdin, output = $stdout)
        @implementation = implementation
        @input = input
        @output = output
      end

      def start
        loop do
          headers = {}
          loop do
            header_line = input.readline.strip
            if header_line.empty?
              if headers.empty?
                redo
              else
                break
              end
            end
            header_name, header_value = header_line.split(":", 2)
            headers[header_name.strip] = header_value.strip
          end

          body_raw = input.read(headers["Content-Length"].to_i)
          body_json = JSON.parse(body_raw)
          implementation.request(
            body_json.fetch("id"),
            body_json.fetch("method"),
            body_json.fetch("params"))
        end
      rescue EOFError
      end

      private
      attr_reader :implementation, :input, :output
    end
  end
end
