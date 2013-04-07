# genex 
# a home-grown stab at the Perl Regex-Genex library which generates all strings which match the specified regex.
# see the GENEX.md for more info

# where a 'fragment' can be 
#  - a single char, ['A'], 
#  - a list of chars, ['A','B','C'], 
#  - a single/list of word fragments, ['AA','BB','CC'], 
# always passed in as a list, 
# defaulting to the list of all chars, i.e. '.'.

@@NO_MORE=nil
@@ALL_CHARS=('A'..'Z').to_a
	
# FragmentGen: 
# - .initialize with a list of pieces
# - .next will iterate over the list, returning nil when the list is commpleted
# - .current returns the last output from .next
# - .all returns the full list of values

class FragmentGen
	attr_reader :current, :all

	def initialize(fragment_spec)
		@fragment_spec = fragment_spec
		@all           = @fragment_spec[:fragment_pieces]
		@index         = -1 # index points to prev position
		@max_index     = @all.length - 1 if !@all.nil?
	end

	# if this FragmentGen is matching a backreference, look it up (if its the first next), else read from the list of pieces

	def next(backreferences)
		if @fragment_spec[:backreference]
			if @index < 0
				b = @fragment_spec[:backreference]
				@current = backreferences[b - 1] # could be nil
			else
				@current = nil
			end
			@index += 1
		else
			if @index > @max_index
				@current = @@NO_MORE
			else
				@index += 1
				@current = @all[@index]
			end
		end

		return @current
	end

	def to_s
		"FragmentGen: @fragment_spec=#{@fragment_spec}, current=#{self.current or 'nil'}"
	end
end

# FragmentRepeaterElement:
# - .initialize with a fragment_spec (see FragmentParser), and a length, 
#               to create that length list of FragmentGen objects (via a chain of FREs), each initialized with the list of pieces
# - .next will iterate over the list of FragmentGens, tail first, rippling back the .next calls, 
#         returning nil when all the FragmentGens are exhausted

class FragmentRepeaterElement
	attr_reader :current

	def initialize(fragment_spec, repeat_length)
		#puts "DEBUG: FragmentRepeaterElement.new: fragment_spec=#{fragment_spec.to_s}, repeat_length=#{repeat_length}"
		@fragment_spec = fragment_spec
		@repeat_length = repeat_length
		@fragmentGen   = FragmentGen.new(@fragment_spec)
		@is_first_next = true
	end

	# private
	def generate_chain(backreferences = [])
		if @repeat_length > 1 and ! @fragmentGen.next(backreferences).nil?
			#puts "DEBUG: generate_chain: @repeat_length=#{@repeat_length},  @fragmentGen.current=#{ @fragmentGen.current }"
			@repeat_chain = FragmentRepeaterElement.new( @fragment_spec, @repeat_length - 1)
		else
			#puts "DEBUG: generate_chain: @repeat_chain = nil"
			@repeat_chain = nil
		end
	end

	# get the next iteration from the chain, and if that is nil, we iterate locally and generate a new chain
	def next(backreferences)
		#puts "next: @repeat_length=#{@repeat_length}, @repeat_chain=#{@repeat_chain.to_s}, @fragmentGen.current=#{@fragmentGen.current.to_s}"

		if @is_first_next
			generate_chain(backreferences)
			@is_first_next = false
		end

		if @repeat_chain.nil?
			@current = @fragmentGen.next(backreferences)
		else
			chained_fragment = @repeat_chain.next(backreferences)
			if chained_fragment.nil?
				generate_chain(backreferences)
				chained_fragment = @repeat_chain.next(backreferences) if !@repeat_chain.nil?
			end
			
			local_fragment = @fragmentGen.current

			if local_fragment.nil? or chained_fragment.nil?
				@current = nil
			else
				@current = local_fragment + chained_fragment
			end
		end

		#puts "@repeat_length=#{@repeat_length}, @current=#{@current}"
		@current
	end

	def all
		@fragmentGen.all
	end

	def to_s
		"FragmentRepeaterElement: repeat_length=#{@repeat_length}, " + @fragmentGen.to_s + "\n" + @repeat_chain.to_s
	end
