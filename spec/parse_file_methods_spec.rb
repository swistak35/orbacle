require 'spec_helper'

RSpec.describe ParseFileMethods do
  specify do
    file = <<END
      class Foo
        def bar
        end
      end
END
    expect(parse_file_methods.(file)).to eq([
      ["Foo", "bar"],
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
      ["Foo", "bar"],
      ["Foo", "baz"],
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
      ["Some::Foo", "bar"],
      ["Some::Foo", "baz"],
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
      ["Some::Foo", "oof"],
      ["Some::Bar", "rab"],
    ])
  end

  it do
    file = <<END
      module Some
        module Foo
          class Bar
            def baz
            end
          end
        end
      end
END
    expect(parse_file_methods.(file)).to eq([
      ["Some::Foo::Bar", "baz"],
    ])
  end

  it do
    file = <<END
      module Some::Foo
        class Bar
          def baz
          end
        end
      end
END

    expect(parse_file_methods.(file)).to eq([
      ["Some::Foo::Bar", "baz"],
    ])
  end

  it do
    file = <<END
      module Some::Foo::Bar
        class Baz
          def xxx
          end
        end
      end
END

    expect(parse_file_methods.(file)).to eq([
      ["Some::Foo::Bar::Baz", "xxx"],
    ])
  end

  it do
    file = <<END
      module Some::Foo
        class Bar::Baz
          def xxx
          end
        end
      end
END

    expect(parse_file_methods.(file)).to eq([
      ["Some::Foo::Bar::Baz", "xxx"],
    ])
  end

  it do
    file = <<END
      def xxx
      end
END

    expect(parse_file_methods.(file)).to eq([
      [nil, "xxx"],
    ])
  end

  def parse_file_methods
    ->(file) {
      service = ParseFileMethods.new
      service.(file)[:methods]
    }
  end
end
