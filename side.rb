require File.dirname(__FILE__) + '/row_regex'
require File.dirname(__FILE__) + '/row'

class Side
  attr_reader :row_regexs, :hex_rows, :id
  @@NEXT_SIDE_ID = 0

  def initialize
    @row_regexs = []
    @hex_rows   = []
    @id         = @@NEXT_SIDE_ID
    @@NEXT_SIDE_ID += 1
  end

  def add_row(row_regex)
    @row_regexs << row_regex
  end

  def last_row
    @row_regexs.last
  end

  def to_s
    if @hex_rows.nil? or @hex_rows.empty?
      @row_regexs.map{|r| r.to_s}.join("\n")    
    else
      @hex_rows.map{|r| r.to_s}.join("\n")
    end
  end 

  def populate_hex(previous_side=nil)
      if previous_side.nil?
        # generate the initial cells
        num_rows = @row_regexs.length
        minimum_row_length = (num_rows / 2).to_i + 1

        @hex_rows = @row_regexs.each_with_index.map {|row_regex, i| 
          row_length = i + minimum_row_length
          if i >= minimum_row_length
            row_length = num_rows + minimum_row_length -1 - i
          end
          Row.new(@id, row_regex, row_length)
        }
      else
        # copy from the previous side's cells
          @hex_rows = @row_regexs.each_with_index.map {|row_regex, i| Row.new(@id, row_regex, i, previous_side.hex_rows)}
      end
  end
end