end

# nil means end of sequence

# FragmentRepeater:
# - .initialize with a fragment_spec (see FragmentParser for details),
#               where the list of pieces will be passed to a FragmentRepeaterElement (and FragmentGen),
#                     and the repeat char is used to work out how the FRE chain will increase in length as we iterate
#               creating an FRE for the starting length of chain
# - .next will iterate over the chain of FREs until it is exhausted, then iterate over the length of chain until likewise

class FragmentRepeater
	attr_reader :current, :fragment_pieces_ratio

	@@EMPTY_FRAGMENT = ''

	def initialize(fragment_spec)
		@fragment_spec = fragment_spec
		repeat_char = @fragment_spec[:repeat_char]

		case repeat_char
		when nil # for an exact match
			@start_index = 1
			@end_index   = 0
		when '*'
			@start_index = 0
			@end_index   = -1 # keep going 4e4
		when '?'
			@start_index = 0
			@end_index   = 0
		when '+'
			@start_index = 1
			@end_index   = -1 # keep going 4e4
		else 
			abort 'unrecognized repeat_char:' + repeat_char
		end

		@index = @start_index - 1
		@repeater_element = nil

		@fragment_pieces_ratio = 1
		if !@fragment_spec[:fragment_pieces].nil?
			sorted_pieces = @fragment_spec[:fragment_pieces].sort { |x,y| x.length <=> y.length }
			longest  = sorted_pieces.last.length
			shortest = sorted_pieces.first.length
			if shortest > 0
				@fragment_pieces_ratio = longest / shortest
			end	
		end
	end

	def to_s
		"FragmentRepeater: @fragment_spec=#{@fragment_spec}, @start_index=#{@start_index}, @end_index=#{@end_index}, @index=#{@index}, @fragment_pieces_ratio=#{@fragment_pieces_ratio}"
	end

	def next(backreferences)
		#puts "DEBUG: FragmentRepeater.next: @index=#{@index}"
		if @index == -1 # ie we are starting with nothing
			@index += 1
			return @@EMPTY_FRAGMENT
		elsif @end_index >= 0 and @index > @end_index
			return @@NO_MORE
		end

		# if we get here, we are expecting to be generating some fragments

		# make sure we have an initial chain for the current chain length, i.e. @index

		if @repeater_element.nil?
			@repeater_element = FragmentRepeaterElement.new(@fragment_spec, repeat_length=@index+1) # remember the param is for chain length, not the index
		end

		next_fragment = @repeater_element.next(backreferences)

		# if the chain has finished, inc index, reset the chain, and try again

		if next_fragment.nil?
			@index += 1
			@repeater_element = nil
			next_fragment = self.next(backreferences)
		end

		# if we get here, we either have a next_fragment or it is nil (and therefore this FragmentRepeater is finished)

		@current = next_fragment
	end
end


