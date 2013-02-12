require File.dirname(__FILE__) + '/full_hex.rb'

# define
# - side
# - full_row
# - partial_left
# - partial_right

def side()
  Full_hex.instance.add_side Side.new()
end

def full_row(text)
  Full_hex.instance.last_side.add_row Row_regex.new(text)
end

def partial_left(text)
  Full_hex.instance.last_side.last_row.add_partial_left( text )
end

def partial_right(text)
  Full_hex.instance.last_side.last_row.add_partial_right( text )
end

load 'hex-regex.txt'

puts "
Summary:
- #{Full_hex.instance.sides.length} sides
- #{Full_hex.instance.sides.first.row_regexs.length} rows per side
- missing some basic error checking"