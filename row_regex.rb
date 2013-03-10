class Row_regex
  attr_reader :full, :partials

  @@DEFAULT_PATTERN = '.*'

  def self.decorate( regex )
    '/' + regex.source + '/'
  end

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
    Row_regex.decorate(@full) + " : " + @partials.map{|partial| Row_regex.decorate(partial) }.join(", ")
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

  def score_breakdown(string)
    scores = []
    scores << [@full, ! @full.match(string).nil? ]
    @partials.each{ |regex| scores << [regex, ! regex.match(string).nil?] }
    return scores
  end

  def score_breakdown_to_s(string)
    scores = score_breakdown(string)

    scores.map { |s| 
      extra_text = ''
      extra_text = '==' + s[1].to_s if s[1]
      Row_regex.decorate(s[0]) + extra_text }.join(', ')
  end
end