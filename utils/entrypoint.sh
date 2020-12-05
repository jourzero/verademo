#!/bin/bash

# Start and initialize DB
echo -e "\n-- Starting mariadb..."
service mysql start
service mysql status

echo -e "\n-- Initializating the DB..."
mysql < /app/utils/dbinit.sql

# Start tomcat and serve verademo app
echo -e "\n-- Starting Tomcat..."
/usr/local/tomcat/bin/startup.sh

# Tail the tomcat log
echo -e "\n-- Tailing the tomcat log..."
tail -f /usr/local/tomcat/logs/catalina.out