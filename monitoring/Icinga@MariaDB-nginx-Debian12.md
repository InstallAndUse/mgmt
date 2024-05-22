```
#
# HISTORY
#

# 2023-10-17  * initial run /A
# 2024-03-06  + cloned for Debian on nginx deployment /A
              + SSL cert generation /A
```

Create Debian x86_64 architecture VM instance (aarch64 has icingaweb2.9.5, which is NOT supporting php v8.1).
```bash
uname -a
```
Do not deploy Icinga onto arm64, second trial. Not supported, yet.


! Below assuming all commands are executed in the priveledged mode

Check that OS see Icinga's packages
```bash
apt list *icinga*
```


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


Install and secure MariaDB instance (write down root password)
In my case, this instance I deploy onto "GCP Cloud SQL", that is why I am missing this part.
Same checks apply, ensure DB connectivity from local machine to DB server.
```bash
apt install mariadb-server
mariadb-secure-installation
netstat -ntap | grep 3306
```
```
tcp        0      0 127.0.0.1:3306          0.0.0.0:*               LISTEN      18957/mariadbd
```

Add Icinga repository:
```bash
cat /etc/apt/sources.list.d/bookworm-icinga.list
```
```bash
deb     [signed-by=/usr/share/keyrings/icinga-archive-keyring.gpg] https://packages.icinga.com/debian icinga-bookworm main
deb-src [signed-by=/usr/share/keyrings/icinga-archive-keyring.gpg] https://packages.icinga.com/debian icinga-bookworm main
```


Installing Icinga, IcingaWeb and IcingaWeb Director
Positive remark, that a lot of modules has been packaged and are easily downloadable from major repos -
- there is no need to bring them separately and configure. :) good.

We are installing to utilize nginx as a webserver, but common installation will deploy everything onto Apache.
No issues with it, let's install and reconfigure it later. Doing so will apply all post-install automatic configuration.
Order matters.
```bash
apt install \
    icinga2 \
    icinga2-ido-mysql \
    icingaweb2

#? icingacli \
#? icingaweb2-common \
#? icingaweb2-common \
#? icingaweb2-module-director \
#? icingaweb2-module-idoreports \
#? icingaweb2-module-monitoring \
#? icingaweb2-module-pdfexport \
#? icingaweb2-module-reporting \
#? libapache2-mod-php \
#? icingaweb2-module-ipl

apt install \
    icinga-director \
    icinga-director-daemon \
    icinga-director-php \
    icinga-director-web

apt install \
    php-fpm \
    php-imagick

#? dpkg -i --force-overwrite /var/cache/apt/archives/icinga-php-incubator_0.20.0-1+ubuntu22.04_all.deb
#? dpkg -i --force-overwrite /var/cache/apt/archives/icinga-director-php_1.10.2-1+ubuntu22.04_all.deb
```



Questions during install
```
Configure database for icinga2-ido-mysql with dbconfig-common? [yes/no] yes
MySQL application password for icinga2-ido-mysql: (generate and provide pass)
If hit [Enter] and did not provide pass, it can be found here:
```
```bash
cat /etc/dbconfig-common/icinga2-ido-mysql.conf | grep -v \#
```


Checking services are enabled and running:
```bash
systemctl status mariadb
systemctl status icinga2
systemctl status apache2
```

Let's disable apache, as we shall not use it
```bash
systemctl disable apache2
systemctl mask apache2
```

Figure out where does php-fpm socket configured
```bash
cat /etc/php/8.2/fpm/pool.d/www.conf | grep fpm.sock
```
```bash
listen = /run/php/php8.2-fpm.sock
```


Configure nginx for Icingaweb:
```bash
vi /etc/nginx/sites-enabled/mon.2dz.fi.conf
```
In order Certbot to work in automatic mode, ensure server block has proper server_name value to match certificate
```
server {
  server_name ici.2dz.fi;
```

Check, that webserver is listening:
```bash
sudo ss -ntap | grep -E 'apache|nginx'
```

Check, that webserver is accessible and inspect connectivity until you see the desired traffic.
```bash
apt install tcpdump
tcpdump port 80
tail -f /var/log/nginx/*.log
```

... and Icinga is responding
```bash
tail -f /var/log/icinga2/*
tail -f /var/log/icingaweb2/*
```


Enable SSL for webserver (installing CertBot to manage certificates)
```bash
apt install certbot python3-certbot-nginx
certbot --nginx -d ici.2dz.fi
```
Provide e-mail address for communication and read terms of use, reply 'Y'.
Cert and key should be located in:
```
Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/ici.2dz.fi/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/ici.2dz.fi/privkey.pem
```
And nginx's config file updated in:
(listen 443 ssl and redirect sections added)
```bash
vi /etc/nginx/sites-enabled/ici.2dz.fi.conf
```
Check and reload nginx config
```bash
systemctl reload nginx
```
Query status of the timer and test renewal
```bash
systemctl status certbot.timer
certbot renew --dry-run
```



