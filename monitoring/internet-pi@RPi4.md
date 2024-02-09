Installing Internet Connection monitoring set from source:
https://github.com/geerlingguy/internet-pi

```
sudo apt-get install -y python3-pip
pip3 install ansible
```
(re-login)
```
ansible-galaxy collection install -r requirements.yml
```
cp example.config.yml config.yml
cp example.inventory.ini inventory.ini
```
edit files
```
ansible-playbook main.yml
sudo shutdown -r now
ansible-playbook main.yml
sudo netstat -ntap | grep 3030
```
open (host):3030
