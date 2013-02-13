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

    rows_in_first_side = @sides.first.row_regexs.length
    rows_in_second_side = @sides[1].row_regexs.length
    rows_in_third_side = @sides[2].row_regexs.length

    @input_woes << "side 1 has #{rows_in_first_side} rows, but side 2 has #{rows_in_second_side} rows." if rows_in_second_side != rows_in_first_side
    @input_woes << "side 1 has #{rows_in_first_side} rows, but side 3 has #{rows_in_third_side} rows." if rows_in_third_side != rows_in_first_side

    return @input_woes.length == 0
  end

  def summary
  "Full_hex: summary
- #{sides.length} sides
- #{sides.first.row_regexs.length} rows per side
"
  end
end