#!/bin/bash
# Run container, don't remove it when completed, name it with the directory name, publish on 4080
echo "Starting container ${PWD##*/}... To use the app, browse to http://127.0.0.1:4080/verademo"
docker run -it -p 127.0.0.1:4080:8080 --name ${PWD##*/} ${PWD##*/} $CMD 2>&1
