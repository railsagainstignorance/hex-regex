require 'singleton'
require File.dirname(__FILE__) + '/side'

class Full_hex
  include Singleton
  attr_reader :sides, :input_woes

  def initialize
    @sides = []
  end

  def add_side( side )
    @sides << side
  end

  def last_side()
    @sides.last
  end

  def all_inputs_validated?
    @input_woes = []
    @input_woes << "Full_hex does not have 3 sides, it has #{@sides.length}." if @sides.length != 3
    return @input_woes.length == 0
  end

  def summary
  "Full_hex: summary
- #{sides.length} sides
- #{sides.first.row_regexs.length} rows per side
"
  end
end