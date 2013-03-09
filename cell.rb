class Cell
	attr_reader :letter, :rows

	@@ALL_LETTERS = ('A'..'Z').to_a
	@@ALL_CELLS = []

	def self.all
		@@ALL_CELLS
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
end