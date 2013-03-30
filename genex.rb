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
	
class FragmentGen
	attr_reader :current, :all

	@@ALL_CHARS=('A'..'Z').to_a
	
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

end

# nil means end of sequence

class FragmentRepeater
	attr_reader :current

	@@NO_FRAGMENT = nil

	def initialize(fragment_spec, repeat_char='*')
		@fragment_spec = fragment_spec

		case repeat_char
		when '*'
			@start_index = 0
			@end_index   = -1 # keep going 4e4
		when '?'
			@start_index = 0
			@end_index   = 1
		when '+'
			@start_index = 1
			@end_index   = -1 # keep going 4e4
		else 
			exit 'unrecognized repeat_char:' + repeat_char
		end

		@index = @start_index -1
		@chain = nil
	end

	def next
		if @index == -1 # ie we are starting with nothing
			@index += 1
			return @@NO_FRAGMENT
		elsif @end_index > 0 and @index > @end_index
			return @@NO_MORE
		end

		# if we get here, we are expecting to be generating some fragments

		# make sure we have an initial chain for the current chain length, i.e. @index

		if @chain.nil?
			@chain = FragmentRepeaterElement.new(@fragment_spec, @index)
		end

		next_fragment = @chain.next

		# if the chain has finished, inc index and try again

		if next_fragment.nil?
			@index += 1
			next_fragment = self.next
		end

		# if we get here, we either have a next_fragment or it is nil (and therefore this FragmentRepeater is finished)

		@current = next_fragment
	end
end

class FragmentRepeaterElement
	attr_reader :current

	def initialize(fragment_spec, chain_length)
		#puts "DEBUG: FragmentRepeaterElement.new: fragment_spec=#{fragment_spec.to_s}, chain_length=#{chain_length}"
		@fragment_spec = fragment_spec
		@chain_length = chain_length
		@fragmentGen = FragmentGen.new(@fragment_spec)
		generate_chain
	end

	# private
	def generate_chain
		if @chain_length > 1 and ! @fragmentGen.next.nil?
			#puts "DEBUG: generate_chain: @chain_length=#{@chain_length},  @fragmentGen.current=#{ @fragmentGen.current }"
			@chain = FragmentRepeaterElement.new( @fragment_spec, @chain_length - 1)
		else
			#puts "DEBUG: generate_chain: @chain = nil"
			@chain = nil
		end
	end

	# get the next iteration from the chain, and if that is nil, we iterate locally and generate a new chain
	def next
		#puts "next: @chain_length=#{@chain_length}, @chain=#{@chain.to_s}, @fragmentGen.current=#{@fragmentGen.current.to_s}"
		if @chain.nil?
			@current = @fragmentGen.next
		else
			chained_fragment = @chain.next
			if chained_fragment.nil?
				generate_chain
				chained_fragment = @chain.next if !@chain.nil?
			end
			
			local_fragment = @fragmentGen.current

			if local_fragment.nil? or chained_fragment.nil?
				@current = nil
			else
				@current = local_fragment + chained_fragment
			end
		end

		#puts "@chain_length=#{@chain_length}, @current=#{@current}"
		@current
	end

	def all
		@fragmentGen.all
	end
end

def test
	fragmentGen = FragmentGen.new
	puts "fragmentGen.all=#{fragmentGen.all}"
	puts "fragmentGen.next: 1..10: " + (1..24).map { |e| fragmentGen.next }.join(',')
	puts "fragmentGen.current: #{fragmentGen.current}"
	puts "fragmentGen.next: "
	while ! (f = fragmentGen.next).nil?
		puts f
	end

	fragmentRepeaterElement = FragmentRepeaterElement.new(['RR', 'HHH'], 4)
	puts "fragmentRepeaterElement.all: " + fragmentRepeaterElement.all.join(",")
	puts "fragmentRepeaterElement.current: " + fragmentRepeaterElement.current.to_s
	puts "calling fragmentRepeaterElement.next"
	puts "fragmentRepeaterElement.next: " + (1..30).map { |e| fragmentRepeaterElement.next.to_s }.join(',')

	fragmentRepeater = FragmentRepeater.new(['A', 'B', 'C'], '*')
	puts "fragmentRepeater: " 
	(1..10).each { |e| puts ' .next: ' + (fragmentRepeater.next || 'nil') }
	# is not working at this point
	# test the repeater element


end

test