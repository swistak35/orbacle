require 'json'

module Orbacle
  class LangServer
    def logger(text)
      File.open("/tmp/orbacle.log", "a") {|f| f.puts(text) }
    end

    def start
      loop do
        headers = {}
        loop do
          line = $stdin.gets
          return if line.nil?
          break if line.chomp.empty?
          logger "Received header line: #{line.inspect}"
          _, hname, hval = line.chomp.match(/(.+):\s*(.*)/).to_a
          headers[hname] = hval
        end
        body = $stdin.gets(headers["Content-Length"].to_i)
        logger "Received body: #{body.inspect}"
        json = JSON.parse(body)
        call_method(json)
      end
    end

    def call_method(json)
      method_name = json["method"]
      params = json["params"]
      case method_name
      when "textDocument/definition"
        call_definition(params)
      else logger("Called unhandled method '#{method_name}' with params '#{params}'")
      end
    end

    def call_definition(params)
      logger("Definition called with params #{params}!")
    end
  end
end
