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
      ParseFileMethods::Result.new([
        ParseFileMethods::Result::Klass.new("Foo"),
        ParseFileMethods::Result::Method.new("bar"),
      ]),
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
      ParseFileMethods::Result.new([
        ParseFileMethods::Result::Klass.new("Foo"),
        ParseFileMethods::Result::Method.new("bar"),
      ]),
      ParseFileMethods::Result.new([
        ParseFileMethods::Result::Klass.new("Foo"),
        ParseFileMethods::Result::Method.new("baz"),
      ]),
    ])
  end

  it do
    file = <<END
      module Some
        class Foo
          def bar
          end

          def baz
          end
        end
      end
END
    expect(parse_file_methods.(file)).to eq([
      ParseFileMethods::Result.new([
        ParseFileMethods::Result::Mod.new("Some"),
        ParseFileMethods::Result::Klass.new("Foo"),
        ParseFileMethods::Result::Method.new("bar"),
      ]),
      ParseFileMethods::Result.new([
        ParseFileMethods::Result::Mod.new("Some"),
        ParseFileMethods::Result::Klass.new("Foo"),
        ParseFileMethods::Result::Method.new("baz"),
      ]),
    ])
  end

  it do
    file = <<END
      module Some
        class Foo
          def oof
          end
        end

        class Bar
          def rab
          end
        end
      end
END
    expect(parse_file_methods.(file)).to eq([
      ParseFileMethods::Result.new([
        ParseFileMethods::Result::Mod.new("Some"),
        ParseFileMethods::Result::Klass.new("Foo"),
        ParseFileMethods::Result::Method.new("oof"),
      ]),
      ParseFileMethods::Result.new([
        ParseFileMethods::Result::Mod.new("Some"),
        ParseFileMethods::Result::Klass.new("Bar"),
        ParseFileMethods::Result::Method.new("rab"),
      ]),
    ])
  end
end
