#!/usr/bin/env python
# A rudimentary syntax check for an ansible yaml file

import yaml
import sys

try:
    playbook = yaml.load(open('ansible/win-core-cisinfra.yml','r'))
except:
    print "Error loading the playbook, must be a yaml syntax problem"
    sys.exit(1)
else:
    print "YAML syntax looks good."
