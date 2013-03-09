taking a stab at programatically solving the hex of regexs
==========================================================

Intrigued by http://www.coinheist.com/rubik/a_regular_crossword/grid.pdf

am attempting to rediscover Ruby and write an program to solve it.

The hex is specified via a DSL in hex-regex.txt.

To run the 'solution' so far, 
$ ruby hex-regex-dsl.rb

Approach
========

* create a DSL to allow specification of a hexagonal grid with 3 set of rows, where each row is constrained by a regex that must match the entre row (as described in the initial example)
* extend the definition of each row so that it can have a set of smaller regexs which just match part of the row, to give a a more 'helpful' scoring mechanism rather than just yes/no.
* actually use ruby Regexs on Strings
* populate the initial grid with random A-Z
* iterate in some structured way and do a basic hill-climbing algorithm
 * picking a cell (at random, or the worst)
 * trying other letter values
 * re-evaluate the 3 intersecting rows
 * retain the letter change if it improves things
 * rinse and repeat

TBD
===

- check that the cells do in fact know which rows they are in
- a scoring fn for a row
- score all the rows
- identify a suitable cell
- try all poss letter values, looks scores in the 3 intersecting rows
- pick a letter
- iterate
- fancy GUI? 