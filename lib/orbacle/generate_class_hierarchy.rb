module Orbacle
  class GenerateClassHierarchy
    def initialize(db)
      @db = db
    end

    def call
      klasslikes = @db
        .find_all_klasslikes
        .select {|kl| kl.type == "klass" }
        .map do |kl|
          {
            scope: kl.scope,
            name: kl.name,
            inheritance: kl.inheritance,
            nesting: kl.nesting,
          }
        end

      klasslikes.each do |kl|
        if kl[:inheritance].nil?
          kl[:real_inheritance] = "Object"
        elsif kl[:inheritance].start_with?("::")
          kl[:real_inheritance] = kl[:inheritance][2..-1]
        else
          possible_parents = kl[:nesting].each_index.map do |i|
            [nesting_to_scope(kl[:nesting][0..i]), kl[:inheritance]].compact.join("::")
          end
          possible_parents.unshift(kl[:inheritance])
          possible_parents2 = possible_parents.map do |parent|
            scope = parent.split("::")[0..-2].join("::")
            scope = nil if scope == ""
            name = parent.split("::").last
            klasslikes.find do |kkl|
              kkl[:scope] == scope && kkl[:name] == name
            end
          end.compact
          chosen_real_inheritance = possible_parents2.last

          if chosen_real_inheritance
            kl[:real_inheritance] = [chosen_real_inheritance[:scope], chosen_real_inheritance[:name]].compact.join("::")
          end
        end
      end

      klasslikes

      File.open("output.dot", "w") do |f|
        f.puts "digraph cha {"
        f.puts "  Object [shape=record,label=\"Object\"]"

        klasslikes.each do |kl|
          full_name = [kl[:scope], kl[:name]].compact.join("::")
          f.puts "  #{full_name.gsub(":","_")} [shape=record,label=\"#{full_name}\"]"
        end

        klasslikes.each do |kl|
          full_name = [kl[:scope], kl[:name]].compact.join("::")
          if kl[:real_inheritance]
            f.puts "  #{full_name.gsub(":", "_")} -> #{kl[:real_inheritance].gsub(":", "_")}"
          else
            f.puts "  #{kl[:inheritance].gsub(":", "_")} [label=\"#{kl[:inheritance]}\"]"
            f.puts "  #{full_name.gsub(":", "_")} -> #{kl[:inheritance].gsub(":", "_")}"
            f.puts "  #{kl[:inheritance].gsub(":", "_")} -> Object"
          end
        end
        f.puts "}"
      end

      klasslikes
    end

    def nesting_to_scope(nesting)
      return nil if nesting.empty?

      nesting.map do |_type, pre, name|
        pre + [name]
      end.join("::")
    end

    def scope_from_nesting_and_prename(nesting, prename)
      scope_from_nesting = nesting_to_scope(nesting)
      result = [scope_from_nesting, prename].compact.join("::")
      result if !result.empty?
    end
  end
end
