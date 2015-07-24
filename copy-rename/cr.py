#!/usr/bin/env python

import  shutil
import datetime



shutil.copy(
    'default.xls',
    'timesheet-{0}.xls'.format(datetime.date.today().isoformat()))
