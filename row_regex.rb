class Row_regex
  @@DEFAULT_PATTERN = '.*'

  def initialize( pattern = @@DEFAULT_PATTERN )
    @full = Regexp.new( '^' + pattern + '$' )
    @partials = []
  end

  def add_partial_left(pattern = @@DEFAULT_PATTERN)
    @partials << Regexp.new( '^' + pattern )
  end

  def add_partial_right(pattern = @@DEFAULT_PATTERN)
    @partials << Regexp.new( pattern + '$' )
  end

end