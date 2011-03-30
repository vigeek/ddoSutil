#!/usr/bin/env python
# dSutil-deflate.py - much to do...

import os
from string import split

final = ''

comd = os.popen("netstat -tunv  | awk '{print $5}' | awk -F':' '{print $1}' | grep ^[0-9] | uniq -c")
for ivar in comd.readlines():
	final+=ivar
	print ivar
comd.close
