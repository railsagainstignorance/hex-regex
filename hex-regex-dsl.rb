require File.dirname(__FILE__) + '/full_hex.rb'

# define
# - side
# - full_row
# - partial_left
# - partial_right

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
