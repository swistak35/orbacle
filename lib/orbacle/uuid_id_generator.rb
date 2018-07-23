module Orbacle
  class UuidIdGenerator
    def call
      SecureRandom.uuid
    end
  end
end
