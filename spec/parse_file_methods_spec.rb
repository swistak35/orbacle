require 'spec_helper'

RSpec.describe ParseFileMethods do
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
      [nil, "Foo", :klass]
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
      [nil, "Foo", :klass]
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
      [nil, "Some", :mod],
      ["Some", "Foo", :klass],
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
      [nil, "Some", :mod],
      ["Some", "Foo", :klass],
      ["Some", "Bar", :klass],
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
      [nil, "Some", :mod],
      ["Some", "Foo", :mod],
      ["Some::Foo", "Bar", :klass],
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
      ["Some", "Foo", :mod],
      ["Some::Foo", "Bar", :klass],
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
      ["Some::Foo", "Bar", :mod],
      ["Some::Foo::Bar", "Baz", :klass],
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
      ["Some", "Foo", :mod],
      ["Some::Foo::Bar", "Baz", :klass],
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
      [nil, "Foo", :klass],
      ["Foo", "Bar", :other],
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
      [nil, "Foo", :klass],
      ["Foo::Ban::Baz", "Bar", :other],
    ])
  end

  xit do
    # nasty
    file = <<END
      class Foo
        ::Bar = 32
      end
END
    # r = parse_file_methods.(file)
    # expect(r[:methods]).to eq([
    #   ["Foo", "bar"],
    # ])
    # expect(r[:constants]).to match_array([
    #   [nil, "Foo", :klass],
    #   ["Foo", "Bar", :other],
    # ])
  end


  def parse_file_methods
    ->(file) {
      service = ParseFileMethods.new
      service.process_file(file)
    }
  end
end
