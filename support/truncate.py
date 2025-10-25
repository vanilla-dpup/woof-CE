#!/usr/bin/python3

import sys
import mmap
import os

with open(sys.argv[1], 'r+b') as f:
	with mmap.mmap(f.fileno(), 0) as m:
		s = m.size()
		if m[s - 1] == 0:
			i = s - 2
			while i >= 0 and m[i] == 0:
				i -= 1

			print(f"{i * 100 / s:.2f}")
			m.resize(i + 1)
