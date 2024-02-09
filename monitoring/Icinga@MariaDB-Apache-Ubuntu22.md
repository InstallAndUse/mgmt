2023-10-17  * initial run

Create Ubuntu x86_64 architecture VM instance (aarch64 has icingaweb2.9.5, which is not supporting php v8.1).
Do not deploy Icinga onto arm64, second trial. Not supported, yet.
```bash
N: Skipping acquire of configured file 'main/binary-arm64/Packages' as repository 'https://packages.icinga.com/ubuntu icinga-jammy InRelease' doesn't support architecture 'arm64'
```

At this, point piece of advice, Debian is supporting arm64 architecture. I am running Mac M1, which is ARM. For local instance, I shall move to Debian distro.
Refer to another document.
```
https://packages.icinga.com/debian/dists/icinga-bookworm/
```



! Below assuming all commands are executed in the priveledged mode

Sync time for initially booted system and update/upgrade it.
```bash
hwclock --hctosys
apt update && apt upgrade
shutdown -r now
```

Install utilities (optional)
```bash
apt install tmux net-tools traceroute tcpdump
```


Create local user,


Install and secure MariaDB instance (write down root password)
```bash
apt install mariadb-server
mariadb-secure-installation
netstat -ntap | grep 3306
  tcp        0      0 127.0.0.1:3306          0.0.0.0:*               LISTEN      18957/mariadbd
```

Add Icinga repository:
ref. https://icinga.com/docs/icinga-2/latest/doc/02-installation/02-Ubuntu/
```bash



ls -la /etc/apt/sources.list.d/
    total 12
    drwxr-xr-x 2 root root 4096 Oct 25 13:49 .
    drwxr-xr-x 8 root root 4096 Oct 24 16:05 ..
    -rw-r--r-- 1 root root  236 Oct 25 13:49 jammy-icinga.list
```


Installing Icinga, IcingaWeb and IcingaWeb Director
```bash
apt install \
  icinga2 \
  icinga2-ido-mysql \
  icingacli \
  icingaweb2 \
  icingaweb2-common \
  icingaweb2-module-director \
  icingaweb2-module-idoreports \
  icingaweb2-module-ipl \
  icingaweb2-module-monitoring \
  icingaweb2-module-pdfexport \
  icingaweb2-module-reporting \
  libapache2-mod-php \

apt install \
  icinga-director-daemon \
  icinga-director-php \
  icinga-director-web \
  icinga-director


dpkg -i --force-overwrite /var/cache/apt/archives/icinga-php-incubator_0.20.0-1+ubuntu22.04_all.deb
dpkg -i --force-overwrite /var/cache/apt/archives/icinga-director-php_1.10.2-1+ubuntu22.04_all.deb

```





Questions during install
```
Configure database for icinga2-ido-mysql with dbconfig-common? [yes/no] yes
MySQL application password for icinga2-ido-mysql: (generate and provide pass)
```


Checking services are enabled and running:
```bash
systemctl status mariadb
systemctl status icinga2
systemctl status apache2
```


Check, that webserver is listening:
```bash
ss -ntap | grep apache
```


Check, that webserver is accessible and inspect connectivity until you see the desired traffic.
```bash
apt install tcpdump
tcpdump port 80

tail -f /var/log/apache2/*.log
```



```bash
tail -f /var/log/icinga2/icinga2.log
```




Create icinga2 setup token
```bash
icingacli setup token create
The newly generated setup token is: 5aabdfd054d9f0fa
systemctl restart apache2
```


Create IcingaWeb2 database (not Icinga)
```sql
CREATE DATABASE icingaweb2;
GRANT ALL ON icingaweb2.* TO icingaweb2@'localhost' IDENTIFIED BY '(stong-password)';

```


After token is successfully generated, open URL and provide token ID.
http://(host)/icingaweb2/setup

Check all modules, [Next]
Provide IcingaWeb2 DB credentials. [Validate], [Next]




Configure Monitoring IDO Resource (created during apt install icinga2-ido-mysql):
```text
Resource Name: icinga_ido
DB Type: MySQL
Host: localhost
DB Name: icinga2
Username: icinga2
Password: (provided)
Character Set: utf8mb4
```
[Validate], [Next]


