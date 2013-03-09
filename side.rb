require File.dirname(__FILE__) + '/row_regex'

class Side
  attr_reader :row_regexs

  def initialize
    @row_regexs = []
  end

  def add_row(row_regex)
    @row_regexs << row_regex
  end

  def last_row
    @row_regexs.last
  end

  def to_s()
    (0..@row_regexs.length-1).map{|i| (i+1).to_s + ') ' + @row_regexs[i].to_s}.join("\n")
  end 

end