#!/usr/bin/env python

# -----------------------------------------------------------------
# Main Program
# -----------------------------------------------------------------

# Get and read the Pythonware Daily URL
import urllib2

url = 'http://www.pythonware.com/daily/'
f = urllib2.urlopen(url)
html = f.read()
f.close()

# Get the list of emails to send to
f = open("emails.txt")

# Create a text/plain message

from email.MIMEText import MIMEText

msg = MIMEText(html, "html") # MIMEMultipart("alternative") # 

me  = 'sundevil@livingcosmos.org'

for you in f:

    import datetime
    msg['Subject'] = '%s - %s' % (datetime.date.today(), url)
    msg['From'] = me
    msg['To'] =   you

    # Send the message via our own SMTP server, but don't include the
    # envelope header.

    import smtplib

    s = smtplib.SMTP()
    s.connect()
    s.sendmail(me, [you], msg.as_string())
    s.close()
