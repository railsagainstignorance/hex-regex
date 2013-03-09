require File.dirname(__FILE__) + '/full_hex.rb'
require File.dirname(__FILE__) + '/cell.rb'

def message_and_exit(text)
  puts 'Error: ' + text
  puts 'at ' + caller[1].split(':')[0..1].join(', line ')
  exit
end

def side()
  Full_hex.instance.add_side Side.new()
end

def full_row(text)
  message_and_exit "no side exists for row: \"#{text}\"" if Full_hex.instance.last_side.nil?
  Full_hex.instance.last_side.add_row Row_regex.new(text)
end

def partial_left(text)
  message_and_exit "no row exists for partial_left: \"#{text}\"" if Full_hex.instance.last_side.nil? or Full_hex.instance.last_side.last_row.nil?
  Full_hex.instance.last_side.last_row.add_partial_left( text )
end

def partial_right(text)
  message_and_exit "no row exists for partial_right: \"#{text}\"" if Full_hex.instance.last_side.nil? or Full_hex.instance.last_side.last_row.nil?
  Full_hex.instance.last_side.last_row.add_partial_right( text )
end

load 'hex-regex.txt'

if( ! Full_hex.instance.all_inputs_validated? )
  puts  'Full_hex: input woes: '
  Full_hex.instance.input_woes.each do |woe|
    puts '- ' + woe + "\n"
  end
  puts
  exit
end

puts Full_hex.instance.summary

puts Full_hex.instance.to_s

puts "\npopulating hex\n"
Full_hex.instance.populate_hex

puts Full_hex.instance.to_s

puts "\ncell test: all cells' row ids:\n"
puts Cell.test_all_cells_row_ids

puts "\nrow score test: all rows' scores:\n"
puts Row.test_all_rows_scores

puts "\ncell score test: all cells' scores:\n"
puts Cell.test_all_cells_rows_scores

puts "\nfind a better letter test:\n"
printf "total score = %5.2f\n", Row.total_score
puts Cell.test_cell_find_a_better_letter
printf "total score = %5.2f\n", Row.total_score

puts "\nscan all cells to find better letters:\n"
printf "total score = %5.2f\n", Row.total_score
puts Cell.test_scan_all_cells_for_better_letters
printf "total score = %5.2f\n", Row.total_score

puts "\nscan all cells and report if any improvement:\n"
printf "total score = %5.2f\n", Row.total_score
found = Cell.find_a_better_letter_across_all_cells?
if found
  puts " improvement found\n"
else
  puts " none found\n"
end
printf "total score = %5.2f\n", Row.total_score

puts "\nrepeatedly scan all cells until no more improvement:\n"
printf "total score = %5.2f\n", Row.total_score
iteration = 1
while Cell.find_a_better_letter_across_all_cells?
  printf "%d) total score = %5.2f\n", iteration, Row.total_score.to_s
  iteration += 1
end