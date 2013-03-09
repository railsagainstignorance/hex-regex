class Cell
	attr_reader :letter, :rows

	@@ALL_LETTERS = ('A'..'Z').to_a

	def initialize( letter = @@ALL_LETTERS[rand(26)] )
		@letter = letter
		@rows = []
	end

	def add_to_row( row )
		@rows << row
	end

	def to_s
		@letter.to_s
	end
end