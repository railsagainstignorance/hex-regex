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

 Also, re TDD, have not explicitly used tests but am experimenting with running test-esque code in the main hex-regex-dsl.rb file automatically. The test-esque code is mainly to view the output to see what is happening. 
 Seems to have a similar effect on coding.
 * helping to think about the code
 * immediately breaks if later code changes cause a problem
 * helps surface the need for assorted abstractions and pushing the code to the more suited class.
"But that's just the same as writing test code as you go anyway."
Maybeso.

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
- wondering if the partials are in fact *preventing* the algorithm from being able to find the right letters
- also, perhaps there are certain improvements which can only be made through 2+ letters changing at once
- have quite possibly reached the limit of dumb, single-letter mutations, but hopefully the hex framework will support any further algorithmic ideas.
- how about allowing flipflop between rows which match, and rows which dont? Every 2nd iteration, ignore the contributions of previously matching rows. Not sure that makes sense. 
 - After iteration1, some rows don't match. 
 - setting those to ".*" (temporarily), match against the remaining rows in iteration 2
 - After iteration2, there are the (previously) matching iteration1 rows, the (currently) matching iteration 2 rows, and the (currently) non-matching iteration2 rows.
 - what next? 
 - ignore all matching iterations 1 and 2 rows, and only score against the non-matching iteration rows in iteration 3?
 - keep going until there are no non-matching rows left, then start again?
 - can we be sure of getting a fully matched row in each iteration? 
