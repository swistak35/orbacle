module Orbacle
  class ProcType
    def initialize(lambda_id)
      @lambda_id = lambda_id
    end

    attr_reader :lambda_id

    def ==(other)
      self.class == other.class &&
        self.lambda_id == other.lambda_id
    end

    def hash
      [
        self.class,
        self.lambda_id,
      ].hash ^ BIG_VALUE
    end
    alias eql? ==

    def each_possible_type
      yield self
    end

    def bottom?
      false
    end
  end
end

