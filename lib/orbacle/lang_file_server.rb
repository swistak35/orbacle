module Orbacle
  class LangFileServer
    def initialize(lang_server:, logger:)
      @lang_server = lang_server
      @logger = logger
    end

    def start
      loop do
        headers = {}
        loop do
          line = $stdin.gets
          return if line.nil?
          break if line.chomp.empty?
          logger.debug("header #{line.inspect}")
          _, hname, hval = line.chomp.match(/(.+):\s*(.*)/).to_a
          headers[hname] = hval
        end
        body = $stdin.gets(headers["Content-Length"].to_i)
        logger.info("received #{body.inspect}")
        json = JSON.parse(body, symbolize_names: true)
        result = @lang_server.call_method(json)
        logger.info("send #{result.inspect}")
        if result
          response_json = JSON(result)
          $stdout.print "Content-Length: #{response_json.size}\r\n\r\n#{response_json}"
          $stdout.flush
        end
      end
    end

    private
    attr_reader :logger
  end
end
