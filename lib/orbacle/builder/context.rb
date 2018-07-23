# frozen_string_literal: true

module Orbacle
  class Builder
    class Context
      AnalyzedKlass = Struct.new(:klass_id, :method_visibility)

      def initialize(filepath, selfie, nesting, analyzed_klass, analyzed_method, lenv)
        @filepath = filepath.freeze
        @selfie = selfie.freeze
        @nesting = nesting.freeze
        @analyzed_klass = analyzed_klass.freeze
        @analyzed_method = analyzed_method.freeze
        @lenv = lenv.freeze
      end

      attr_reader :filepath, :selfie, :nesting, :analyzed_klass, :analyzed_method, :lenv

      def with_selfie(new_selfie)
        self.class.new(filepath, new_selfie, nesting, analyzed_klass, analyzed_method, lenv)
      end

      def with_nesting(new_nesting)
        self.class.new(filepath, selfie, new_nesting, analyzed_klass, analyzed_method, lenv)
      end

      def scope
        nesting.to_scope
      end

      def with_analyzed_klass(new_klass_id)
        self.class.new(filepath, selfie, nesting, AnalyzedKlass.new(new_klass_id, :public), analyzed_method, lenv)
      end

      def with_visibility(new_visibility)
        self.class.new(filepath, selfie, nesting, AnalyzedKlass.new(analyzed_klass.klass_id, new_visibility), analyzed_method, lenv)
      end

      def with_analyzed_method(new_analyzed_method_id)
        self.class.new(filepath, selfie, nesting, analyzed_klass, new_analyzed_method_id, lenv)
      end

      def merge_lenv(new_lenv)
        self.class.new(filepath, selfie, nesting, analyzed_klass, analyzed_method, lenv.merge(new_lenv))
      end

      def lenv_fetch(key)
        lenv.fetch(key, [])
      end

      def with_lenv(new_lenv)
        self.class.new(filepath, selfie, nesting, analyzed_klass, analyzed_method, new_lenv)
      end

      def analyzed_klass_id
        analyzed_klass.klass_id
      end

      def with_merged_lenvs(lenv1, lenv2)
        final_lenv = {}

        var_names = (lenv1.keys + lenv2.keys).uniq
        var_names.each do |var_name|
          final_lenv[var_name] = (lenv1.fetch(var_name, []) + lenv2.fetch(var_name, [])).uniq
        end

        with_lenv(final_lenv)
      end
    end
  end
end
