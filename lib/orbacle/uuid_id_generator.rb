# frozen_string_literal: true

module Orbacle
  class UuidIdGenerator
    def call
      SecureRandom.uuid
    end
  end
end
