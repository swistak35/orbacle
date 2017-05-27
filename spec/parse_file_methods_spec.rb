require 'spec_helper'

RSpec.describe Swistakbot::ParseFileMethods do
  specify do
    file = <<END
      class Foo
        def bar
        end
      end
END
    r = parse_file_methods.(file)
    expect(r[:methods]).to eq([
      ["Foo", "bar"],
    ])
    expect(r[:constants]).to match_array([
      [nil, "Foo", :klass, { line: 1 }]
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
    r = parse_file_methods.(file)
    expect(r[:methods]).to eq([
      ["Foo", "bar"],
      ["Foo", "baz"],
    ])
    expect(r[:constants]).to match_array([
      [nil, "Foo", :klass, { line: 1 }]
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
    r = parse_file_methods.(file)
    expect(r[:methods]).to eq([
      ["Some::Foo", "bar"],
      ["Some::Foo", "baz"],
    ])
    expect(r[:constants]).to match_array([
      [nil, "Some", :mod, { line: 1 }],
      ["Some", "Foo", :klass, { line: 2 }],
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

    r = parse_file_methods.(file)
    expect(r[:methods]).to eq([
      ["Some::Foo", "oof"],
      ["Some::Bar", "rab"],
    ])
    expect(r[:constants]).to match_array([
      [nil, "Some", :mod, { line: 1 }],
      ["Some", "Foo", :klass, { line: 2 }],
      ["Some", "Bar", :klass, { line: 7 }],
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
    r = parse_file_methods.(file)
    expect(r[:methods]).to eq([
      ["Some::Foo::Bar", "baz"],
    ])
    expect(r[:constants]).to match_array([
      [nil, "Some", :mod, { line: 1 }],
      ["Some", "Foo", :mod, { line: 2 }],
      ["Some::Foo", "Bar", :klass, { line: 3 }],
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

    r = parse_file_methods.(file)
    expect(r[:methods]).to eq([
      ["Some::Foo::Bar", "baz"],
    ])
    expect(r[:constants]).to match_array([
      ["Some", "Foo", :mod, { line: 1 }],
      ["Some::Foo", "Bar", :klass, { line: 2 }],
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

    r = parse_file_methods.(file)
    expect(r[:methods]).to eq([
      ["Some::Foo::Bar::Baz", "xxx"],
    ])
    expect(r[:constants]).to match_array([
      ["Some::Foo", "Bar", :mod, { line: 1 }],
      ["Some::Foo::Bar", "Baz", :klass, { line: 2 }],
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

    r = parse_file_methods.(file)
    expect(r[:methods]).to eq([
      ["Some::Foo::Bar::Baz", "xxx"],
    ])
    expect(r[:constants]).to match_array([
      ["Some", "Foo", :mod, { line: 1 }],
      ["Some::Foo::Bar", "Baz", :klass, { line: 2 }],
    ])
  end

  it do
    file = <<END
      def xxx
      end
END

    r = parse_file_methods.(file)
    expect(r[:methods]).to eq([
      [nil, "xxx"],
    ])
    expect(r[:constants]).to match_array([])
  end

  specify do
    file = <<END
      class Foo
        Bar = 32

        def bar
        end
      end
END
    r = parse_file_methods.(file)
    expect(r[:methods]).to eq([
      ["Foo", "bar"],
    ])
    expect(r[:constants]).to match_array([
      [nil, "Foo", :klass, { line: 1 }],
      ["Foo", "Bar", :other, { line: 2 }],
    ])
  end

  specify do
    file = <<END
      class Foo
        Ban::Baz::Bar = 32
      end
END
    r = parse_file_methods.(file)
    expect(r[:methods]).to eq([])
    expect(r[:constants]).to match_array([
      [nil, "Foo", :klass, { line: 1 }],
      ["Foo::Ban::Baz", "Bar", :other, { line: 2 }],
    ])
  end

  xspecify do
    file = <<END
      class Foo
        ::Bar = 32
      end
END
    # another example would be with ::Bar::Baz because it's different case
    r = parse_file_methods.(file)
    expect(r[:constants]).to match_array([
      [nil, "Foo", :klass, { line: 1 }],
      [nil, "Bar", :other, { line: 2 }],
    ])
  end


  def parse_file_methods
    ->(file) {
      service = Swistakbot::ParseFileMethods.new
      service.process_file(file)
    }
  end
end
