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
	attr_reader :current

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
	end

	def to_s
		"FragmentRepeater: @fragment_spec=#{@fragment_spec}, @start_index=#{@start_index}, @end_index=#{@end_index}, @index=#{@index}"
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
		when /^\((\.+)#{anyrepeat}\)(.*)$/
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
	@@fce_count = 0
	@@FCE_COUNT_MAX = 1000

	def initialize( fragment_specs )
		# assume param is a clone and can be mucked with
		@fragment_spec 			  = fragment_specs.shift
		@fragment_specs_for_chain = fragment_specs
		@fragment_repeater        = FragmentRepeater.new(@fragment_spec)
		@current                  = nil
		@count_next               = 0
		@fce_chain                = nil
		@should_have_no_chain     = @fragment_specs_for_chain.empty?
	end

	def next(backreferences, remaining_length)
		#puts "DEBUG: FragmentChainElement.next: in :id=#{@fragment_spec[:id]}, :string=#{@fragment_spec[:fragment_string]}, @current=#{@current}, backreferences=#{backreferences}, remaining_length=#{remaining_length}, @count_next=#{@count_next}"
		@@fce_count += 1
		return nil if @@fce_count > @@FCE_COUNT_MAX

		if @count_next > 0 and @current.nil?
			return nil
		end
		
		@count_next += 1

		if @should_have_no_chain
			@current = @fragment_repeater.next(backreferences)
			# TODO: yes, but what about if the current.length > remainin_length and keeps getting longer (e.g. with repeat element)?
			while ! @current.nil? and remaining_length >= 0 and @current.length != remaining_length
				@current = @fragment_repeater.next(backreferences) 					
			end

			#puts "DEBUG: FragmentChainElement.next: @fce_chain.nil? :id=#{@fragment_spec[:id]}, :string=#{@fragment_spec[:fragment_string]}, @current=#{@current}, backreferences=#{backreferences}, @count_next=#{@count_next}"
			return @current
		end

		if @current.nil?
			@current = @fragment_repeater.next(backreferences)				
		end
	
		stop_runaway = 0
		# check we have a @current which fits within the remaining_length
		if ! @current.nil? and remaining_length >= 0 and @current.length > remaining_length
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
		#puts "DEBUG: FragmentChainElement.next: 1st chain_next :id=#{@fragment_spec[:id]}, :string=#{@fragment_spec[:fragment_string]}, @current=#{@current}, backreferences=#{backreferences}, remaining_length=#{remaining_length}, @current.length=#{@current.length}, @count_next=#{@count_next}"
		chain_next = @fce_chain.next(backreferences, remaining_length - @current.length)

		#puts "DEBUG: FragmentChainElement.next: after chain_next :id=#{@fragment_spec[:id]}, :string=#{@fragment_spec[:fragment_string]}, @current=#{@current}, backreferences=#{backreferences}, remaining_length=#{remaining_length}, chain_next=#{chain_next}"
		stop_runaway = 0
		while stop_runaway<@@FCE_COUNT_MAX and chain_next.nil? and ! @current.nil? and (remaining_length < 0 or (remaining_length - @current.length) >= 0)
			stop_runaway += 1
			@current = @fragment_repeater.next(backreferences)
			if !@current.nil? and remaining_length >= 0 and @current.length > remaining_length
				# assume any further nexts will only get longer...
				@current = nil
			end
			## check we have a @current which fits within the remaining_length
			#puts "DEBUG: FragmentChainElement.next: in while: stop_runaway=#{stop_runaway}, @@FCE_COUNT_MAX=#{@@FCE_COUNT_MAX}, @current=#{@current}, remaining_length=#{remaining_length}, @current.length=#{@current.nil? or @current.length}"
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
end

#
# ToDo
# - specify/limit overall generated string length
#  - IDEA: pass in remaining_length, where <0 => unlimited, 0 => must produce no more chars (but still match regex), >1 => must produce this num of chars
#   - Q: needs to allow for repeat_char=? or * in subsequent FCEs, but, how do we stop a * from iterating 4e4? 
#     - pre-sort :fragment_pieces?
#     - Q: but even with A*, how do say no more? 
#     - Q: Can we say a chain_next is only going to stay same length or get longer?
#   - Q: will the final FragmentChainElement make the judgement call on whether the overall string is a match on length?
#   - Q: will it be possible to keep the length checking at the FragmentChainElement level? Hopefully yes.
#   - Q: will there be a need to have a filter at the FragmentChainer level to check on string length? Hopefully not.
#  - IDEA: define a adhere_to_precise_length var in start of FCE.next call, to make it clean/clear if we need to worry about length in rest of def
#   - probably needs several length checks in next def
#  - specify target length in FCE.inititialize. It doesn't sense for it to change from .next to .next. Then pass remaining_length through stack.
# - check backreferences pop/push stack for later chain pushes not being popped when unwinding back to earlier in the chain.

def test
	STDOUT.sync = true

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
	target_length = 9
	puts "FragmentChainer.initialize: regex_string=#{regex_string}"
	fragmentChainer = FragmentChainer.new(regex_string,target_length)
	puts fragmentChainer

	puts "fragmentChainer.nexts: for regex_string=\'#{regex_string}\', target_length=#{target_length}"
	(1..30).each { |e| 
		fcoutput = fragmentChainer.next
		if fcoutput.nil?
			fcoutput = 'nil' 
		else
			fcoutput = "\'#{fcoutput.to_s}\'"
		end
		puts sprintf("%3d) %s", e, fcoutput.to_s)
	}
	
	
	
	puts "
	==============
	test completed
	==============
	"
end

test