At this point, we know, that Icinga2 local install created local MariaDB database called 'icinga2'
```bash
mysql -u root -p
```
```sql
MariaDB [(none)]> SHOW DATABASES;
+--------------------+
| Database           |
+--------------------+
| icinga2            |
[...]
6 rows in set (0.005 sec)

MariaDB [(none)]> USE icinga2;
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Database changed
MariaDB [icinga2]> SHOW TABLES;
+----------------------------------------+
| Tables_in_icinga2                      |
+----------------------------------------+
| icinga_acknowledgements                |
| icinga_commands                        |
| icinga_commenthistory                  |
| icinga_comments                        |
[...]
```

Configuration file for DB connection is:
```bash
vi /etc/icinga2/features-available/ido-mysql.conf
```
```
/**
 * The db_ido_mysql library implements IDO functionality
 * for MySQL.
 */

library "db_ido_mysql"

object IdoMysqlConnection "ido-mysql" {
  user = "icinga2",
  password = "HlrMpaaaaarl",
  host = "localhost",
  database = "icinga2"
}
```

In my case, I am connecting Icinga's main DB to GCP Cloud SQL.
New database need to be created:
Google Cloud Console, Cloud SQL, Choose instance, Databases, [Create database],
```
Database name: ici_2dz_fi-icinga2
Charset: utf8mb4
Collation: Default collation
[Create]

Database name: ici_2dz_fi-icingaweb2
Charset: utf8mb4
Collation: Default collation
[Create]
```

Then we need to create user for it: Users, [Add user account]
Create user 'icinga2' and generate pass, save it. Limit to specific IP address, if/when known.
Create user 'icingaweb2' and generate pass, save it. Limit to specific IP address, if/when known.

Test connection from instance to DB
```bash
mysql -h 172.21.xxx.xxx -u icinga2 -p
```

```
Enter password:
Welcome to the MariaDB monitor.  Commands end with ; or \g.
Your MySQL connection id is 18412
Server version: 8.0.31-google (Google)
```

Recreate schema in databases
```bash
mysql -h 172.21.xxx.xxx -u root -p (dbname icinga2)    < /usr/share/icinga2-ido-mysql/schema/mysql.sql
mysql -h 172.21.xxx.xxx -u root -p (dbname icingaweb2) < /usr/share/icingaweb2/schema/mysql.schema.sql
```

Grant permissions to users on created database
```bash
mysql -h 172.21.xxx.xxx -u root -p
```

```sql
GRANT ALL PRIVILEGES ON ici_2dz_fi-icinga2.*    TO 'icinga2'@'%';
GRANT ALL PRIVILEGES ON ici_2dz_fi-icingaweb2.* TO 'icingaweb2'@'%';
FLUSH PRIVILEGES;
SHOW GRANTS FOR icinga2;
SHOW GRANTS FOR icingaweb2;
```

Check permissions
```
MySQL [(none)]> SHOW GRANTS FOR icinga2;
+-----------------------------------------------------------------+
| Grants for icinga2@%                                            |
+-----------------------------------------------------------------+
[...]
| GRANT ALL PRIVILEGES ON `ici_2dz_fi-icinga2`.* TO `icinga2`@`%` |
[...]
MySQL [(none)]> SHOW GRANTS FOR icingaweb2;
+-----------------------------------------------------------------------+
| Grants for icingaweb2@%                                               |
+-----------------------------------------------------------------------+
[...]
| GRANT ALL PRIVILEGES ON `ici_2dz_fi-icingaweb2`.* TO `icingaweb2`@`%` |
```

Check again from instance:
```bash
mysql -h 172.21.xxx.xxx -u icinga2 -p
```

```sql
MySQL [(none)]> SHOW GRANTS FOR icinga2;
+-----------------------------------------------------------------+
| Grants for icinga2@%                                            |
+-----------------------------------------------------------------+
[...]
| GRANT ALL PRIVILEGES ON `ici_2dz_fi-icinga2`.* TO `icinga2`@`%` |
[...]
```

Reconfigure Icinga's DB and
```bash
vi /etc/icinga2/features-available/ido-mysql.conf
icinga2 feature enable ido-mysql
systemctl restart icinga2
icinga2 feature list
```

Create icinga2 setup token
```bash
icingacli setup token create
```

```
The newly generated setup token is: 6cd67209d6e6ff6e
```

```bash
systemctl restart nginx
```

After token is successfully generated, open URL and provide freshly generated token ID.
```
https://(host)/icingaweb2/setup
```

