class Cell
	attr_reader :letter, :rows

	@@ALL_LETTERS = ('A'..'Z').to_a
	@@ALL_CELLS = []

	def self.all
		@@ALL_CELLS
	end

	def self.test_all_cells_row_ids
		Cell.all.map { |e| e.to_s + '[' + e.row_ids.join(',') + ']' }.join(', ')
	end

	def self.test_all_cells_rows_scores
		Cell.all.map { |c|  sprintf( "<%4.2f> %s [%s]",
									 c.score,
									 c.to_s,
									 c.row_ids.join(',') 
									 ) }.join("\n")
	end

	def self.test_cell_find_a_better_letter( cell = @@ALL_CELLS.first )
		initial_letter = cell.letter
		initial_score  = cell.score
		found_a_better_letter = cell.find_a_better_letter?
		new_letter     = cell.letter
		new_score      = cell.score
		if found_a_better_letter
			sprintf( "%s-%s, <%4.2f>-<%4.2f>",
			         initial_letter,
			         new_letter,
			         initial_score,
			         new_score
			         )	
		else
			sprintf( "%3s, <%4.2f>",
					 initial_letter,
					 initial_score
				     )
	    end
	end

	def initialize( letter = @@ALL_LETTERS[rand(26)] )
		@letter = letter
		@rows = []
		@@ALL_CELLS << self
	end

	def add_to_row( row )
		@rows << row
	end

	def to_s
		@letter.to_s
	end

	def row_ids
		@rows.map { |r| r.id }
	end

	def score
		@rows.map { |r| r.score }.inject(:+)
	end

	def find_a_better_letter?
		initial_score  = self.score
		initial_letter = @letter

		best_score  = initial_score
		best_letter = initial_letter

		@@ALL_LETTERS.each do |new_letter| 
			if (new_letter != initial_letter)
				@letter   = new_letter
				new_score = self.score
				if new_score > best_score
					best_score  = new_score
					best_letter = new_letter
				end
			end
		end

		if best_score > initial_score
			@letter = best_letter
			return true
		else
			@letter = initial_letter
			return false
		end
	end
end