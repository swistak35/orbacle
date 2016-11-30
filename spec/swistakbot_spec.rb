require 'spec_helper'


RSpec.describe Swistakbot do
  specify do
    Swistakbot.new
  end

  specify do
    swistakbot = Swistakbot.new
    file = <<END
      class Foo
        def bar
        end
      end
END
    r = swistakbot.parse_file_methods(file)
    expect(r).to eq([
      Swistakbot::Result.new("Foo", "bar")
    ])
  end
end