class FragmentParser
	
	# input: regex string e.g. "F(.)*[AO]+\1"
	# output: [ {:fragment_pieces=>['F'], :repeat_char=>nil, :backreference=>false, :capture=>true}, 
	#           {:fragment_pieces=>['A'..'Z'].to_a, :repeat_char=>'*', :backreference=>false, :capture=>true},
	#           {:fragment_pieces=>['A','O'], :repeat_char=>'+', :backreference=>false, :capture=>true},
	#           {:fragment_pieces=>nil, :repeat_char=>nil, :backreference=>1, :capture=>true} ]
	
	# how to parse?  (AA|BBB)
	#                (...?) is the same as .? but where start_index = 2. new param: repeat_from
	#                ([^A]|AAA)   um, tricky.

	@@id = 1

	def self.reset_id
		@@id = 0
	end

	def self.parse_regex(regex_string)
		
		capture = false
		
		anyornoneofchar        ='\[\^?[A-Z]+\]'
		charsoranyornoneofchar ="(?:[A-Z]+|#{anyornoneofchar})"
		sequenceofcharsoranyornoneofchar = "(#{charsoranyornoneofchar}(?:\\|#{charsoranyornoneofchar})*)"
		anyrepeat              ='([*+?])'
		case regex_string
		when ""
			return []
		when /^(\.+|[A-Z]|#{anyornoneofchar}|\\\d)#{anyrepeat}?(.*)$/
			# can parse: ... , [ABC] , [^ABC], \1, with optional modifiers [*+?]
			fragment_string        = $1
			repeat_char            = $2
			remaining_regex_string = $3
		when /^\((\.+)#{anyrepeat}?\)(.*)$/
			# can parse: (...?), i.e. storing the match for later use, with optional modifiers [*+?] within the braces
			fragment_string        = $1
			repeat_char            = $2
			remaining_regex_string = $3
			capture                = true
		when /^\(#{sequenceofcharsoranyornoneofchar}\)#{anyrepeat}?(.*)$/
			# can parse: (AA|BBB), i.e. storing the match for later use, with optional modifiers [*+?]
			fragment_string        = $1
			repeat_char            = $2
			remaining_regex_string = $3
			capture                = true
		else
			abort "ERROR: could not parse regex_string=#{regex_string}"
		end

		backreference = false
		repeat_from = 0
		case fragment_string
		when /^([A-Z])$/
			fragment_pieces = [$1]
		when /^\\(\d)$/
			backreference = $1.to_i
			fragment_pieces = nil
		when /^\[\^([A-Z]+)\]$/
			fragment_pieces = @@ALL_CHARS - $1.split(//)
		when /^\[([A-Z]+)\]$/
			fragment_pieces = $1.split(//)
		when /^(\.+)$/ # specify how many more than 1 dot there are
			dots = $1
			repeat_from = dots.length - 1
			fragment_pieces = @@ALL_CHARS
		when /^#{sequenceofcharsoranyornoneofchar}$/
			fragment_pieces = $1.split(/\|/).map { |piece|
				case piece
				when /^([A-Z]+)$/
					[$1]
				when /^\[\^([A-Z]+)\]$/
					@@ALL_CHARS - $1.split(//)
				when /^\[([A-Z]+)\]$/
					$1.split(//)
				end
			}.flatten
		else
			abort "ERROR: could not parse fragment_string=\'#{fragment_string}\' with repeat_char=\'#{repeat_char}\' in regex_string=\'#{regex_string}\'"
		end

		if ! fragment_pieces.nil?
			fragment_pieces.sort! {|x,y| x.length <=> y.length }
		end

		fragment_spec = {
			:fragment_pieces => fragment_pieces, # a list of strings that could match this fragment
			:repeat_char     => repeat_char,     # the char the indicates how the fragment repeats, possibly nil
			:backreference   => backreference,          # specifies which previously matched value to use (int) or nil
			:capture         => capture,          # is this fragment to be stored for later matching
			:repeat_from     => repeat_from,      # to cover multiple dots, e.g. ..., would have repeat_from=2
			:id              => @@id,
			:fragment_string => fragment_string
		}

		@@id += 1

		return [fragment_spec] + self.parse_regex(remaining_regex_string)
	end
end

# FragmentChainElement:
# - .initialize with a list of fragment_specs
#   - pluck off first spec for self, invoked FCE.initialize with remaining specs (if any)
# - .next with a list of backreferences
#  - generates first string (if needed), append to backreferences if this spec says so
#  - invokes chain's next to get the remaining values
#  - if that is nil, iterate self and try again
#  - concatenate self's value and chain's value and returns that or nil

class FragmentChainElement
	@@FCE_COUNT_MAX = 10000000

	def initialize( fragment_specs )
		# assume param is a clone and can be mucked with
		@fragment_spec 			  = fragment_specs.shift
		@fragment_specs_for_chain = fragment_specs
		@fragment_repeater        = FragmentRepeater.new(@fragment_spec)
		@current                  = nil
		@count_next               = 0
		@fce_chain                = nil
		@should_have_no_chain     = @fragment_specs_for_chain.empty?
		@fragment_pieces_ratio    = @fragment_repeater.fragment_pieces_ratio
	end

	def next(backreferences, remaining_length)
		#puts "DEBUG: FragmentChainElement.next: in :id=#{@fragment_spec[:id]}, :string=#{@fragment_spec[:fragment_string]}, @current=#{@current}, backreferences=#{backreferences}, remaining_length=#{remaining_length}, @count_next=#{@count_next}, @should_have_no_chain=#{@should_have_no_chain}"
		return nil if @count_next > @@FCE_COUNT_MAX

		if @count_next > 0 and @current.nil?
			return nil
		end
		
		@count_next += 1

		if @should_have_no_chain
			@current = @fragment_repeater.next(backreferences)
			# because there is no subsequent chain, we know this FCE has to fit the remaining_length exactly
			while ! @current.nil? and remaining_length >= 0 and @current.length <= (remaining_length * @fragment_pieces_ratio) and @current.length != remaining_length
				@current = @fragment_repeater.next(backreferences) 					
			end

			if ! @current.nil? and @current.length > remaining_length
				@current = nil
			end

			#puts "DEBUG: FragmentChainElement.next: @fce_chain.nil? :id=#{@fragment_spec[:id]}, :string=#{@fragment_spec[:fragment_string]}, @current=#{@current}, backreferences=#{backreferences}, @count_next=#{@count_next}, remaining_length=#{remaining_length}"
			return @current
		end

		if @current.nil?
			@current = @fragment_repeater.next(backreferences)				
		end
	
		stop_runaway = 0
		# check we have a @current which fits within the remaining_length (give or take the ratio)
		if ! @current.nil? and remaining_length >= 0 and @current.length > (remaining_length * @fragment_pieces_ratio) 
			# assume any further nexts will only get longer...
			@current = nil
		end

		#while stop_runaway<@@FCE_COUNT_MAX and ! @current.nil? and remaining_length >= 0 and (@current.length > remaining_length)
		#	puts "DEBUG: FragmentChainElement.next: while: @current=#{@current}, remaining_length=#{remaining_length}, stop_runaway=#{stop_runaway}"
		#	@current = @fragment_repeater.next(backreferences)
		#	stop_runaway += 1
		#end

		#if stop_runaway>=@@FCE_COUNT_MAX
		#	abort "ERROR: FragmentChainElement.next: while: stop_runaway>#{@@FCE_COUNT_MAX}"
		#end

		# have we come up with a non-nil @current ?
		return nil if @current.nil?

		if @fragment_spec[:capture]
			backreferences.push(@current)
		end

		generate_chain if @fce_chain.nil?
		#puts "DEBUG: FragmentChainElement.next: 1st chain_next :id=#{@fragment_spec[:id]}, :string=#{@fragment_spec[:fragment_string]}, @current=#{@current}, backreferences=#{backreferences}, remaining_length=#{remaining_length}, @current.length=#{@current.length}, @count_next=#{@count_next}, @should_have_no_chain=#{@should_have_no_chain}"
		chain_next = @fce_chain.next(backreferences, remaining_length - @current.length)

		#puts "DEBUG: FragmentChainElement.next: after chain_next :id=#{@fragment_spec[:id]}, :string=#{@fragment_spec[:fragment_string]}, @current=#{@current}, backreferences=#{backreferences}, remaining_length=#{remaining_length}, chain_next=#{chain_next}"
		stop_runaway = 0
		while stop_runaway<@@FCE_COUNT_MAX and chain_next.nil? and ! @current.nil? and (remaining_length < 0 or (@current.length <= (remaining_length * @fragment_pieces_ratio)))
			stop_runaway += 1
			prev_current = @current
			@current = @fragment_repeater.next(backreferences)
			if !@current.nil? and remaining_length >= 0 and @current.length > remaining_length
				# as long as we have not gone past the ratio, we may still get shorter nexts so don't give up
				next
			end
			#puts "DEBUG: FragmentChainElement.next: in while: stop_runaway=#{stop_runaway}, @@FCE_COUNT_MAX=#{@@FCE_COUNT_MAX}, @current=#{@current}, remaining_length=#{remaining_length}, @current.length=#{@current.nil? or @current.length}"
			
			## check we have a @current which fits within the remaining_length
			#while (stop_runaway < @@FCE_COUNT_MAX) and (! @current.nil?) and (remaining_length >= 0) and (@current.length > remaining_length)
			#	puts "DEBUG: FragmentChainElement.next: while in while: @current=#{@current}, remaining_length=#{remaining_length}, stop_runaway=#{stop_runaway}"
			#	@current = @fragment_repeater.next(backreferences)
			#	stop_runaway += 1
			#end
			#
			if ! @current.nil?
				if @fragment_spec[:capture]
					backreferences.pop
					backreferences.push(@current)
				end
				generate_chain
				#puts "DEBUG: FragmentChainElement.next: loop chain_next :id=#{@fragment_spec[:id]}, :string=#{@fragment_spec[:fragment_string]}, @current=#{@current}, backreferences=#{backreferences}, remaining_length=#{remaining_length}, @current.length=#{@current.length}, @count_next=#{@count_next}"
				chain_next = @fce_chain.next(backreferences, remaining_length - @current.length)	

				if (prev_current.length == @current.length) and chain_next.nil?
					@current = nil
				end
			end
		end

		if stop_runaway>=@@FCE_COUNT_MAX
			abort "\nERROR: FragmentChainElement.next: while while: stop_runaway>#{@@FCE_COUNT_MAX}"
		end

				
		return nil if chain_next.nil? or @current.nil?

		
		#puts "DEBUG: FragmentChainElement.next: out :id=#{@fragment_spec[:id]}, @current=#{@current}, chain_next=#{chain_next}"
		return @current + chain_next
	end

	def to_s
		"FragmentChainElement: @fragment_spec=#{@fragment_spec}, @current=#{@current}, @count_next=#{@count_next},\n                      @fragment_repeater=#{@fragment_repeater}\n@fce_chain=#{@fce_chain.to_s}"
	end

	def generate_chain
		if ! @fragment_specs_for_chain.empty?
			@fce_chain = FragmentChainElement.new(Array.new(@fragment_specs_for_chain))
		else
			@fce_chain = nil
		end
	end
end

# FragmentChainer: 
# - .initialized with a regex_string
#  - parses the regex_string, to get a list of fragment_specs
# - .next
#  - creates the initial array of backreferences
#  - invokes teh start of the chain of FragmentChainElements, passing along the backreferences
#  - returns the concatenated string fragments

class FragmentChainer
	def initialize(regex_string, target_length = -1)
		@regex_string   = regex_string
		@fragment_specs = FragmentParser.parse_regex(@regex_string)
		@fce_chain          = FragmentChainElement.new(Array.new(@fragment_specs))
		@current        = nil
		@count_next     = 0
		@target_length  = target_length
	end

	def to_s
		"FragmentChainer: regex_string=\'#{@regex_string}\', @count_next=#{@count_next},\n" + @fragment_specs.join("\n") + ",\n@fce_chain=#{@fce_chain.to_s}"
	end

	def next
		return nil if @count_next > 0 and @current.nil?
		@count_next += 1

		return nil if @fce_chain.nil?

		@current = @fce_chain.next( backreferences = [], remaining_length = @target_length )
	end

	def count(max_count=10000000)
		c = 0
		while !self.next.nil? and c < max_count
			c += 1
			final_current = @current
			#puts "FragmentChainer.count: count=#{c}, @current=#{@current}"
		end
		puts "FragmentChainer.count: count=#{c}, final_current=#{final_current}"
		return c
	end
end

#
# ToDo
# - debug results of the regex counts, e.g. regex='[CR]*', 8. Loses the plot after 256. DONE
# - debug regex='N.*X.X.X.*E', 9. DONE
# - debug regex='[CEIMU]*OH[AEMOR]*', 10. DONE
# - debug regex=regex_string=(S|MM|HHH)*, target_length=7, FragmentChainer.count: count=3, final_current=MMHHHMM, count=3
#  - the FG does not emit nexts in size order
#  - IDEA: in the FG (or the fragment_parser, or the *FragmentRepeater*?), calculate the ratio of longest to shortest fragment_pieces, and that gives the multiple for how much more than remaining_length we wait for
# - debug: cannot parse 'P+(..)\1.*', or '.*(.)C\1X\1.*'
# - debug: crashes: '(RR|HHH)*.?'

def test1
	fragmentGen = FragmentGen.new({
		:fragment_pieces => @@ALL_CHARS,
		:repeat_char     => nil,
		:backreference   => false,
		:capture         => false,
		:repeat_from     => 0
		})
	puts "fragmentGen.all=#{fragmentGen.to_s}"
	puts "fragmentGen.next: 1..10: " + (1..24).map { |e| fragmentGen.next([]) }.join(',')
	puts "fragmentGen.current: #{fragmentGen.current}"
	puts "fragmentGen.next: "
	while ! (f = fragmentGen.next([])).nil?
		puts f
	end

	fragment_spec = {
		:fragment_pieces => nil,
		:repeat_char     => nil,
		:backreference   => 2,
		:capture         => false,
		:repeat_from     => 0
		}
	fragmentGen = FragmentGen.new( fragment_spec)

	backreferences = ['ABC', 'DEF', 'GHI']

	puts "\n#{fragmentGen.to_s}"
	puts "fragmentGen.nexts:"
	(1..3).each { |e| puts "#{e}) #{fragmentGen.next(backreferences) || 'nil'}"}
	puts "fragmentGen.current: #{fragmentGen.current || 'nil'}"

	puts "----"
	fragment_spec = {
		:fragment_pieces => ['RR', 'HHH'],
		:repeat_char     => nil,
		:backreference   => false,
		:capture         => false,
		:repeat_from     => 0
		}
	fragmentRepeaterElement = FragmentRepeaterElement.new(fragment_spec, 4)
	puts "fragmentRepeaterElement:\n" + fragmentRepeaterElement.to_s
	puts "fragmentRepeaterElement.current: " + fragmentRepeaterElement.current.to_s
	puts "calling fragmentRepeaterElement.next"
	puts "fragmentRepeaterElement.nexts: " + (1..30).map { |e| fragmentRepeaterElement.next([]).to_s }.join(',')

	puts "----"
	fragment_spec = {
		:fragment_pieces => nil,
		:repeat_char     => nil,
		:backreference   => 3,
		:capture         => false,
		:repeat_from     => 0
		}

	backreferences = ['ABC', 'DEF', 'GHI']

	fragmentRepeaterElement = FragmentRepeaterElement.new( fragment_spec, 3 )
	puts "fragmentRepeaterElement:\n" + fragmentRepeaterElement.to_s
	puts "backreferences=#{backreferences}"
	puts "fragmentRepeaterElement.current: " + fragmentRepeaterElement.current.to_s
	puts "calling fragmentRepeaterElement.nexts"
	puts "fragmentRepeaterElement.nexts: \n"
	(1..3).map { |e| puts "#{e}) #{fragmentRepeaterElement.next(backreferences) || 'nil' }" }


	puts "\n---"
	['*', '+', '?', nil].each { |repeat_char| 
		fragmentRepeater = FragmentRepeater.new({
			:fragment_pieces => ['AA', 'BB', 'CC'],
			:repeat_char     => repeat_char,
			:backreference   => false,
			:capture         => false,
			:repeat_from     => 0
		})
		puts fragmentRepeater.to_s
		puts "fragmentRepeater.nexts: " + (1..30).map { |e| "#{e.to_s}." + (fragmentRepeater.next([]) || 'nil') }.join(',')
	}

	puts "\n----"

	backreferences = ['ABC', 'DEF', 'GHI']

	puts "backreferences=#{backreferences}"

	['*', '+', '?', nil].each { |repeat_char| 
		fragment_spec = {
			:fragment_pieces => nil,
			:repeat_char     => repeat_char,
			:backreference   => 3,
			:capture         => false,
			:repeat_from     => 0
		}	

		fragmentRepeater = FragmentRepeater.new(fragment_spec)
		puts fragmentRepeater.to_s
		puts "fragmentRepeater.nexts: "
		(1..10).map { |e| puts "#{e.to_s})  #{fragmentRepeater.next(backreferences) || 'nil'}" }
	}

	puts "----"
	regex_string='ABC*[^ABC]+\1\2?[ABC]*[^ABC]+.*..+...?(..?)\1(AA|BBB)(A|BB)+(AA|BBB|[^ABCZ])?(PP|Q|RRR)'
	puts "FragmentParser.parse_regex: regex_string=#{regex_string}"
	puts FragmentParser.parse_regex(regex_string).join("\n")

	puts "----"
	FragmentParser.reset_id
	regex_string='(AA)B(B)C*D?E?F?G\1\2'
	regex_string='(ZZZZ|AA|BB)C?D*E+\1'
	regex_string='[CR]*'
	target_length = 8
	puts "FragmentChainer.initialize: regex_string=#{regex_string}"
	fragmentChainer = FragmentChainer.new(regex_string,target_length)
	puts fragmentChainer

	puts "fragmentChainer.nexts: for regex_string=\'#{regex_string}\', target_length=#{target_length}"
	(1..260).each { |e| 
		fcoutput = fragmentChainer.next
		if fcoutput.nil?
			fcoutput = 'nil' 
		else
			fcoutput = "\'#{fcoutput.to_s}\'"
		end
		puts sprintf("%3d) %s", e, fcoutput.to_s)
	}
	
	fragmentChainer = FragmentChainer.new(regex_string,target_length)
	puts "\nfragmentChainer.count=#{fragmentChainer.count}"
end

def test2
	puts "\n----"
	[
		['.(C|HH)*', 7],
		['[CR]*', 8],
		['R*D*M*', 8],
		['NA*E', 9],
		#['N.*X.X.X.*E', 9],
		#['[CEIMU]*OH[AEMOR]*', 10],
		['(S|MM|HHH)*', 7],
		['[AM]*CM(RC)*R?', 12],
		['P+(..)\1.*', 5],
		['.*(.)C\1X\1.*', 7],
		['(RR|HHH)*.?']
	].each {|pair| 
		regex_string = pair[0]
		target_length = pair[1]
		fragment_chainer = FragmentChainer.new(regex_string, target_length)
		puts "regex_string=#{regex_string}, target_length=#{target_length}"
		#fragment_chainer=#{fragment_chainer}"
		count = fragment_chainer.count
		puts "    count=#{count}" 
	}
end

def test_parsedotdot
	#puts "\n---"

	#fragmentRepeater = FragmentRepeater.new({
	#	:fragment_pieces => ['S', 'MM', 'HHH'],
	#	:repeat_char     => '*',
	#	:backreference   => false,
	#	:capture         => false,
	#	:repeat_from     => 0
	#})

	#puts fragmentRepeater.to_s
	#puts "fragmentRepeater.nexts: "
	#(1..300).each { |e| puts "#{e.to_s}." + (fragmentRepeater.next([]) || 'nil') }

	puts "----"
	FragmentParser.reset_id
	
	[
	 #'(AA)B(B)C*D?E?F?G\1\2',
	 #'(ZZZZ|AA|BB)C?D*E+\1',
	 #'[CR]*',
	 'P+',
	 '(..)',
	 'P+(..)\1.*',
	 '.*(.)C\1X\1.*',
	 '(RR|HHH)*.?',
	].each { |regex_string|
		puts "FragmentParser.parse_regex(\'#{regex_string}\''):\n" + FragmentParser.parse_regex(regex_string).join("\n")
	}
end

def test
	STDOUT.sync = true

	puts "test started:\n"

#	test1
#	test_parsedotdot
	test2

	puts "

	==============
	test completed
	==============
	"
end
test