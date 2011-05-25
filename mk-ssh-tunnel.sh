#!bin/bash -x


ssh -L '1522:localhost:5432' computer@test.bioscriptrx.com 'ping -i 60 localhost'