Create API user in order for IcingaWeb2 to command or control Icinga2 (process)
```bash
vi /etc/icinga2/features-available/api.conf
# EDIT #
# add another user
object ApiUser "icingaweb2" {
  password = "newpass"
  // permissions = [ "status/query", "actions/*", "objects/modify/*", "objects/query/*" ]
  permissions = [ "*" ]
}
# EDIT #

# configure icinga
icinga2 api setup
systemctl restart icinga2

# check that Icinga2 is now listening for API queries
ss -ntap | grep 5665
LISTEN    0      4096                    *:5665                   *:*     users:(("icinga2",pid=21383,fd=18))
```








# configure IcingaWeb2 Director


create system user for icingadirector (to run systemctl icinga-director service (daemon))
```bash
useradd -r -g icingaweb2 -d /var/lib/icingadirector -s /bin/false icingadirector
```

# create database for director
mysql -u root -p
# add resource (specify character set is lowercase 'utf8', utf8mb4 will not work (for time of writing, 2021 01 27 /A)):
CREATE DATABASE director CHARACTER SET 'utf8mb4';
GRANT ALL ON director.* TO director@'localhost' IDENTIFIED BY 'newpass';
Icingaweb2, Configuration, Application, Resources, [Create New Resource]
Resource Type: SQL Database
Resource Name: director
Database Type: MySQL
Host: localhost
Port:
Database name: director
Username: director
Password: director
Character set: utf8
[validate configuration]
    The configuration has been successfully validated.
    Validation Log
    Connection to director as director on localhost: successful
    have_ssl: DISABLED
    protocol_version: 10
    version: 10.3.27-MariaDB
    version_compile_os: Linux
[save changes]

# configure icinga director
icingaweb2, Configuration, Modules, director, Configuration
DB resource: director_db
[create database schema]


Icinga Director,
DB Source: [icingaweb2_db], [Create schema]
---------

























# 2021 01 27  * updated

NO PACKAGES IN REPOSITORY
at the moment of writing, icinga packages were not available in RHN for RH Satellites
subscribed to Icinga_RHEL8_Icinga_RHEL8




# ICINGA (master installation)

# enable REPOS, subscribe if needed
yum repolist
yum update
yum install icinga2 icinga2-selinux
systemctl enable icinga2 && systemctl restart icinga2 && systemctl status icinga2
icinga2 feature list

yum install icingaweb2 icingaweb2-selinux icingacli

# if you wish to use EPEL's plugins, install them with
yum install nagios-plugins-all
# otherwise install them manually
[...]

# yum install mariadb-server mariadb
# use better module installation instead
yum module install mariadb
systemctl enable mariadb && systemctl start mariadb

# secure mariadb installation (set root pass, disable its remote access)
mysql_secure_installation

# install icinga--mariadb connector
yum install icinga2-ido-mysql

# create database, user and tables
mysql -u root -p
  CREATE DATABASE icinga;
  # you may create user and grand using same command
  # CREATE USER icinga@localhost IDENTIFIED BY 'newpass';
  # GRANT SELECT, INSERT, UPDATE, DELETE, DROP, CREATE VIEW, INDEX, EXECUTE ON icinga.* TO 'icinga'@'localhost';
  GRANT SELECT, INSERT, UPDATE, DELETE, DROP, CREATE VIEW, INDEX, EXECUTE ON icinga.* TO 'icinga'@'localhost' IDENTIFIED BY '(newpass)';
  FLUSH PRIVILEGES;
  quit
mysql -u root -p icinga < /usr/share/icinga2-ido-mysql/schema/mysql.sql

# determine credentials
vi /etc/icinga2/features-available/ido-mysql.conf
  uncomment and update credentials
ln -s /etc/icinga2/features-available/ido-mysql.conf /etc/icinga2/features-enabled/ido-mysql.conf
systemctl restart icinga2

# better to install using module command and check that it is running
# yum install httpd
yum module install httpd
systemctl enable httpd && systemctl start httpd
netstat -ntap | grep -e 80 -e 443

# configure icinga
icinga2 api setup
systemctl restart icinga2

# set new pass for root API user
vi /etc/icinga2/conf.d/api-users.conf

# add another user
object ApiUser "icingaweb2" {
  password = "newpass"
  // permissions = [ "status/query", "actions/*", "objects/modify/*", "objects/query/*" ]
  permissions = [ "*" ]
}
systemctl restart icinga2

