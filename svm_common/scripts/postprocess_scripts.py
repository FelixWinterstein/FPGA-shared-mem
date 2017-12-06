#!/usr/bin/env python

#----------------------------------------------------------------------------------
#-- Felix Winterstein, Imperial College London, 2016
#-- 
#-- Module Name: postprocess_scripts.py
#-- 
#-- Revision 1.01
#-- Additional Comments: distributed under an Apache-2.0 license, see LICENSE
#-- 
#----------------------------------------------------------------------------------

import argparse
import os
import sys
import subprocess
import shutil
import hashlib


parser = argparse.ArgumentParser()
parser.add_argument('cl_file', help = 'path to kernel code (.cl) file')
args = parser.parse_args()

if os.path.isfile(args.cl_file) and os.path.splitext(args.cl_file)[1] == '.cl':
	proj = os.path.splitext(os.path.basename(args.cl_file))[0]
else:
	sys.exit('Unrecognised file type')

# Delete previously generated interface system partition file so it's regenerated

os.remove(os.path.join(proj, 'acl_iface_partition.qxp'))
	
# Remove add_* commands from system.tcl so that QSys isn't told to add components or wires that already exist

with open(os.path.join(proj, 'system.tcl'), 'r') as handle:
	lines = handle.readlines()

with open(os.path.join(proj, 'system.tcl'), 'w') as handle:
	for line in lines:
		if not line.startswith('add_'):
			handle.write(line)
