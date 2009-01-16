#!/usr/bin/env python

from path import path
import time


daysecs = 86400
daysago = 60
secsago = daysago * daysecs
timethen = time.time() - secsago

for f in path('/Users/tbrannon/Downloads').files('*'):
    age = f.mtime - timethen
    if age < 0:
        f.remove()
