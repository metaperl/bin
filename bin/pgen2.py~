#!/usr/bin/python

import sys
import codecs

input = str(sys.argv[1])
print input

xform = '0%s1%s2' % ('tmb', input[0:3])
print xform


rot13ed_data = codecs.getencoder('rot13')(xform)[0]
print rot13ed_data