# check which php version you have with
php -v
# you might need to install php7 version:
# yum install rh-php71 rh-php71-php-mysqlnd
# systemctl enable rh-php71-php-fpm.service && systemctl start rh-php71-php-fpm.service

# check for FilesMatch, if using php-fpm
vi /etc/httpd/conf.d/icingaweb2.conf
# restart php, if changed needed to apply
# systemctl restart rh-php71-php-fpm.service && systemctl status rh-php71-php-fpm.service

# generate new token, copy-paste into notepad, you will need it
icingacli setup token create
  The newly generated setup token is: 51223xxxxxxx0f12

# create table in DB for icingaweb2
mysql -u root -p
CREATE DATABASE icingaweb2;
GRANT ALL ON icingaweb2.* TO icingaweb2@localhost IDENTIFIED BY '(newpass)';

# does not exist in repo, comes from EPEL, better is "GraphicsMagick.x86_64 : An ImageMagick fork, offering faster image generation and better quality"
# yum install ImageMagick
# causes dependecies error
# yum install ImageMagick-devel
# source /opt/rh/rh-php71/enable
# /opt/rh/rh-php71/root/bin/pecl install imagick




# server firewall
# open firewall, if needed tcp/(80,443)
vi /etc/sysconfig/iptables

### ## #
# Icinga welcomes.
### ## #
-A INPUT -m state --state NEW -m tcp -p tcp -s xxx.xxx.xx.xxxx/21 --dport 5665 -j ACCEPT -m comment --comment "Icinga listens for agents."
-A INPUT -m state --state NEW -m tcp -p tcp -s xxx.xxx.xx.xx/21 -m multiport --dports 80,443 -j ACCEPT -m comment --comment "Icinga listens for http(s) connections."

# reload firewall and check
iptables-restore < /etc/sysconfig/iptables
iptables -L -n -v --line-numbers | grep Icinga

# github? no github, please.
# for github
open firewall rules here

# at this point Icingaweb2 should be accessible via browser
https://localhost/icingaweb2

# proceed with setup instractions, provided by wizard
# provide token generate earlier or, you forgot it already, recall it with:
icingacli setup token show

# check that icinga is happy with internal checks
# I got:
  The PHP module Imagick is missing.
# but will work on it in the future.

# plan, how authentication will happen on your instance and apply chosen way

# local authentication = "database" scenario earlier created)
Authentication Type: Database
[next]
Resource Name: icingaweb2
Database Type: MySQL
Host: localhost
Database name: icingaweb2
Username: icingaweb2
Passowrd: (pass)
# if you know what are you doing, specify yours, other very advised to use:
Character Set: utf8mb4
[Validate configuration]
  "The configuration has been successfully validated."
[next]
Authentication Backend: Backend Name: icingaweb2
[next]
# create admin user in icingaweb2
Administration
Username: admin
Password: (newpass)
Repeat password: (repeat newpass)
[next]
# application configuration left untoched
Show Stacktraces [x]
Show Application State Messages [x]
User Preference Storage Type: database
logging type: syslog
logging level: error
application prefix: icingaweb2
facility: user
[next]
[next]
[next]

Monitoring Backend
Backend Name: icinga
Backend Type: IDO
[next]

# now it is time to tell to IcingaWeb2 where Icinga2 stores its data
Monitoring IDO Resource
Resource Name: icinga_ido
Database Type: MySQL
Host: localhost
Port:
Database Name: icinga
Username: icinga
Password: (pass)
Character Set: utf8mb4
[validate configuration]
    The configuration has been successfully validated.
    Validation Log
    Connection to icinga as icinga on localhost: successful
    have_ssl: DISABLED
    protocol_version: 10
    version: 10.3.27-MariaDB
    version_compile_os: Linux
[next]

# how do we going to tell icinga instance what to do
Command Transport
Transport Name: icinga2
Transport Type: Icinga 2 API
Host: localhost
Port: 5665
# created earlier
API Username: icingaweb2
API Password: (pass)
[validate configuration]
    The configuration has been successfully validated.
[next]
Protected Custom Variables: *pw*,*pass*,community
[next]
[finish]
    Congratulations! Icinga Web 2 has been successfully set up.
[Login to Icinga Web 2]

# !! ready !! login with your admin account









#
# installing director (adding hosts/services)
#

