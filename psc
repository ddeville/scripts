#!/bin/tcsh
set cmd = 'ps axo pid,ppid,user,command'
if ("$1" == "") then
  $cmd
else
  $cmd | grep "$1" | grep -v "grep $1" | grep -v "bin/psc"
endif

