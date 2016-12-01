require 'spec_helper'

RSpec.describe Swistakbot do
  specify do
    Swistakbot.new
  end

  let(:parse_file_methods) { ParseFileMethods.new }

  specify do
    file = <<END
      class Foo
        def bar
        end
      end
END
    expect(parse_file_methods.(file)).to eq([
      ParseFileMethods::Result.new("Foo", "bar")
    ])
  end

  specify do
    file = <<END
      class Foo
        def bar
        end

        def baz
        end
      end
END
    expect(parse_file_methods.(file)).to eq([
      ParseFileMethods::Result.new("Foo", "bar"),
      ParseFileMethods::Result.new("Foo", "baz"),
    ])
  end
end
