#!/usr/bin/python

import sys
import codecs

letterdex = {}

for i in xrange(2):
    for j in xrange(13):
        letterdex[chr(97 + ((13*i) + j))] = (i, j)

print letterdex

input = str(sys.argv[1])
print input

xform = 'tmb%d%s%d' %  (letterdex[input[0]][0] , input , letterdex[input[0]][1])
print xform


rot13ed_data = codecs.getencoder('rot13')(xform)[0]
print rot13ed_data
