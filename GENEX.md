genex 
=====

a home-grown stab at the Perl Regex-Genex library which generates all strings which match the specified regex.

The scope of which regex features are covered will be kept small, sufficient to cover the regex hex puzzle.

Starting with:

* . (any char)
* * (any number of the previous thingy)
* + (1 or more of the previous thingy)
* ? (0 or 1 of the previous thingy)
* (aa|bb|cc) (either aa or bb or cc)
* [abc]      (either a or b or c)
* [^abc]     (anything other than a or b or c)
* ^          (anchored to the start of the string)
* $          (anchored to the end of the string)
* \1         (previous match of the ())
* \2 \3 etc

There will be a global maximum length of string

approach
========

* to keep the code simple, probably at the xpense of efficiency
* to generate all single chars, then pairs of chars, then triples, etc
* lazy evaluation
