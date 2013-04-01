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

	def initialize(pieces=@@ALL_CHARS)
		@all = pieces
		@index = -1 # index points to prev position
		@max_index = @all.length - 1
	end

	def next
		if @index > @max_index
			@current = @@NO_MORE
		else
			@index += 1
			@current = @all[@index]
		end

		return @current
	end

	def to_s
		'FragmentGen: ' + self.all.to_s + ", current=#{self.current or 'nil'}"
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
		@fragmentGen = FragmentGen.new(@fragment_spec[:fragment_pieces])
		generate_chain
	end

	# private
	def generate_chain
		if @repeat_length > 1 and ! @fragmentGen.next.nil?
			#puts "DEBUG: generate_chain: @repeat_length=#{@repeat_length},  @fragmentGen.current=#{ @fragmentGen.current }"
			@repeat_chain = FragmentRepeaterElement.new( @fragment_spec, @repeat_length - 1)
		else
			#puts "DEBUG: generate_chain: @repeat_chain = nil"
			@repeat_chain = nil
		end
	end

	# get the next iteration from the chain, and if that is nil, we iterate locally and generate a new chain
	def next
		#puts "next: @repeat_length=#{@repeat_length}, @repeat_chain=#{@repeat_chain.to_s}, @fragmentGen.current=#{@fragmentGen.current.to_s}"
		if @repeat_chain.nil?
			@current = @fragmentGen.next
		else
			chained_fragment = @repeat_chain.next
			if chained_fragment.nil?
				generate_chain
				chained_fragment = @repeat_chain.next if !@repeat_chain.nil?
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
			exit 'unrecognized repeat_char:' + repeat_char
		end

		@index = @start_index - 1
		@repeater_element = nil
	end

	def to_s
		"FragmentRepeater: @fragment_spec=#{@fragment_spec}"
	end

	def next
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

		next_fragment = @repeater_element.next

		# if the chain has finished, inc index, reset the chain, and try again

		if next_fragment.nil?
			@index += 1
			@repeater_element = nil
			next_fragment = self.next
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

	def self.parse_regex(regex_string)
		
		capture = false
		
		anyornoneofchar        ='\[\^?[A-Z]+\]'
		charsoranyornoneofchar ="(?:[A-Z]+|#{anyornoneofchar})"
		anyrepeat              ='([*+?])'
		case regex_string
		when ""
			return []
		when /^(\.+|[A-Z]+|#{anyornoneofchar}|\\\d)#{anyrepeat}?(.*)$/
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
		when /^\((#{charsoranyornoneofchar}(?:\|#{charsoranyornoneofchar})*)\)#{anyrepeat}?(.*)$/
			# can parse: (AA|BBB), i.e. storing the match for later use, with optional modifiers [*+?]
			fragment_string        = $1
			repeat_char            = $2
			remaining_regex_string = $3
			capture                = true
		else
			puts "ERROR: could not parse regex_string=#{regex_string}"
			exit
			return []
		end

		backreference = false
		repeat_from = 0
		case fragment_string
		when /^([A-Z]+)$/
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
		when /^([A-Z]+(?:\|[A-Z]+)*)$/
			fragment_pieces = $1.split(/\|/)
		else
			puts "ERROR: could not parse fragment_string=\'#{fragment_string}\' with repeat_char=\'#{repeat_char}\' in regex_string=\'#{regex_string}\'"
			exit
			return []
		end

		fragment_spec = {
			:fragment_pieces => fragment_pieces, # a list of strings that could match this fragment
			:repeat_char     => repeat_char,     # the char the indicates how the fragment repeats, possibly nil
			:backreference   => backreference,          # specifies which previously matched value to use (int) or nil
			:capture         => capture,          # is this fragment to be stored for later matching
			:repeat_from     => repeat_from      # to cover multiple dots, e.g. ..., would have repeat_from=2
		}

		return [fragment_spec] + self.parse_regex(remaining_regex_string)
	end
end

class FragmentChainer
	#
end

#

def test
	fragmentGen = FragmentGen.new
	puts "fragmentGen.all=#{fragmentGen.to_s}"
	puts "fragmentGen.next: 1..10: " + (1..24).map { |e| fragmentGen.next }.join(',')
	puts "fragmentGen.current: #{fragmentGen.current}"
	puts "fragmentGen.next: "
	while ! (f = fragmentGen.next).nil?
		puts f
	end

	puts "----"
	fragmentRepeaterElement = FragmentRepeaterElement.new({
		:fragment_pieces => ['RR', 'HHH'],
		:repeat_char     => nil,
		:backreference   => false,
		:capture         => false,
		:repeat_from     => 0
		}, 4)
	puts "fragmentRepeaterElement:\n" + fragmentRepeaterElement.to_s
	puts "fragmentRepeaterElement.current: " + fragmentRepeaterElement.current.to_s
	puts "calling fragmentRepeaterElement.next"
	puts "fragmentRepeaterElement.nexts: " + (1..30).map { |e| fragmentRepeaterElement.next.to_s }.join(',')

	puts "----"
	['*', '+', '?', nil].each { |repeat_char| 
		fragmentRepeater = FragmentRepeater.new({
			:fragment_pieces => ['AA', 'BB', 'CC'],
			:repeat_char     => repeat_char,
			:backreference   => false,
			:capture         => false,
			:repeat_from     => 0
		})
		puts fragmentRepeater.to_s
		puts "fragmentRepeater.nexts: " + (1..30).map { |e| "#{e.to_s}." + (fragmentRepeater.next || 'nil') }.join(',')
	}

	puts "----"
	regex_string='ABC*[^ABC]+\1\2?[ABC]*[^ABC]+.*..+...?(..?)\1(AA|BBB)(A|BB)+'
	puts "FragmentParser.parse_regex: regex_string=#{regex_string}"
	puts FragmentParser.parse_regex(regex_string).join("\n")

	puts "test completed"
end

test