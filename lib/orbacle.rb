module Orbacle
  Position = Struct.new(:line, :character)
  PositionRange = Struct.new(:start, :end) do
    def include_position?(position)
      if (start_line+1..end_line-1).include?(position.line)
        true
      elsif start_line == position.line && end_line == position.line
        (start_character <= position.character) && (position.character <= end_character)
      elsif start_line == position.line
        start_character <= position.character
      elsif end_line == position.line
        end_character >= position.character
      end
    end

    def end_line
      self.end.line
    end

    def start_line
      self.start.line
    end

    def start_character
      self.start.character
    end

    def end_character
      self.end.character
    end
  end
  class Location < Struct.new(:uri, :position_range, :span)
    def start
      position_range&.start
    end

    def start_line
      start&.line
    end

    def start_character
      start&.character
    end

    def end
      position_range&.end
    end

    def end_line
      self.end&.line
    end

    def end_character
      self.end&.character
    end
  end

  BIG_VALUE = 0b111111100100000010110010110011101010000101010100001100100110001
end

require 'parser/current'

require 'orbacle/ast_utils'
require 'orbacle/bottom_type'
require 'orbacle/builder/context'
require 'orbacle/builder/operator_assignment_processors'
require 'orbacle/builder'
require 'orbacle/class_type'
require 'orbacle/command_line_interface'
require 'orbacle/const_name'
require 'orbacle/const_ref'
require 'orbacle/constants_tree'
require 'orbacle/define_builtins'
require 'orbacle/engine'
require 'orbacle/find_definition_under_position'
require 'orbacle/generic_type'
require 'orbacle/global_tree'
require 'orbacle/graph'
require 'orbacle/indexer'
require 'orbacle/lambda_type'
require 'orbacle/lang_server'
require 'orbacle/main_type'
require 'orbacle/nesting'
require 'orbacle/node'
require 'orbacle/nominal_type'
require 'orbacle/ruby_parser'
require 'orbacle/scope'
require 'orbacle/selfie'
require 'orbacle/type_pretty_printer'
require 'orbacle/typing_service'
require 'orbacle/union_type'
require 'orbacle/uuid_id_generator'
require 'orbacle/worklist'
