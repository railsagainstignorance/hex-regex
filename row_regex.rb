class Row_regex
  attr_reader :full, :partials

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

  def to_s
    '/' + @full.source + "/ : " + @partials.map{|item| ' /' + item.source + '/'}.join(", ")
  end

  def all_regexs
    [@full].concat(@partials)
  end

  def score(string)
    cumulative_score = 0
    cumulative_score += 1 if @full.match(string)       
    @partials.each{ |regex| cumulative_score += 0.01 if regex.match(string) }
    return cumulative_score
  end
end