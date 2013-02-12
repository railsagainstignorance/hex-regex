class Row_regex
  def initialize( pattern )
    @full = Regexp.new( '^' + pattern + '$' )
    @partials = []
  end

  def add_partial_left(pattern)
    @partials << Regexp.new( '^' + pattern )
  end

  def add_partial_right(pattern)
    @partials << Regexp.new( pattern + '$' )
  end

end