#!/usr/bin/env python

import os
import subprocess
import sys

# first check (`xcode-select --version`) and install (`xcode-select --install`)
# then check and install brew (`/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"`)

def is_cmd_installed(cmd):
	try:
		path = subprocess.check_output(["which", cmd]).strip()
		return os.path.exists(path) and os.access(path, os.X_OK)
	except subprocess.CalledProcessError as e:
		return False

# Let's first make sure that a few things are installed
if not is_cmd_installed("brew"):
	print("Install brew by running")

print("DOG %r" % is_cmd_installed("brew"))
