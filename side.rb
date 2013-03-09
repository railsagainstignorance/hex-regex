require File.dirname(__FILE__) + '/row_regex'
require File.dirname(__FILE__) + '/row'

class Side
  attr_reader :row_regexs, :hex_rows

  def initialize
    @row_regexs = []
    @hex_rows   = []
  end

  def add_row(row_regex)
    @row_regexs << row_regex
  end

  def last_row
    @row_regexs.last
  end

  def to_s
    if @hex_rows.nil? or @hex_rows.empty?
      (0..@row_regexs.length-1).map{|i| (i+1).to_s + ') ' + @row_regexs[i].to_s}.join("\n")    
    else
      (0..@hex_rows.length-1).map{|i| (i+1).to_s + ') ' + @hex_rows[i].to_s}.join("\n")
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
          Row.new( row_regex, row_length)
        }
      else
        # copy from the previous side's cells
          @hex_rows = @row_regexs.each_with_index.map {|row_regex, i| Row.new(row_regex, i, previous_side.hex_rows)}
      end
  end
end