# assuming at this point that firewall is opened towards github servers
iptables-restore < /etc/sysconfig/iptables
iptables -L -n -v --line-numbers | grep git
5        0     0 ACCEPT     tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            multiport dports 80,443 tcp match-set github dst
# easy way:
yum install git

# installing required module dependencies first
https://github.com/Icinga/icingaweb2-module-ipl/blob/master/README.md
# check for latest release number and adjust MODULE_VERSION variable below:
https://github.com/Icinga/icingaweb2-module-ipl/releases

# prepare download directory to avoid mess and keep places clean and tidy
sudo
cd
mkdir -p downloads/modules4icinga
cd downloads/modules4icinga/

# check that icingaweb2 modules directory exists and is not empty:
ls -la /usr/share/icingaweb2/modules

# create installation script
vi install_icinga_module.sh
---snip---
# paste following code below:
#
# 2020 01 27  + init: this script written to install/update modules for icinga /A
#

MODULES_PATH="/usr/share/icingaweb2/modules"

# https://github.com/Icinga/icingaweb2-module-ipl/releases
MODULE_NAME=ipl
MODULE_VERSION=v0.5.0
REPO="https://github.com/Icinga/icingaweb2-module-${MODULE_NAME}"
rm -rf ${MODULES_PATH}/${MODULE_NAME}
git clone ${REPO} "${MODULES_PATH}/${MODULE_NAME}" --branch "${MODULE_VERSION}"
icingacli module enable "${MODULE_NAME}"

# https://github.com/Icinga/icingaweb2-module-incubator/releases
MODULE_NAME=incubator
MODULE_VERSION=v0.6.0
REPO="https://github.com/Icinga/icingaweb2-module-${MODULE_NAME}"
rm -rf ${MODULES_PATH}/${MODULE_NAME}
git clone ${REPO} "${MODULES_PATH}/${MODULE_NAME}" --branch "${MODULE_VERSION}"
icingacli module enable "${MODULE_NAME}"

# https://github.com/Icinga/icingaweb2-module-reactbundle/releases
MODULE_NAME=reactbundle
MODULE_VERSION=v0.8.0
REPO="https://github.com/Icinga/icingaweb2-module-${MODULE_NAME}"
rm -rf ${MODULES_PATH}/${MODULE_NAME}
git clone ${REPO} "${MODULES_PATH}/${MODULE_NAME}" --branch "${MODULE_VERSION}"
icingacli module enable "${MODULE_NAME}"

# https://github.com/Icinga/icingaweb2-module-director/releases
MODULE_NAME=director
MODULE_VERSION=v1.8.0
REPO="https://github.com/Icinga/icingaweb2-module-${MODULE_NAME}"
rm -rf ${MODULES_PATH}/${MODULE_NAME}
git clone ${REPO} "${MODULES_PATH}/${MODULE_NAME}" --branch "${MODULE_VERSION}"
icingacli module enable "${MODULE_NAME}"

ls -la ${MODULES_PATH}
icingacli module list
echo "Done."
---snip---

# make script executable and run it (you will need it in the future to update modules)
chmod +x ./install_icinga_module.sh
./install_icinga_module.sh
[...]
---snip---
total 4
drwxr-xr-x. 10 root root  130 Jan 27 15:17 .
drwxr-xr-x.  7 root root   80 Jan 27 10:58 ..
drwxr-xr-x. 11 root root 4096 Jan 27 15:17 director
drwxr-xr-x.  6 root root  124 Jan 27 10:58 doc
drwxr-xr-x.  6 root root  232 Jan 27 15:17 incubator
drwxr-xr-x.  6 root root  205 Jan 27 15:17 ipl
drwxr-xr-x.  7 root root  136 Jan 27 10:58 monitoring
drwxr-xr-x.  5 root root  169 Jan 27 15:17 reactbundle
drwxr-xr-x.  5 root root   71 Jan 27 10:58 setup
drwxr-xr-x.  5 root root   70 Jan 27 10:58 translation
MODULE         VERSION   STATE     DESCRIPTION
director       1.8.0     enabled   Director - Config tool for Icinga 2
doc            2.8.2     enabled   Documentation module
incubator      0.6.0     enabled   Incubator provides bleeding-edge libraries
ipl            v0.5.0    enabled   The Icinga PHP library
monitoring     2.8.2     enabled   Icinga monitoring module
reactbundle    0.8.0     enabled   ReactPHP-based 3rd party libraries

