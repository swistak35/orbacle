# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'orbacle'

require 'pp'
require 'timeout'

RSpec.configure do |config|
  config.around(:each) do |example|
    if ENV["MUTANT_TESTING"]
      default_timeout = example.metadata[:performance] ? 180 : 1
      timeout = example.metadata[:timeout] || default_timeout
      Timeout.timeout(timeout, &example)
    else
      example.call
    end
  end
end
