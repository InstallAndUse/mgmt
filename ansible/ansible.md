# 2022 03 19  + published on https://github.com/InstallAndUse/mgmt /A


# distribute public keys

# + local user: remote hosts to known_hosts
for host in $(cat (hosts.list).ini); do ssh-keyscan -H $host >> ~/.ssh/known_hosts; done;


# can deploy keys with ansible:

# ansible playbook that adds ssh fingerprints to known_hosts
- hosts: all
  connection: local
  gather_facts: no
  tasks:
  - command: /usr/bin/ssh-keyscan -T 10 {{ ansible_host }}
    register: keyscan
  - lineinfile: name=~/.ssh/known_hosts create=yes line={{ item }}
    with_items: '{{ keyscan.results | map(attribute='stdout_lines') | list }}'


# ansible
ansible-playbook -u (you) -i (hosts.list)-production.ini -k -b --ask-become-pass overwrite_file.yml      
