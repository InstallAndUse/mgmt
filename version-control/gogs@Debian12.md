
```bash
apt -y update
apt -y install git
```

Developer has no official own repo, packager.io will be used in order to maintain updates.
```bash
wget -qO- https://dl.packager.io/srv/gogs/gogs/key | sudo apt-key add -
wget -O /etc/apt/sources.list.d/gogs.list \
    https://dl.packager.io/srv/gogs/gogs/main/installer/debian/12.repo
apt update
apt -y install gogs
ss -ntap | grep 6000
```
```
LISTEN    0      4096               *:6000                *:*     users:(("gogs",pid=69825,fd=3))
```

Database install, secure and configure
```bash
apt install mariadb-server
mysql_secure_installation
mysql -u root -p
```
```sql
CREATE DATABASE IF NOT EXISTS gogs;
CREATE USER 'gogs'@'localhost' IDENTIFIED BY 'pass';
GRANT ALL PRIVILEGES ON gogs.* TO 'gogs'@'localhost';
FLUSH PRIVILEGES;
```


Webserver (Nginx) installation and configuration
```bash
apt install -y nginx
```
```bash
vi /etc/nginx/sites-available/gogs.2dz.fi.conf
```
```
# TODO: review
server {
    listen         6000;
    server_name    gogs.2dz.fi;
    location / {
        proxy_pass http://localhost:6000;
    }
}
```
Enable config, test and restart
```bash
ln -s /etc/nginx/sites-available/gogs.2dz.fi.conf /etc/nginx/sites-enabled/
nginx -t
systemctl restart nginx
```
Navigate to http://host/install using WebBrowser
connect to DB using gogs's user


```bash
$ ./gogs admin create-user --name tmpuser --password tmppassword --admin --email email@example.com
```


Make config backup and configure:
```bash
cd /etc/gogs/conf
cp app.ini app.ini.2024-02-25--1743
```

edit configuration file
```bash
vi app.ini
```

```
# TODO: include recent config file
```


Enable registration captcha and email confirmation


restart gogs with
```bash
systemctl restart gogs
```
because of
```bash
systemctl | grep  gogs
```
```
gogs-web-1.service        loaded active running   gogs-web-1.service
gogs-web.service          loaded active running   gogs-web.service
gogs.service              loaded active running   gogs.service
```

after looking into
```bash
/opt/gogs# fgrep -irn mailer .
```
turns out, that:
```
[...]
./CHANGELOG.md:50:- Configuration section `[mailer]` is no longer used, please use `[email]`.
./CHANGELOG.md:190:- Configuration section `[mailer]` is deprecated and will end support in 0.13.0, please start using `[email]`.
```
begin to understand, that configuration's variables' names are outdated

looking into CHANGELOG.md
```
- Configuration section `[mailer]`  is no longer used, please use `[email]`.
- Configuration section `[service]` is no longer used, please use `[auth]`.
```
opened pull request
```
https://github.com/gogs/docs/pull/268
```






Ref:
```
https://gogs.io/docs/installation
https://gogs.io/docs/installation/install_from_packages
```