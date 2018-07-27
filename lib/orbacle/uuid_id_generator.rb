# frozen_string_literal: true

require 'securerandom'

module Orbacle
  class UuidIdGenerator
    def call
      SecureRandom.uuid
    end
  end
end
