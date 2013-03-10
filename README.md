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

- check that the cells do in fact know which rows they are in. DONE
- a scoring fn for a row. DONE
- score all the rows. DONE
- identify a suitable cell. DONE
- try all poss letter values, looks scores in the 3 intersecting rows, for a cell. DONE
- scan all the cells, looking to improve each one. DONE
- iterate. DONE
- expand the partials in the DSL text. the alg seems to be implemented ok, but not getting very far with the current regexs.DONE
- expand them some more. DONE
- add all the missing rows. had forgotten only some were entered initially. Sigh. DONE
- carefully check the row regexs
- add partials to the new rows. DONE
- add more partials, based on stats of matches
- fancy GUI? 