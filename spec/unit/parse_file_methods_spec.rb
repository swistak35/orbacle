require 'spec_helper'

RSpec.describe Orbacle::ParseFileMethods do
  def build_klass(scope: nil, name:, inheritance: nil)
    Orbacle::ParseFileMethods::Klasslike.build_klass(scope: scope, name: name, inheritance: inheritance)
  end

  def build_module(scope: nil, name:)
    Orbacle::ParseFileMethods::Klasslike.build_module(scope: scope, name: name)
  end

  specify do
    file = <<-END
      class Foo
        def bar
        end
      end
    END

    r = parse_file_methods.(file)
    expect(r[:methods]).to eq([
      ["Foo", "bar", { line: 2 }],
    ])
    expect(r[:constants]).to match_array([
      [nil, "Foo", :klass, { line: 1 }]
    ])
    expect(r[:klasslikes]).to match_array([
      build_klass(name: "Foo")
    ])
  end

  specify do
    file = <<-END
      class Foo
        def bar
        end

        def baz
        end
      end
    END

    r = parse_file_methods.(file)
    expect(r[:methods]).to eq([
      ["Foo", "bar", { line: 2 }],
      ["Foo", "baz", { line: 5 }],
    ])
    expect(r[:constants]).to match_array([
      [nil, "Foo", :klass, { line: 1 }]
    ])
    expect(r[:klasslikes]).to match_array([
      build_klass(name: "Foo")
    ])
  end

  it do
    file = <<-END
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
      ["Some::Foo", "bar", { line: 3 }],
      ["Some::Foo", "baz", { line: 6 }],
    ])
    expect(r[:constants]).to match_array([
      [nil, "Some", :mod, { line: 1 }],
      ["Some", "Foo", :klass, { line: 2 }],
    ])
    expect(r[:klasslikes]).to match_array([
      build_module(name: "Some"),
      build_klass(scope: "Some", name: "Foo"),
    ])
  end

  it do
    file = <<-END
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
      ["Some::Foo", "oof", { line: 3 }],
      ["Some::Bar", "rab", { line: 8 }],
    ])
    expect(r[:constants]).to match_array([
      [nil, "Some", :mod, { line: 1 }],
      ["Some", "Foo", :klass, { line: 2 }],
      ["Some", "Bar", :klass, { line: 7 }],
    ])
    expect(r[:klasslikes]).to match_array([
      build_module(name: "Some"),
      build_klass(scope: "Some", name: "Foo"),
      build_klass(scope: "Some", name: "Bar"),
    ])
  end

  it do
    file = <<-END
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
      ["Some::Foo::Bar", "baz", { line: 4 }],
    ])
    expect(r[:constants]).to match_array([
      [nil, "Some", :mod, { line: 1 }],
      ["Some", "Foo", :mod, { line: 2 }],
      ["Some::Foo", "Bar", :klass, { line: 3 }],
    ])
    expect(r[:klasslikes]).to match_array([
      build_module(name: "Some"),
      build_module(scope: "Some", name: "Foo"),
      build_klass(scope: "Some::Foo", name: "Bar"),
    ])
  end

  it do
    file = <<-END
      module Some::Foo
        class Bar
          def baz
          end
        end
      end
    END

    r = parse_file_methods.(file)
    expect(r[:methods]).to eq([
      ["Some::Foo::Bar", "baz", { line: 3 }],
    ])
    expect(r[:constants]).to match_array([
      ["Some", "Foo", :mod, { line: 1 }],
      ["Some::Foo", "Bar", :klass, { line: 2 }],
    ])
    expect(r[:klasslikes]).to match_array([
      build_module(scope: "Some", name: "Foo"),
      build_klass(scope: "Some::Foo", name: "Bar"),
    ])
  end

  it do
    file = <<-END
      module Some::Foo::Bar
        class Baz
          def xxx
          end
        end
      end
    END

    r = parse_file_methods.(file)
    expect(r[:methods]).to eq([
      ["Some::Foo::Bar::Baz", "xxx", { line: 3 }],
    ])
    expect(r[:constants]).to match_array([
      ["Some::Foo", "Bar", :mod, { line: 1 }],
      ["Some::Foo::Bar", "Baz", :klass, { line: 2 }],
    ])
    expect(r[:klasslikes]).to match_array([
      build_module(scope: "Some::Foo", name: "Bar"),
      build_klass(scope: "Some::Foo::Bar", name: "Baz"),
    ])
  end

  it do
    file = <<-END
      module Some::Foo
        class Bar::Baz
          def xxx
          end
        end
      end
    END

    r = parse_file_methods.(file)
    expect(r[:methods]).to eq([
      ["Some::Foo::Bar::Baz", "xxx", { line: 3 }],
    ])
    expect(r[:constants]).to match_array([
      ["Some", "Foo", :mod, { line: 1 }],
      ["Some::Foo::Bar", "Baz", :klass, { line: 2 }],
    ])
    expect(r[:klasslikes]).to match_array([
      build_module(scope: "Some", name: "Foo"),
      build_klass(scope: "Some::Foo::Bar", name: "Baz"),
    ])
  end

  it do
    file = <<-END
      class Bar
        class ::Foo
          def xxx
          end
        end
      end
    END

    r = parse_file_methods.(file)
    expect(r[:methods]).to eq([
      ["Foo", "xxx", { line: 3 }],
    ])
    expect(r[:constants]).to match_array([
      [nil, "Bar", :klass, { line: 1 }],
      [nil, "Foo", :klass, { line: 2 }],
    ])
    expect(r[:klasslikes]).to match_array([
      build_klass(name: "Bar"),
      build_klass(name: "Foo"),
    ])
  end

  it do
    file = <<-END
      class Bar
        module ::Foo
          def xxx
          end
        end
      end
    END

    r = parse_file_methods.(file)
    expect(r[:methods]).to eq([
      ["Foo", "xxx", { line: 3 }],
    ])
    expect(r[:constants]).to match_array([
      [nil, "Bar", :klass, { line: 1 }],
      [nil, "Foo", :mod, { line: 2 }],
    ])
    expect(r[:klasslikes]).to match_array([
      build_klass(name: "Bar"),
      build_module(name: "Foo"),
    ])
  end

  it do
    file = <<-END
      def xxx
      end
    END

    r = parse_file_methods.(file)
    expect(r[:methods]).to eq([
      [nil, "xxx", { line: 1 }],
    ])
    expect(r[:constants]).to match_array([])
    expect(r[:klasslikes]).to be_empty
  end

  specify do
    file = <<-END
      class Foo
        Bar = 32

        def bar
        end
      end
    END

    r = parse_file_methods.(file)
    expect(r[:methods]).to eq([
      ["Foo", "bar", { line: 4 }],
    ])
    expect(r[:constants]).to match_array([
      [nil, "Foo", :klass, { line: 1 }],
      ["Foo", "Bar", :other, { line: 2 }],
    ])
    expect(r[:klasslikes]).to match_array([
      build_klass(name: "Foo"),
    ])
  end

  specify do
    file = <<-END
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
    expect(r[:klasslikes]).to match_array([
      build_klass(name: "Foo"),
    ])
  end

  specify do
    file = <<-END
      class Foo
        ::Bar = 32
      end
    END

    r = parse_file_methods.(file)
    expect(r[:constants]).to match_array([
      [nil, "Foo", :klass, { line: 1 }],
      [nil, "Bar", :other, { line: 2 }],
    ])
    expect(r[:klasslikes]).to match_array([
      build_klass(name: "Foo"),
    ])
  end

  specify do
    file = <<-END
      class Foo
        ::Baz::Bar = 32
      end
    END

    r = parse_file_methods.(file)
    expect(r[:constants]).to match_array([
      [nil, "Foo", :klass, { line: 1 }],
      ["Baz", "Bar", :other, { line: 2 }],
    ])
    expect(r[:klasslikes]).to match_array([
      build_klass(name: "Foo"),
    ])
  end

  specify do
    file = <<-END
      class Foo
        ::Baz::Bam::Bar = 32
      end
    END

    r = parse_file_methods.(file)
    expect(r[:constants]).to match_array([
      [nil, "Foo", :klass, { line: 1 }],
      ["Baz::Bam", "Bar", :other, { line: 2 }],
    ])
    expect(r[:klasslikes]).to match_array([
      build_klass(name: "Foo"),
    ])
  end

  it do
    file = <<-END
      module Some
        module Foo
          def oof
          end
        end

        module Bar
          def rab
          end
        end
      end
    END

    r = parse_file_methods.(file)
    expect(r[:methods]).to eq([
      ["Some::Foo", "oof", { line: 3 }],
      ["Some::Bar", "rab", { line: 8 }],
    ])
    expect(r[:constants]).to match_array([
      [nil, "Some", :mod, { line: 1 }],
      ["Some", "Foo", :mod, { line: 2 }],
      ["Some", "Bar", :mod, { line: 7 }],
    ])
    expect(r[:klasslikes]).to match_array([
      build_module(name: "Some"),
      build_module(scope: "Some", name: "Foo"),
      build_module(scope: "Some", name: "Bar"),
    ])
  end

  specify do
    file = <<-END
      class Foo < Bar
      end
    END

    r = parse_file_methods.(file)
    expect(r[:klasslikes]).to match_array([
      build_klass(name: "Foo", inheritance: "Bar")
    ])
  end

  specify do
    file = <<-END
      class Foo < Bar::Baz
      end
    END

    r = parse_file_methods.(file)
    expect(r[:klasslikes]).to match_array([
      build_klass(name: "Foo", inheritance: "Bar::Baz")
    ])
  end

  specify do
    file = <<-END
      class Foo < ::Bar::Baz
      end
    END

    r = parse_file_methods.(file)
    expect(r[:klasslikes]).to match_array([
      build_klass(name: "Foo", inheritance: "::Bar::Baz")
    ])
  end

  specify do
    file = <<-END
      module Some
        class Foo < Bar
        end
      end
    END

    r = parse_file_methods.(file)
    expect(r[:klasslikes]).to match_array([
      build_module(name: "Some"),
      build_klass(scope: "Some", name: "Foo", inheritance: "Bar")
    ])
  end

  specify do
    file = <<-END
      Foo = Class.new(Bar)
    END

    r = parse_file_methods.(file)
    expect(r[:klasslikes]).to match_array([
      build_klass(name: "Foo", inheritance: "Bar")
    ])
  end

  specify do
    file = <<-END
      Foo = Class.new
    END

    r = parse_file_methods.(file)
    expect(r[:klasslikes]).to match_array([
      build_klass(name: "Foo")
    ])
  end

  specify do
    file = <<-END
      Foo = Module.new
    END

    r = parse_file_methods.(file)
    expect(r[:klasslikes]).to match_array([
      build_module(name: "Foo")
    ])
  end

  def parse_file_methods
    ->(file) {
      service = Orbacle::ParseFileMethods.new
      service.process_file(file)
    }
  end
end
