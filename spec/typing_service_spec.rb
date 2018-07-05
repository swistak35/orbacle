require 'spec_helper'
require 'logger'

module Orbacle
  RSpec.describe TypingService do
    describe "primitives" do
      specify "primitive int" do
        snippet = <<-END
        42
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end

      specify "primitive float" do
        snippet = <<-END
        42.0
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Float"))
      end

      specify "primitive bool" do
        snippet = <<-END
        true
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Boolean"))
      end

      specify "primitive nil" do
        snippet = <<-END
        nil
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Nil"))
      end
    end

    describe "strings" do
      specify "string literal" do
        snippet = <<-END
        "foobar"
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("String"))
      end

      specify "string with interpolation" do
        snippet = '
        bar = 42
        "foo#{bar}baz"
        '

        result = type_snippet(snippet)

        expect(result).to eq(nominal("String"))
      end

      specify "execution string" do
        snippet = '
        bar = 42
        `foo#{bar}baz`
        '

        result = type_snippet(snippet)

        expect(result).to eq(nominal("String"))
      end
    end

    describe "symbols" do
      specify "symbol literal" do
        snippet = <<-END
        :foobar
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Symbol"))
      end

      specify "symbol with interpolation" do
        snippet = '
        bar = 42
        :"foo#{bar}baz"
        '

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Symbol"))
      end
    end

    describe "regexps" do
      specify "regexp" do
        snippet = <<-END
        /foobar/
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Regexp"))
      end

      specify "regexp with interpolation" do
        snippet = '
        bar = 42
        /foo#{bar}/
        '

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Regexp"))
      end
    end

    describe "arrays / tuples" do
      specify "empty array" do
        snippet = <<-END
        []
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [bottom]))
      end

      specify "simple (primitive) literal array" do
        snippet = <<-END
        [1, 2]
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [nominal("Integer")]))
      end

      specify "(primitive) heterogenous literal array" do
        snippet = <<-END
        [1, "foobar"]
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [union([nominal("Integer"), nominal("String")])]))
      end

      specify "array with splat" do
        snippet = <<-END
        foo = [1,2]
        [*foo, "foobar"]
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [union([nominal("Integer"), nominal("String")])]))
      end
    end

    describe "hashes" do
      specify "empty hash" do
        snippet = <<-END
        {}
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Hash", [bottom, bottom]))
      end

      specify "hash" do
        snippet = <<-END
        {
          "foo" => 42,
          bar: "nananana",
        }
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Hash", [union([nominal("String"), nominal("Symbol")]), union([nominal("Integer"), nominal("String")])]))
      end

      specify "hash with kwsplat" do
        snippet = <<-END
        x = { "foo" => 42 }
        {
          bar: "nananana",
          **x,
        }
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Hash", [union([nominal("Symbol"), nominal("String")]), union([nominal("String"), nominal("Integer")])]))
      end
    end

    describe "ranges" do
      specify "range" do
        snippet = <<-END
        (2..4)
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Range", [nominal("Integer")]))
      end
    end

    describe "local variables" do
      specify "local variable assignment" do
        snippet = <<-END
        x = 42
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end

      specify "simple lvar reference" do
        snippet = <<-END
        x = 42
        x
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end
    end

    describe "instance variables" do
      specify "usage of uninitialized instance variable" do
        snippet = <<-END
        class Foo
          def bar
            @baz
          end
        end
        END

        result = full_type_snippet(snippet)

        expect(find_by_node(result, :ivar_definition)).to eq(bottom)
      end

      specify "assignment of instance variable" do
        snippet = <<-END
        class Foo
          def bar
            @baz = 42
          end
        end
        END

        result = full_type_snippet(snippet)

        expect(find_by_node(result, :ivar_definition)).to eq(nominal("Integer"))
      end

      specify "usage of instance variable" do
        snippet = <<-END
        class Foo
          def foo
            @baz = 42
          end

          def bar
            @baz
          end
        end
        END

        result = full_type_snippet(snippet)

        expect(find_by_node(result, :ivar, { var_name: "@baz" })).to eq(nominal("Integer"))
      end

      specify "distinguish instance variables from class level instance variables" do
        snippet = <<-END
        class Fizz
          @baz = 42

          def setting_baz
            @baz = "foo"
          end

          def getting_baz
            @baz
          end
        end
        END

        result = full_type_snippet(snippet)

        expect(find_by_node(result, :ivar_definition)).to eq(nominal("String"))
        expect(find_by_node(result, :clivar_definition)).to eq(nominal("Integer"))
      end

      specify "usage of instance variable inside selfed method" do
        snippet = <<-END
        class Foo
          @baz = 42

          def self.bar
            @baz
          end
        end
        END

        result = full_type_snippet(snippet)

        expect(find_by_node(result, :ivar, { var_name: "@baz" })).to eq(nominal("Integer"))
      end
    end

    describe "class variables" do
      specify "usage of uninitialized class variable" do
        snippet = <<-END
        class Foo
          def bar
            $x = @@baz
          end
        end
        $x
        END

        result = type_snippet(snippet)
        expect(result).to eq(bottom)
      end

      specify "assignment of class variable" do
        snippet = <<-END
        class Foo
          def bar
            $x = (@@baz = 42)
          end
        end
        $x
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end

      specify "usage of class variable" do
        snippet = <<-END
        class Foo
          def foo
            @@baz = 42
          end

          def bar
            $x = @@baz
          end
        end
        $x
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end
    end

    describe "global variables" do
      specify "usage of global variable" do
        snippet = <<-END
        $baz
        END

        result = type_snippet(snippet)

        expect(result).to eq(bottom)
      end

      specify "assignment and usage of global variable" do
        snippet = <<-END
        $baz = 42
        $baz
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end

      specify "nth-ref global variables" do
        snippet = <<-END
        $1
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("String"))
      end

      specify "back-ref global variables" do
        snippet = <<-END
        $`
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("String"))
      end
    end

    describe "defined?" do
      specify "handle defined?" do
        snippet = <<-END
        defined?(x)
        END

        result = type_snippet(snippet)

        expect(result).to eq(union([nominal("String"), nominal("Nil")]))
      end
    end

    describe "constants" do
      specify "assignment to constant" do
        snippet = <<-END
        Foo = 42
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end

      specify "constant reference" do
        snippet = <<-END
        Foo = 42
        Foo
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end
    end

    describe "self" do
      specify "self without class" do
        snippet = <<-END
        self
        END

        result = type_snippet(snippet)

        expect(result).to eq(main)
      end

      specify "self inside class" do
        snippet = <<-END
        class Foo
          def self.bar
            $x = self
          end
        end
        $x
        END

        result = type_snippet(snippet)

        expect(result).to eq(klass("Foo"))
      end

      specify "self inside instance" do
        snippet = <<-END
        class Foo
          def bar
            self
          end
        end
        Foo.new.bar
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Foo"))
      end
    end

    describe "and/or" do
      specify "MISBEHAVIOUR - simple and" do
        snippet = <<-END
        (42 and 42.0)
        END

        result = type_snippet(snippet)

        # expect(result).to eq(union([nominal("Float"), nominal("Boolean"), nominal("Nil")]))
        expect(result).to eq(union([nominal("Integer"), nominal("Float"), nominal("Boolean"), nominal("Nil")]))
      end

      specify "simple or" do
        snippet = <<-END
        (42 or 42.0)
        END

        result = type_snippet(snippet)

        expect(result).to eq(union([nominal("Integer"), nominal("Float"), nominal("Boolean"), nominal("Nil")]))
      end
    end

    describe "custom built-ins Array" do
      specify "Array#map without a block" do
        snippet = <<-END
        x = [1,2]
        x.map
        END

        result = type_snippet(snippet)

        expect(result).to eq(bottom)
      end

      specify "Array#map with simple block" do
        snippet = <<-END
        x = [1,2]
        x.map {|y| y }
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [nominal("Integer")]))
      end

      specify "MISBEHAVIOUR - Array#map - passing block by blockarg" do
        snippet = <<-END
        x = [1,2]
        y = ->(y) { y.to_s }
        x.map(&y)
        END

        result = type_snippet(snippet)

        expect(result).to eq(bottom)
      end

      specify "Array#each without a block" do
        snippet = <<-END
        x = [1,2]
        x.each {|y| y.to_s }
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [nominal("Integer")]))
      end

      specify "Array#each" do
        snippet = <<-END
        x = [1,2]
        x.each {|y| y.to_s }
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [nominal("Integer")]))
      end
    end

    describe "custom built-ins Object" do
      specify "class on nominal self" do
        snippet = <<-END
        class Foo
          def with_something
            self.class.new
          end
        end
        x = Foo.new.with_something
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Foo"))
      end

      specify "class on nominal" do
        snippet = <<-END
        class Foo
        end
        Foo.new.class
        END

        result = type_snippet(snippet)

        expect(result).to eq(klass("Foo"))
      end

      specify "class on generic" do
        snippet = <<-END
        [].class
        END

        result = type_snippet(snippet)

        expect(result).to eq(klass("Array"))
      end

      specify "class on class" do
        snippet = <<-END
        [].class.class
        END

        result = type_snippet(snippet)

        expect(result).to eq(klass("Class"))
      end

      specify "class on union" do
        snippet = <<-END
        x = if something?
          []
        else
          {}
        end
        x.class
        END

        result = type_snippet(snippet)

        expect(result).to eq(union([klass("Array"), klass("Hash")]))
      end

      specify "MISBEHAVIOUR - class on main" do
        snippet = <<-END
        self.class
        END

        result = type_snippet(snippet)

        # expect(result).to eq(klass("Object"))
        expect(result).to eq(bottom)
      end

      specify "clone is id" do
        snippet = <<-END
        [1,2,3].clone
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [nominal("Integer")]))
      end

      specify "dup is id" do
        snippet = <<-END
        [1,2,3].dup
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [nominal("Integer")]))
      end

      specify "freeze is id" do
        snippet = <<-END
        [1,2,3].freeze
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [nominal("Integer")]))
      end

      specify "itself is id" do
        snippet = <<-END
        [1,2,3].itself
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [nominal("Integer")]))
      end

      specify "taint is id" do
        snippet = <<-END
        [1,2,3].taint
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [nominal("Integer")]))
      end

      specify "trust is id" do
        snippet = <<-END
        [1,2,3].trust
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [nominal("Integer")]))
      end

      specify "untaint is id" do
        snippet = <<-END
        [1,2,3].untaint
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [nominal("Integer")]))
      end

      specify "untrust is id" do
        snippet = <<-END
        [1,2,3].untrust
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [nominal("Integer")]))
      end
    end

    describe "constructors" do
      specify "constructor call" do
        snippet = <<-END
        class Foo
        end
        Foo.new
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Foo"))
      end

      specify "constructor call with argument" do
        snippet = <<-END
        class Foo
          def initialize(foo)
            @foo = foo
          end
        end
        Foo.new(42)
        END

        result = full_type_snippet(snippet)
        expect(find_by_node(result, :ivar_definition)).to eq(nominal("Integer"))

        final_result = type_snippet(snippet)
        expect(final_result).to eq(nominal("Foo"))
      end

      specify "calling constructor from parent class" do
        snippet = <<-END
        class Foo
          def initialize(foo)
            @foo = foo
          end
        end
        class Bar < Foo
        end
        Bar.new(42)
        END

        result = full_type_snippet(snippet)

        expect(find_by_node(result, :ivar_definition)).to eq(nominal("Integer"))
      end

      specify "constructor within module" do
        snippet = <<-END
        module Foo
          class Bar
            def initialize(foo)
              @foo = foo
            end
          end
        end
        module Foo
          x = Bar.new(42)
        end
        END

        result = full_type_snippet(snippet)
        expect(find_by_node(result, :ivar_definition)).to eq(nominal("Integer"))
      end
    end

    describe "calling user-defined methods arguments" do
      specify "no args defined, no args passed" do
        snippet = <<-END
        class Foo
          def bar
            42
          end
        end
        Foo.new.bar
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end

      specify "one arg defined, one arg passed" do
        snippet = <<-END
        class Foo
          def bar(x)
            x.succ
          end
        end
        Foo.new.bar(42)
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end

      specify "two args defined, two args passed" do
        snippet = <<-END
        class Foo
          def bar(x, y)
            y
          end
        end
        Foo.new.bar(42, "str")
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("String"))
      end

      specify "one arg defined, two args passed" do
        snippet = <<-END
        class Foo
          def bar(x)
            x
          end
        end
        Foo.new.bar(42, "foo")
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end

      specify "two arg defined, one arg passed" do
        snippet = <<-END
        class Foo
          def bar(x, y)
            x
          end
        end
        Foo.new.bar(42)
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end

      specify "one opt arg defined, no args passed" do
        snippet = <<-END
        class Foo
          def bar(x = 42)
            x
          end
        end
        Foo.new.bar
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end

      specify "one opt arg defined, one arg passed" do
        snippet = <<-END
        class Foo
          def bar(x = 42)
            x
          end
        end
        Foo.new.bar("foo")
        END

        result = type_snippet(snippet)

        expect(result).to eq(union([nominal("Integer"), nominal("String")]))
      end

      specify "one splat arg defined, two arg passed" do
        snippet = <<-END
        class Foo
          def bar(*args)
            args
          end
        end
        Foo.new.bar("foo", 42)
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [union([nominal("String"), nominal("Integer")])]))
      end

      specify "one unnamed splat arg defined, two arg passed" do
        snippet = <<-END
        class Foo
          def bar(*)
          end
        end
        Foo.new.bar("foo", 42)
        END

        expect do
          type_snippet(snippet)
        end.not_to raise_error
      end

      specify "one named argument defined, one named argument passed" do
        snippet = <<-END
        class Foo
          def bar(x:)
            x
          end
        end
        Foo.new.bar(x: 42)
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end

      specify "two named args defined, two named args passed" do
        snippet = <<-END
        class Foo
          def bar(x:, y:)
            y
          end
        end
        Foo.new.bar(x: 42, y: "foo")
        END

        result = type_snippet(snippet)

        expect(result).to eq(union([nominal("Integer"), nominal("String")]))
      end

      specify "one named argument defined, one other named argument passed MISBEHAVIOUR" do
        snippet = <<-END
        class Foo
          def bar(y:)
            y
          end
        end
        Foo.new.bar(x: 42)
        END

        result = type_snippet(snippet)

        # expect(result).to eq(bottom)
        expect(result).to eq(nominal("Integer"))
      end

      specify "one arg one named arg defined, one arg one named arg passed pt1" do
        snippet = <<-END
        class Foo
          def bar(y, x:)
            y
          end
        end
        Foo.new.bar("foo", x: 42)
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("String"))
      end

      specify "one arg one named arg defined, one arg one named arg passed pt2" do
        snippet = <<-END
        class Foo
          def bar(y, x:)
            x
          end
        end
        Foo.new.bar("foo", x: 42)
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end

      specify "keyword splat defined, two named args passed" do
        snippet = <<-END
        class Foo
          def bar(**kwargs)
            kwargs
          end
        end
        Foo.new.bar(x: 42, y: "foo")
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Hash", [nominal("Symbol"), union([nominal("Integer"), nominal("String")])]))
      end

      specify "unnamed keyword splat defined, one named arg passed" do
        snippet = <<-END
        class Foo
          def bar(**)
          end
        end
        Foo.new.bar(x: 42)
        END

        expect do
          type_snippet(snippet)
        end.not_to raise_error
      end

      specify "unnamed splat and unnamed keyword splat defined, args passed" do
        snippet = <<-END
        class Foo
          def bar(*, **)
          end
        end
        Foo.new.bar("foo", 42, x: 42)
        END

        expect do
          type_snippet(snippet)
        end.not_to raise_error
      end

      specify "one named opt arg defined, one named arg passed" do
        snippet = <<-END
        class Foo
          def bar(x: "foo")
            x
          end
        end
        Foo.new.bar(x: 42)
        END

        result = type_snippet(snippet)

        expect(result).to eq(union([nominal("String"), nominal("Integer")]))
      end

      specify "one named opt arg defined, no args passed" do
        snippet = <<-END
        class Foo
          def bar(x: "foo")
            x
          end
        end
        Foo.new.bar
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("String"))
      end

      specify "one opt arg and one opt named arg defined, no args passed" do
        snippet = <<-END
        class Foo
          def bar(y = 42, z: "foo")
            z
          end
        end
        Foo.new.bar
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("String"))
      end

      specify "one arg defined, splat arg passed" do
        snippet = <<-END
        class Foo
          def bar(x)
            x
          end
        end
        a = [1]
        Foo.new.bar(*a)
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end

      specify "two args defiend, splat arg passed" do
        snippet = <<-END
        class Foo
          def bar(x, y)
            y
          end
        end
        a = [1]
        Foo.new.bar(*a)
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end

      specify "two args defined, two splat args passed" do
        snippet = <<-END
        class Foo
          def bar(x, y)
            y
          end
        end
        a = [1]
        b = ["foo"]
        Foo.new.bar(*a, *b)
        END

        result = type_snippet(snippet)

        expect(result).to eq(union([nominal("String"), nominal("Integer")]))
      end

      specify "one arg and one splat arg defined, two splat args passed" do
        snippet = <<-END
        class Foo
          def bar(x, *y)
            y
          end
        end
        a = [1]
        b = ["foo"]
        Foo.new.bar(*a, *b)
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [union([nominal("String"), nominal("Integer")])]))
      end

      specify "one splat arg and one arg defined, two splat args passed" do
        snippet = <<-END
        class Foo
          def bar(*y, z)
            z
          end
        end
        a = [1]
        b = ["foo"]
        Foo.new.bar(*a, *b)
        END

        result = type_snippet(snippet)

        expect(result).to eq(union([nominal("String"), nominal("Integer")]))
      end
    end

    describe "calling user-defined methods - blocks" do
      specify "simple block" do
        snippet = <<-END
        class Foo
          def bar
            yield 42
          end
        end
        Foo.new.bar do |x|
          $res = x
        end
        $res
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end

      specify "method with more than one yield" do
        snippet = <<-END
        class Foo
          def bar
            yield 42
            yield "foo"
          end
        end
        Foo.new.bar do |x|
          x
        end
        END

        result = full_type_snippet(snippet)

        expect(find_by_node(result, :lvar, { var_name: "x" })).to eq(union([nominal("Integer"), nominal("String")]))
      end

      specify "handling yield result" do
        snippet = <<-END
        class Foo
          def bar
            $res = yield 42
          end
        end
        Foo.new.bar do |x|
          "foo"
        end
        $res
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("String"))
      end

      specify "call method with block with 2 args" do
        snippet = <<-END
        class Foo
          def bar
            yield 42, "foo"
          end
        end
        Foo.new.bar do |x, y|
          $x = x
        end
        $x
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end

      specify "call method with block with 2 args 2" do
        snippet = <<-END
        class Foo
          def bar
            yield 42, "foo"
          end
        end
        Foo.new.bar do |x, y|
          $x = y
        end
        $x
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("String"))
      end

      specify "call method with block with 2 args and one named" do
        snippet = <<-END
        class Foo
          def bar
            yield 42, "foo", foo: 42.0
          end
        end
        Foo.new.bar do |x, y, foo:|
          $res = foo
        end
        $res
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Float"))
      end

      specify "call method with block with splat" do
        snippet = <<-END
        class Foo
          def bar
            yield 42, "foo", :bar
          end
        end
        Foo.new.bar do |x, *y|
          $x = y
        end
        $x
        END

        result = type_snippet(snippet)

        expect(result).to eq(generic("Array", [union([nominal("String"), nominal("Symbol")])]))
      end

      specify "call method with yield with splat with block pt1" do
        snippet = <<-END
        class Foo
          def bar
            arr = ["foo", :bar]
            yield 42, *arr
          end
        end
        Foo.new.bar do |x, y, z|
          $res = y
        end
        $res
        END

        result = type_snippet(snippet)

        expect(result).to eq(union([nominal("String"), nominal("Symbol")]))
      end

      specify "call method with yield with splat with block pt2" do
        snippet = <<-END
        class Foo
          def bar
            arr = ["foo", :bar]
            yield 42, *arr
          end
        end
        Foo.new.bar do |x, y, z|
          $res = z
        end
        $res
        END

        result = type_snippet(snippet)

        expect(result).to eq(union([nominal("String"), nominal("Symbol")]))
      end

      specify "call method with block with optional argument" do
        snippet = <<-END
        class Foo
          def bar
            yield 42
          end
        end
        Foo.new.bar do |x, y = "foo"|
          $x = y
        end
        $x
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("String"))
      end

      specify "call method with blockarg" do
        snippet = <<-END
        class Bar
          def foo
            $res = yield 42
          end
        end
        y = ->(y) { y.to_s }
        Bar.new.foo(&y)
        $res
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("String"))
      end

      specify "call method with blockarg, more than one lambda possible" do
        snippet = <<-END
        class Bar
          def foo
            $res = yield 42
          end
        end
        y = if random
          ->(y) { "foo" }
        else
          ->(y) { :foo }
        end
        Bar.new.foo(&y)
        $res
        END

        result = type_snippet(snippet)

        expect(result).to eq(union([nominal("String"), nominal("Symbol")]))
      end

      specify "call method with stupid blockarg" do
        snippet = <<-END
        class Bar
          def foo
            $res = yield 42
          end
        end
        y = 78
        Bar.new.foo(&y)
        $res
        END

        result = type_snippet(snippet)

        expect(result).to eq(bottom)
      end
    end

    describe "calling user-defined methods call objects" do
      specify "method call to self" do
        snippet = <<-END
        class Foo
          def bar
            self.baz
          end

          def baz
            42
          end
        end
        Foo.new.bar
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end


      specify "method call from parent class" do
        snippet = <<-END
        class Foo
          def foo
            42
          end
        end
        class Bar < Foo
        end
        Bar.new.foo
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end

      specify "call to missing class method" do
        snippet = <<-END
        class Foo
        end
        Foo.bar
        END

        result = type_snippet(snippet)

        expect(result).to eq(bottom)
      end

      specify "call to class method" do
        snippet = <<-END
        class Foo
          def self.bar
            42
          end
        end
        Foo.bar
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end
    end

    describe "attr_reader/writer/accessor" do
      specify "simple attr_reader" do
        snippet = <<-END
        class Foo
          def initialize(x)
            @bar = x
          end

          attr_reader :bar
        end
        Foo.new(42).bar
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end

      specify "simple attr_writer" do
        snippet = <<-END
        class Foo
          attr_reader :bar
          attr_writer :bar
        end
        y = Foo.new
        y.bar = 42
        y.bar
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end
    end

    describe "super calls" do
      specify "basic example" do
        snippet = <<-END
        class Parent
          def foo(x)
            x.to_s
          end
        end
        class Child < Parent
          def foo(x)
            super(x)
          end
        end
        Child.new.foo(42)
        END
        result = type_snippet(snippet)

        expect(result).to eq(nominal("String"))
      end

      specify "example in constructor" do
        snippet = <<-END
        class Parent
          def initialize(x)
            x.to_s
          end
        end
        class Child < Parent
          def initialize(x)
            $y = super(x)
          end
        end
        Child.new(42)
        $y
        END

        result = type_snippet(snippet)

        expect(result).to eq(nominal("String"))
      end

      specify "example when no parent call" do
        snippet = <<-END
        class Parent
        end
        class Child < Parent
          def foo(x)
            super(x)
          end
        end
        Child.new.foo(42)
        END

        expect do
          type_snippet(snippet)
        end.not_to raise_error
      end

      specify "passing block" do
        snippet = <<-END
        class Parent
          def foo()
            yield 42
          end
        end
        class Child < Parent
          def foo()
            super() do |y|
              $res = y
            end
          end
        end
        Child.new.foo
        $res
        END
        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end

      specify "passing block - testing yield result" do
        snippet = <<-END
        class Parent
          def foo()
            $res = yield 42
          end
        end
        class Child < Parent
          def foo()
            super() do |y|
              "foo"
            end
          end
        end
        Child.new.foo
        $res
        END
        result = type_snippet(snippet)

        expect(result).to eq(nominal("String"))
      end
    end

    describe "loop operators" do
      specify "break" do
        snippet = <<-END
        while foo
          $x = break
        end
        $x
        END
        result = type_snippet(snippet)

        expect(result).to eq(bottom)
      end

      specify "redo" do
        snippet = <<-END
        while foo
          $x = redo
        end
        $x
        END
        result = type_snippet(snippet)

        expect(result).to eq(bottom)
      end

      specify "next" do
        snippet = <<-END
        while foo
          $x = next
        end
        $x
        END
        result = type_snippet(snippet)

        expect(result).to eq(bottom)
      end
    end

    describe "exceptions" do
      specify "rescue" do
        snippet = <<-END
        begin
          42
        rescue
          "foo"
        end
        END
        result = type_snippet(snippet)

        expect(result).to eq(union([nominal("String"), nominal("Integer")]))
      end

      specify "else" do
        snippet = <<-END
        begin
          42
        rescue
          "foo"
        else
          :bar
        end
        END
        result = type_snippet(snippet)

        expect(result).to eq(union([nominal("String"), nominal("Symbol")]))
      end

      specify "ensure" do
        snippet = <<-END
        begin
          42
        rescue
          "foo"
        else
          :bar
        ensure
          42.0
        end
        END
        result = type_snippet(snippet)

        expect(result).to eq(union([nominal("String"), nominal("Symbol")]))
      end

      specify "retry" do
        snippet = <<-END
        begin
          42
        rescue
          $x = retry
        end
        $x
        END
        result = type_snippet(snippet)

        expect(result).to eq(bottom)
      end

      specify "assigned error" do
        snippet = <<-END
        begin
          42
        rescue RuntimeError => e
          $x = e
        end
        $x
        END
        result = type_snippet(snippet)

        expect(result).to eq(nominal("RuntimeError"))
      end

      specify "assigned errors" do
        snippet = <<-END
        begin
          42
        rescue RuntimeError, ArgumentError => e
          $x = e
        end
        $x
        END
        result = type_snippet(snippet)

        expect(result).to eq(union([nominal("RuntimeError"), nominal("ArgumentError")]))
      end

      specify "assigned any error" do
        snippet = <<-END
        begin
          42
        rescue => e
          $x = e
        end
        $x
        END
        result = type_snippet(snippet)

        expect(result).to eq(nominal("StandardError"))
      end
    end

    describe "if" do
      specify "if-else" do
        snippet = <<-END
        if foo
          42
        else
          42.0
        end
        END
        result = type_snippet(snippet)

        expect(result).to eq(union([nominal("Integer"), nominal("Float")]))
      end

      specify "only iftrue" do
        snippet = <<-END
        if foo
          42
        end
        END
        result = type_snippet(snippet)

        expect(result).to eq(union([nominal("Integer"), nominal("Nil")]))
      end

      specify "only iffalse" do
        snippet = <<-END
        unless foo
          42
        end
        END
        result = type_snippet(snippet)

        expect(result).to eq(union([nominal("Nil"), nominal("Integer")]))
      end
    end

    describe "case..when" do
      specify "basic" do
        snippet = <<-END
        case foo
        when bar then 42
        when baz then 42.0
        else "foo"
        end
        END
        result = type_snippet(snippet)

        expect(result).to eq(union([nominal("Integer"), nominal("Float"), nominal("String")]))
      end
    end

    describe "zsuper calls" do
      specify "basic example" do
        snippet = <<-END
        class Parent
          def foo(x)
            x.to_s
          end
        end
        class Child < Parent
          def foo(x)
            super
          end
        end
        Child.new.foo(42)
        END
        result = type_snippet(snippet)

        expect(result).to eq(nominal("String"))
      end

      specify "constructor example" do
        snippet = <<-END
        class Parent
          def initialize(x)
            x
          end
        end
        class Child < Parent
          def initialize(x)
            $x = super
          end
        end
        Child.new(42)
        $x
        END
        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end

      specify "when can't find super" do
        snippet = <<-END
        class Child
          def foo(x)
            super
          end
        end
        Child.new.foo(42)
        END
        result = type_snippet(snippet)

        expect(result).to eq(bottom)
      end

      specify "passing block" do
        snippet = <<-END
        class Parent
          def foo
            yield 42
          end
        end
        class Child < Parent
          def foo
            super
          end
        end
        Child.new.foo do |y|
          $res = y
        end
        $res
        END
        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end

      specify "overriding block pt1" do
        snippet = <<-END
        class Parent
          def foo
            yield 42
          end
        end
        class Child < Parent
          def foo
            super do |y|
              $res = y
            end
          end
        end
        Child.new.foo do |y|
          y
        end
        $res
        END
        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end

      specify "overriding block pt2" do
        snippet = <<-END
        class Parent
          def foo
            yield 42
          end
        end
        class Child < Parent
          def foo
            super do |y|
              y
            end
          end
        end
        Child.new.foo do |y|
          $res = y
        end
        $res
        END
        result = type_snippet(snippet)

        expect(result).to eq(bottom)
      end
    end

    describe "lambdas" do
      specify "simple one pt1" do
        snippet = <<-END
        l = ->(x) { $res = x }
        l.(42)
        $res
        END
        result = type_snippet(snippet)

        expect(result).to eq(nominal("Integer"))
      end

      specify "simple one pt2" do
        snippet = <<-END
        l = ->(x) { x.to_s }
        l.(42)
        END
        result = type_snippet(snippet)

        expect(result).to eq(nominal("String"))
      end
    end

    def type_snippet(snippet)
      worklist = Worklist.new
      graph = Graph.new
      tree = GlobalTree.new
      DefineBuiltins.new(graph, tree).()
      result = Builder.new(graph, worklist, tree).process_file(snippet, nil)
      typing_result = TypingService.new(Logger.new(nil)).(graph, worklist, tree)
      typing_result[result.node]
    end

    def full_type_snippet(snippet)
      worklist = Worklist.new
      graph = Graph.new
      tree = GlobalTree.new
      result = Builder.new(graph, worklist, tree).process_file(snippet, nil)
      TypingService.new(Logger.new(nil)).(graph, worklist, tree)
    end

    def nominal(*args)
      NominalType.new(*args)
    end

    def union(*args)
      UnionType.new(*args)
    end

    def generic(*args)
      GenericType.new(*args)
    end

    def klass(*args)
      ClassType.new(*args)
    end

    def main
      MainType.new
    end

    def bottom
      BottomType.new
    end

    def find_by_node(result, node_type, node_params = {})
      result.find {|k,v| k.type == node_type && k.params == node_params }.last
    end
  end
end
