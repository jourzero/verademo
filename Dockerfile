# Use tomcat image since the app requires Tomcat (tomcat:latest := 9.0.40-jdk11-openjdk-buster)
FROM tomcat:latest 
EXPOSE 8080

# Install needed packages
RUN apt-get update && apt-get -y install lsb-release maven lsof curl mariadb-server

## Copy app files and use this as our base
COPY . /app
WORKDIR /app

# Build app and deploy it
RUN mvn package
RUN cp target/verademo.war /usr/local/tomcat/webapps

# Start/initialize DB and start tomcat server
CMD /app/utils/entrypoint.sh