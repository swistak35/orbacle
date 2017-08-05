require 'json'
require 'pathname'
require 'uri'

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
      request_id = json["id"]
      method_name = json["method"]
      params = json["params"]
      case method_name
      when "textDocument/definition"
        result = call_definition(params)
      else
        result = nil
        logger("Called unhandled method '#{method_name}' with params '#{params}'")
      end
      if result
        response_json = JSON({
          id: request_id,
          result: result
        })
        $stdout.print "Content-Length: #{response_json.size}\r\n\r\n#{response_json}"
        $stdout.flush
      end
    # rescue => e
    #   logger(e)
    end

    def call_definition(params)
      logger("Definition called with params #{params}!")
      textDocument = params["textDocument"]
      fileuri = textDocument["uri"]
      project_path, db_path = find_closest_db(fileuri)
      db = SQLite3::Database.new(db_path.to_s)
      # searched_constant = "ParseFileMethods"
      file_content = File.read(URI(fileuri).path)
      searched_line = params["position"]["line"]
      searched_character = params["position"]["character"]
      searched_constant, found_nesting = Orbacle::DefinitionProcessor.new.process_file(file_content, searched_line + 1, searched_character + 1)
      result = db.execute("select * from constants where name = ?", [searched_constant])[0]
      return nil if result.nil?
      scope, _name, _type, targetfile, targetline = result
      return {
        # uri: "file:///home/swistak35/projs/msc-thesis/lib/orbacle/parse_file_methods.rb",
        uri: "file://#{project_path}/#{targetfile}",
        range: {
          start: {
            line: targetline - 1,
            character: 0,
          },
          end: {
            line: targetline - 1,
            character: 1,
          }
        }
      }
    end

    def find_closest_db(fileuri)
      dirpath = Pathname(URI(fileuri).path)
      while !dirpath.root?
        dirpath = dirpath.split[0]
        db_path = dirpath.join(".orbacle.db")
        return [dirpath, db_path] if File.exists?(db_path)
      end
      return nil
    end
  end
end