Done.
---snip---


https://github.com/Icinga/icingaweb2-module-director/blob/master/doc/02-Installation.md
# installing module dependencies (repeat until Dependencies resolved. Nothing to do. Complete!)
yum install php-mysqlnd php-curl php-iconv php-pcntl php-process php-sockets php-mbstring php-json

# create database for director
mysql -u root -p
# add resource (specify character set is lowercase 'utf8', utf8mb4 will not work (for time of writing, 2021 01 27 /A)):
CREATE DATABASE director CHARACTER SET 'utf8';
GRANT ALL ON director.* TO director@localhost IDENTIFIED BY 'newpass';
Icingaweb2, Configuration, Application, Resources, [Create New Resource]
Resource Type: SQL Database
Resource Name: director
Database Type: MySQL
Host: localhost
Port:
Database name: director
Username: director
Password: director
Character set: utf8
[validate configuration]
    The configuration has been successfully validated.
    Validation Log
    Connection to director as director on localhost: successful
    have_ssl: DISABLED
    protocol_version: 10
    version: 10.3.27-MariaDB
    version_compile_os: Linux
[save changes]

# configure icinga director
icingaweb2, Configuration, Modules, director, Configuration
DB resource: director_db
[create database schema]

# kickstart wizard (if fresh install you do not need to import anything)
endpoint: (hostname), if not sure, use FQDN here
hostname: (hostname), if not sure, use FQDN here
Port: 5665
API user: icingaweb2
Password: (pass)

# configuring daemon
useradd -r -g icingaweb2 -d /var/lib/icingadirector -s /bin/false icingadirector
install -d -o icingadirector -g icingaweb2 -m 0750 /var/lib/icingadirector
cp "/usr/share/icingaweb2/modules/director/contrib/systemd/icinga-director.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable icinga-director && systemctl start icinga-director && systemctl status icinga-director

# check in icinga instance, should be fine now:
https://(host)/icingaweb2/director/health
https://(host)/icingaweb2/director/daemon

