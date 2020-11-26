#!/bin/bash
set -x
wget https://dev.mysql.com/get/mysql-apt-config_0.8.16-1_all.deb
dpkg -i mysql-apt-config_0.8.16-1_all.deb 
apt-get update
apt-get install mysql-server
service mysql start