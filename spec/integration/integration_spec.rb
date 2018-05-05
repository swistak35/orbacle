require 'spec_helper'
require 'logger'

RSpec.describe Orbacle do
  specify do
    integration_app_path = "#{Dir.pwd}/spec/support/integration_app"

    indexer = Orbacle::Indexer.new
    indexing_result = indexer.(project_root: Pathname.new(integration_app_path))

    lang_server = Orbacle::LangServer.new(logger: Logger.new(nil))
    result = lang_server.call_method(indexing_result, {
      id: 1,
      method: "textDocument/definition",
      jsonrpc: "2.0",
      params: {
        textDocument: {
          uri: "file://#{integration_app_path}/main.rb",
        },
        position: {
          line: 2,
          character: 5,
        }
      }
    })
    expect(result).to eq({
      id: 1,
      result: {
        uri: "file://#{integration_app_path}/bar.rb",
        range: {
          start: {
            line: 0,
            character: 0,
          },
          end: {
            line: 1,
            character: 1,
          }
        },
        _count: 1
      }
    })
  end
end