## at this point we need to create master in new zone
# firstly empty everything from zones and certs
rm /var/lib/icinga2/certs/*
rm -rf /var/lib/icinga2/api/zones/*
rm -rf /var/lib/icinga2/api/zones/zones-stage/*

# start configuration
icinga2 node wizard
---snip---
Welcome to the Icinga 2 Setup Wizard!
We will guide you through all required configuration details.
Please specify if this is an agent/satellite setup ('n' installs a master setup) [Y/n]: n
Starting the Master setup routine...
Please specify the common name (CN) [(hostname)]: (hostname)
Reconfiguring Icinga...
Checking for existing certificates for common name '(hostname)'...
Certificates not yet generated. Running 'api setup' now.
Generating master configuration for Icinga 2.
'api' feature already enabled.
Master zone name [master]: (new zone name)
Default global zones: global-templates director-global
Do you want to specify additional global zones? [y/N]: n
Please specify the API bind host/port (optional):
Bind Host []:
Bind Port []:
Do you want to disable the inclusion of the conf.d directory [Y/n]:
Disabling the inclusion of the conf.d directory...
Checking if the api-users.conf file exists...
Done.
Now restart your Icinga 2 daemon to finish the installation!
----snip---
systemctl restart icinga2

# new cert should be generated in
ls -la /var/lib/icinga2/certs

# kickstarter to import freshly defined master configuration
icingaweb2, configuration, modules, director, configuration
kickstart wizard:
endpoint name: (hostname of master)
icinga host: localhost
port: 5665
API user: icingaweb2
password: (pass)
[Run import]
# examine that only necessary objects are imported
# (clean installation on moment of writing contains about 241 object creations/modifications)
icingaweb2, icinga director, activity log
# on last page you should see your freshly zone created
# when sure, deploy configuration
icingaweb2, icinga director, activity log, [Deploy 241 pending changes]

# you should see new config files appeared in
ls -la /var/lib/icinga2/api/zones

# during node setup, ticketsalt should be generated, but
# check that it is updated, otherwise generate and modify file
vi /etc/icinga2/constants.conf

# during node setup, wizard ask to disable default checks, otherwise
mv /etc/icinga2/conf.d/services.conf /etc/icinga2/conf.d/services.conf.20191021

# uncomment and enable, set 'true'
vi /etc/icinga2/features-enabled/api.conf
  ticket_salt = TicketSalt

# enable features
icinga2 feature enable command
icinga2 feature enable perfdata

# notifications
yum install postfix
systemctl enable postfix && systemctl start postfix && systemctl status postfix
icinga2 feature enable notification && systemctl restart icinga2

# selinux
semanage fcontext -a -t nagios_notification_plugin_exec_t "/data/home/icinga/checks/local(/.*)?"
restorecon -R /data/home/icinga/checks/local/


# module:  reporting
download https://github.com/Icinga/icingaweb2-module-reporting/archive/master.zip
upload
cd /usr/share/icingaweb2/modules
install -d -m 0755 "${ICINGAWEB_MODULEPATH}/reporting"
unzip
mysql -u root -p
CREATE DATABASE reporting;
GRANT SELECT, INSERT, UPDATE, DELETE, DROP, CREATE VIEW, INDEX, EXECUTE ON reporting.* TO reporting@localhost IDENTIFIED BY '(pass)';
# create template table first, otherwise 1005 error, cause key does not exist
mysql -p -u root reporting < schema/mysql.sql
Configuration -> Application -> Resources menu > create new resouce. icingaweb_reporting_db, reporting, reporting, utf8mb4.
Configuration -> Modules -> reporting -> Backend, icingaweb_reporting_db
cp /usr/share/icingaweb2/modules/reporting/config/systemd/icinga-reporting.service /etc/systemd/system/icinga-reporting.service
systemctl enable icinga-reporting.service
systemctl start icinga-reporting.service
(pdfexport requires https://github.com/Icinga/icingaweb2-module-pdfexport/blob/master/doc/02-Installation.md)


#######################################################################################
# script installation
# check connectivity
curl -k -s -m 2 https://(host):5665/ >/dev/null && echo "5665 OK" || echo "5665 NOT OK"
# (host): add repo to host
yum repolist
yum install icinga2 nagios-plugins-all
# download host/agent/script, execute ./icinga.sh
icinga2 feature enable command api
icinga2 feature disable checker
systemctl enable icinga2 && systemctl restart icinga2




# console installation from node
(host):/data/home/(you)# icinga2 node wizard
Welcome to the Icinga 2 Setup Wizard!
We will guide you through all required configuration details.
Please specify if this is an agent/satellite setup ('n' installs a master setup) [Y/n]: Y
Starting the Agent/Satellite setup routine...
Please specify the common name (CN) [(host)]:
Please specify the parent endpoint(s) (master or satellite) where this node should connect to:
Master/Satellite Common Name (CN from your master/satellite node): (host)
Do you want to establish a connection to the parent node from this node? [Y/n]: y
Please specify the master/satellite connection information:
Master/Satellite endpoint host (IP address or FQDN): (host)
Master/Satellite endpoint port [5665]:
Add more master/satellite endpoints? [y/N]: n
Parent certificate information:
 Subject:     CN = (host)
 Issuer:      CN = Icinga CA
 Valid From:  Sep 29 11:23:06 2019 GMT
 Valid Until: Sep 25 11:23:06 2034 GMT
 Fingerprint: 39 60 1B AE D0 93 1E 36 89 4E 5E 04 E1 C5 80 1B 57 CC 0C D6
Is this information correct? [y/N]: y
Please specify the request ticket generated on your Icinga 2 master (optional).
 (Hint: # icinga2 pki ticket --cn '(host)'): 8bc7aa3167870788b8xxx85b8fe1f5310ffbd
Please specify the API bind host/port (optional):
Bind Host []:
Bind Port []:
Accept config from parent node? [y/N]: y
Accept commands from parent node? [y/N]: y
Reconfiguring Icinga...
Disabling feature notification. Make sure to restart Icinga 2 for these changes to take effect.
Enabling feature api. Make sure to restart Icinga 2 for these changes to take effect.
Local zone name [(host)]:
Parent zone name [master]: (host)
Default global zones: global-templates director-global
Do you want to specify additional global zones? [y/N]: n
Do you want to disable the inclusion of the conf.d directory [Y/n]:
Disabling the inclusion of the conf.d directory...
Done.

# Now restart your Icinga 2 daemon to finish the installation!
(host):/data/home/(you)# systemctl restart icinga2
icinga2 feature enable command api
icinga2 feature disable checker
systemctl restart icinga2