Check all modules, [Next]
Check requirements, install, if any [Refresh], [Next]
Provide IcingaWeb2 DB credentials. [Validate], [Next]
Authentication type: Databse [Next]



## Database Resource
```
Now please configure the database resource where to store users and user groups.
Note that the database itself does not need to exist at this time as it is going
to be created once the wizard is about to be finished.
(Translating: this is 'icingaweb2' DB created above.)
Resource Name: icingaweb_db
Database Type: MySQL
Host: (host)
Port: 3306
Database Name: icingaweb2
Username: icingaweb2
Password: (provided)
Character Set: utf8mb4
Use SSL: [ ]
[Validate Configuration], [Next]
```


## Schema is empty in DB, it need to be created:
## Database Setup
```
It seems that either the database you defined earlier does not yet exist and
cannot be created using the provided access credentials, the database does not
have the required schema to be operated by Icinga Web 2 or the provided access
credentials do not have the sufficient permissions to access the database.
Please provide appropriate access credentials to solve this.
```

# Authentication Backend
```
As you've chosen to use a database for authentication all you need to do now
is defining a name for your first authentication backend.
Backend Name: icingaweb2
```

# Administration
```
Now it's time to configure your first administrative account or group for Icinga Web 2.
Username: admin
Password *
Repeat password *
[Next]
```

# Application Configuration
```
Now please adjust all application and logging related configuration options to fit your needs.
Show Stacktraces [x]
Show Application State Messages [x]
Enable strict content security policy [ ]
Logging Type [Syslog]
Logging Level [Error]
Application Prefix: icingaweb2
Facility [user]
[Next]
Summary, [Next]
Welcome to the configuration of the monitoring module for Icinga Web 2! , [Next]
```

Create API user in order for IcingaWeb2 to command or control Icinga2 (process), add lines
```bash
vi /etc/icinga2/features-available/api.conf
```

```ini
object ApiUser "icingaweb2" {
  password = "newpass"
  // permissions = [ "status/query", "actions/*", "objects/modify/*", "objects/query/*" ]
  permissions = [ "*" ]
}
```

Configure icinga to enable API
```bash
icinga2 api setup
systemctl restart icinga2
```

Check that Icinga2 is now listening for API queries
```bash
ss -ntap | grep 5665
```

```
LISTEN    0      4096                    *:5665                   *:*     users:(("icinga2",pid=21383,fd=18))
```

# Configure Monitoring IDO Resource (created during apt install icinga2-ido-mysql):
```ini
Resource Name: icinga_ido
DB Type: MySQL
Host: localhost
DB Name: icinga2
Username: icinga2
Password: (provided)
Character Set: utf8mb4
```

```
[Validate], [Next]
Monitoring Security, [Next]
Summary, [Finish]
```

In case of admin user is not created in DB:
```bash
mysql -h 172.21.xxx.xxx -u root -p
```

Use query below to change admin's password. After login and change pass:
```
l: admin p: admin
```

```sql
USE icingaweb2;
INSERT INTO `icingaweb_user` VALUES ('admin',1,'$2y$10$8kWWNgcSkZb7rmemZFNusOryxvriUBXFlo/R3Z8fWwVqOQpTDS9n6','2023-10-25 19:07:36','2024-03-07 06:17:56');
SELECT * FROM icingaweb_user;
```



# configure IcingaWeb2 Director
Check and create system user for icinga director (to run systemctl icinga-director service (daemon))
```bash
cat /etc/passwd | grep icinga
useradd -r -g icingaweb2 -d /var/lib/icingadirector -s /bin/false icingadirector
```

# create database for director
```bash
mysql -u root -p
```

# add resource (specify character set is lowercase 'utf8', utf8mb4 will not work:
```sql
CREATE DATABASE ici_2dz_fi_director CHARACTER SET utf8;
CREATE USER 'icingaweb2director'@'%' IDENTIFIED BY '(superpass)';
GRANT ALL ON ici_2dz_fi_director.* TO 'icingaweb2director'@'%';
FLUSH PRIVILEGES;
```

```
Icingaweb2, Configuration, Application, Resources, [Create New Resource]
Resource Type: SQL Database
Resource Name: ici_2dz_fi-director
Database Type: MySQL
Host: localhost
Port:
Database name: ici_2dz_fi-director
Username: icingaweb2director
Password: (superpass)
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
```

# configure icinga director
```
icingaweb2, Configuration, Modules, director, Configuration
DB resource: director_db
[create database schema]


Icinga Director,
DB Source: [icingaweb2_db], [Create schema]
```


ref
```
https://icinga.com/docs/icinga-2/latest/doc/02-installation/01-Debian/
```