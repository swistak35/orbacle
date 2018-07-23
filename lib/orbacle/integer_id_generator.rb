# frozen_string_literal: true

module Orbacle
  class IntegerIdGenerator
    def initialize
      @last_id = 0
    end

    def call
      @last_id += 1
    end
  end
end
