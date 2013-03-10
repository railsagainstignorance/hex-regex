require File.dirname(__FILE__) + '/cell'
require File.dirname(__FILE__) + '/row_regex'

class Row
	attr_reader :cells, :row_regex, :id

	@@ALL_ROWS = []

	def self.all
		@@ALL_ROWS
	end

	def self.test_all_rows_scores
		Row.all.map { |r| sprintf("<%4.2f> %s", r.score.to_s, r.to_s) }.join("\n")
	end

	def self.total_score
		Row.all.map { |r| r.score }.inject(:+)
	end

	# this constructor can existing_rows in two ways: a nil row means create a new Cell.
	# NB, nth starts at 0

	def initialize( id_prefix, row_regex, nth, existing_rows )
		@id        = [id_prefix, nth].join('.')
		@row_regex = row_regex
		@cells     = []

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
			if existing_rows[r].nil?
				cell = Cell.new
			else
				cell = existing_rows[r].cells[c]
			end
			@cells << cell
			c += 1 if( c < maximum_cell )
		}
	
		# make sure we link the row to the cell
		@cells.each{ |cell| cell.add_to_row( self ) }

		@@ALL_ROWS << self
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
				 @row_regex.score_breakdown_to_s(self.string_of_cells)
				 )
	end

	def string_of_cells
		@cells.map { |c| c.letter }.join('')
	end

	def score
		@row_regex.score(self.string_of_cells)
	end

end	