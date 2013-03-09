require File.dirname(__FILE__) + '/cell'
require File.dirname(__FILE__) + '/row_regex'

class Row
	attr_reader :cells, :regex, :id

	# this constructor can interpret nth in two ways: saying which slice of the existing_rows, or the length of the row if none
	# NB, nth starts at 0

	def initialize( id_prefix, regex, nth, existing_rows = [] )
		@id    = [id_prefix, nth].join('.')
		@regex = regex
		@cells = []

		if existing_rows.length == 0
			num_cells = nth -1
			@cells = (0..num_cells).map { |i| Cell.new }
		else
			# this is the clever bit which takes a slice across the existing rows
			minimum_row_length = (existing_rows.length / 2).to_i + 1

			# copy the existing_rows into a new array of arrays of cells
			#source_rows = existing_rows.map { |r| Array.new(r.cells) }

			if nth < minimum_row_length
				starting_row  = minimum_row_length -1 + nth
				starting_cell = 0
				maximum_cell  = nth
				ending_row    = 0
			else
				starting_row  = (existing_rows.length) -1
				starting_cell = nth - minimum_row_length + 1
				maximum_cell  = nth
				ending_row    = nth - minimum_row_length + 1
			end

#puts "starting_row=#{starting_row}, starting_cell=#{starting_cell}, maximum_cell=#{maximum_cell}, ending_row=#{ending_row}\n"
			c = starting_cell
			(ending_row..starting_row).to_a.reverse.each{ |r|
#				puts "r=#{r}\n"
				@cells << existing_rows[r].cells[c]
				c += 1 if( c < maximum_cell )
			}
		end

		# make sure we link the row to the cell
		@cells.each{ |cell| cell.add_to_row( self ) }
	end

	def to_s( max_cells = 7 )
		if @cells.length > max_cells
			padding = []
		else
			padding = [" "] * (max_cells- @cells.length)
		end
		sprintf( "%s) %s%s%s : %s",
		         @id,
				 padding.join(''),
				 @cells.map { |item| item.to_s }.join(' '),
				 padding.join(''),
				 @regex.to_s 
				 )
	end
end	

# quick test

def row_test
	rows = []
	num_rows = 7
	minimum_row_length = (num_rows / 2).to_i + 1
	puts "num_rows=#{num_rows}, minimum_row_length=#{minimum_row_length}\n"
	(0..minimum_row_length-1).each{ |i| rows << Row.new(Row_regex.new, minimum_row_length + i) }
	(minimum_row_length..num_rows-1).each{ |i| rows << Row.new(Row_regex.new, num_rows + minimum_row_length -1 -i) }

	puts rows

	next_rows = (0..num_rows-1).map { |r| Row.new(Row_regex.new, r, rows) }

	puts "\n"
	puts next_rows
end