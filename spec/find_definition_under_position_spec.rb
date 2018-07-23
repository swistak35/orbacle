# frozen_string_literal: true

require 'spec_helper'

module Orbacle
  RSpec.describe FindDefinitionUnderPosition do
    specify "simple case inside class" do
      file = <<-END
      class Foo
        def bar
          Baz.new
        end
      end
      END

      expected_nesting = Nesting
        .empty
        .increase_nesting_const(ConstRef.from_full_name("Foo", Nesting.empty))
      constant_result = FindDefinitionUnderPosition::ConstantResult.new(
        ConstRef.from_full_name("Baz", expected_nesting))
      expect(find_definition_under_position(file, 2, 9)).to be_nil
      expect(find_definition_under_position(file, 2, 10)).to eq(constant_result)
      expect(find_definition_under_position(file, 2, 11)).to eq(constant_result)
      expect(find_definition_under_position(file, 2, 12)).to eq(constant_result)
      expect(find_definition_under_position(file, 2, 13)).to be_nil
    end

    specify "simple case inside module" do
      file = <<-END
      module Foo
        def bar
          Baz.new
        end
      end
      END

      expected_nesting = Nesting
        .empty
        .increase_nesting_const(ConstRef.from_full_name("Foo", Nesting.empty))
      constant_result = FindDefinitionUnderPosition::ConstantResult.new(
        ConstRef.from_full_name("Baz", expected_nesting))
      expect(find_definition_under_position(file, 2, 9)).to be_nil
      expect(find_definition_under_position(file, 2, 10)).to eq(constant_result)
      expect(find_definition_under_position(file, 2, 11)).to eq(constant_result)
      expect(find_definition_under_position(file, 2, 12)).to eq(constant_result)
      expect(find_definition_under_position(file, 2, 13)).to be_nil
    end

    specify "changing nesting" do
      file = <<-END
      class Foo
      end
      class Bar
        def bar
          Baz.new
        end
      end
      END

      expected_nesting = Nesting
        .empty
        .increase_nesting_const(ConstRef.from_full_name("Bar", Nesting.empty))
      constant_result = FindDefinitionUnderPosition::ConstantResult.new(
        ConstRef.from_full_name("Baz", expected_nesting))
      expect(find_definition_under_position(file, 4, 9)).to be_nil
      expect(find_definition_under_position(file, 4, 10)).to eq(constant_result)
      expect(find_definition_under_position(file, 4, 11)).to eq(constant_result)
      expect(find_definition_under_position(file, 4, 12)).to eq(constant_result)
      expect(find_definition_under_position(file, 4, 13)).to be_nil
    end

    specify do
      file = <<-END
      class Foo
        def bar
          ::Bar::Baz.new
        end
      end
      END

      expected_nesting = Nesting
        .empty
        .increase_nesting_const(Orbacle::ConstRef.from_full_name("Foo", Nesting.empty))
      constant_result = FindDefinitionUnderPosition::ConstantResult.new(
        ConstRef.from_full_name("::Bar::Baz", expected_nesting))
      expect(find_definition_under_position(file, 2, 9)).to be_nil
      expect(find_definition_under_position(file, 2, 10)).to eq(constant_result)
      expect(find_definition_under_position(file, 2, 11)).to eq(constant_result)
      expect(find_definition_under_position(file, 2, 12)).to eq(constant_result)
      expect(find_definition_under_position(file, 2, 13)).to eq(constant_result)
      expect(find_definition_under_position(file, 2, 14)).to eq(constant_result)
      expect(find_definition_under_position(file, 2, 15)).to eq(constant_result)
      expect(find_definition_under_position(file, 2, 16)).to eq(constant_result)
      expect(find_definition_under_position(file, 2, 17)).to eq(constant_result)
      expect(find_definition_under_position(file, 2, 18)).to eq(constant_result)
      expect(find_definition_under_position(file, 2, 19)).to eq(constant_result)
      expect(find_definition_under_position(file, 2, 20)).to be_nil
    end

    describe "definition of message send"  do
      specify do
        file = <<-END
        foo.bar(42, "foo")
        END

        message_result = FindDefinitionUnderPosition::MessageResult.new(
          "bar",
          PositionRange.new(Position.new(0, 12), Position.new(0, 14)))
        expect(find_definition_under_position(file, 0, 11)).to eq(nil)
        expect(find_definition_under_position(file, 0, 12)).to eq(message_result)
        expect(find_definition_under_position(file, 0, 13)).to eq(message_result)
        expect(find_definition_under_position(file, 0, 14)).to eq(message_result)
        expect(find_definition_under_position(file, 0, 15)).to eq(nil)
      end
    end

    def find_definition_under_position(file, line, column)
      parser = RubyParser.new
      service = FindDefinitionUnderPosition.new(parser)
      service.process_file(file, Position.new(line, column))
    end
  end
end
