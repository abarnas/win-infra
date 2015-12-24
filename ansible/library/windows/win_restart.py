#!/usr/bin/python
# -*- coding: utf-8 -*-

# (c) 2014, Paul Durivage <paul.durivage@rackspace.com>, Trond Hindenes <trond@hindenes.com> and others
#
# This file is part of Ansible
#
# Ansible is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Ansible is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Ansible.  If not, see <http://www.gnu.org/licenses/>.

# this is a windows documentation stub.  actual code lives in the .ps1
# file of the same name

DOCUMENTATION = '''
---
module: win_restart
version_added: "1.9"
short_description: Restarts a windows system
description:
     - Restart a remote windows hosts
options:
  name:
    force:
      - Force a reboot
    required: false
    default: false
    aliases: []
author: Ard-Jan Barnas
'''

EXAMPLES = '''
# This restarts a windows server
$ ansible -i hosts -m win_restart all

# Playbook example
---
- name: RestartServer
  hosts: all
  gather_facts: false
  tasks:
    - name: RestartServer
      win_restart:
        force: true

'''
