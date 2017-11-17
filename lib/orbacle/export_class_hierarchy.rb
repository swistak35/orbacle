module Orbacle
  class ExportClassHierarchy
    def call(tree)
      output_file = "class_hierarchy.dot"

      File.open("output.dot", "w") do |f|
        f.puts "digraph cha {"

        tree.breadth_each do |node|
          if node.content.real
            f.puts "  #{node.name.gsub(":", "_")} [shape=record,label=\"#{node.name}\"]"
          else
            f.puts "  #{node.name.gsub(":", "_")} [label=\"#{node.name}\"]"
          end

          if !node.content.inheritance.nil?
            f.puts "  #{node.name.gsub(":", "_")} -> #{node.parent.name.gsub(":", "_")}"
          end
        end

        f.puts "}"
      end
    end
  end
end
