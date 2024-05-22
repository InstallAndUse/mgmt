= PHP =

vi /etc/opt/rh/rh-php73/php.ini
; 2024-05-16  * for IcingaWeb to deploy vvvveeeeeeeery big config  /A
;             * still not enough /A
; memory_limit = 1024M
memory_limit = 2048M


vi /etc/opt/rh/rh-php73/php-fpm.d/www.conf
; Default 128M is not enough for reports
;php_admin_value[memory_limit] = 1024M
; 2024-05-16  * 1024 was not enough for IPAM query execition /A
php_admin_value[memory_limit] = 2048M




= MariaDB / MySQL=

```bash
vi /etc/my.cnf.d/server.cnf
[mysqld]
max_allowed_packet=100M
```
and restart DB
```bash
systemctl | grep db
systemctl restart rh-mariadb103-mariadb.service
```
or

```bash
mysql -u root -p
MariaDB [(none)]> SET GLOBAL max_allowed_packet=100000000;
MariaDB [(none)]> SHOW VARIABLES LIKE 'max_allowed_packet';
```
and remember to restart DB client, to renew session, in our case, IcingaWeb (which is PHP)
```bash
systemctl | grep php
systemctl restart rh-php73-php-fpm.service
```



= InfluxDB =

```bash
vi /etc/influxdb/influxdb.conf
```
```
# 2024-05-22  * because of two /16 subnets make for than 100k host objects, and tags in timeseries, limit need to be increased /A
max-values-per-tag=200000
```
```bash
systemctl restart influxdb
```