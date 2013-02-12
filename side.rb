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

end