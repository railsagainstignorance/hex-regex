require 'singleton'
require File.dirname(__FILE__) + '/side'

class Full_hex
  include Singleton
  attr_reader :sides

  def initialize
    @sides = []
  end

  def add_side( side )
    @sides << side
  end

  def last_side()
    @sides.last
  end
end