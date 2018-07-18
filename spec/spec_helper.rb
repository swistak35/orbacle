$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'orbacle'

require 'pp'
require 'timeout'

RSpec.configure do |config|
  config.around(:each, performance: false) do |example|
    timeout = example.metadata[:timeout] || 5
    Timeout.timeout(timeout, &example)
  end
end
