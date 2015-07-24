#!/usr/bin/env python


from pyperclip import *

txt = """<html>
  <head>
    <title>Money Back with Every Purchase</title>
    <META http-equiv="refresh" content="1;URL={0}">
  </head>
  <body bgcolor="#ffffff">
    <center>
      Connecting to webinar.
    </center>
  </body>
</html>
"""

html = txt.format(paste())
print html
with open('index.html', 'w') as fp:
    fp.write(html)

# x

from fabric.api import execute, put

s = execute(put, 'index.html',
            remote_path='/home/schemelab/domains/com/cashbackmiami',
            host='schemelab@li2-168.members.linode.com')
print(repr(s))
