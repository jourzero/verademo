# User tomcat image since the app requires Tomcat
#FROM tomcat:9.0
#FROM tomcat:8
# tomcat:latest corresponds to: 9.0.40-jdk11-openjdk-buster
FROM tomcat:latest 
EXPOSE 8080

RUN apt-get update && apt-get -y install lsb-release maven lsof curl

## Copy app files and use this as our base
COPY . /app
WORKDIR /app

# Build app and deploy it
RUN mvn package
RUN cp target/verademo.war /usr/local/tomcat/webapps

# Run bash. For next steps, see Docker notes in readme.md.
CMD /bin/bash
