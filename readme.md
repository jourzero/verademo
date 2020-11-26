# VeraDemo - Blab-a-Gag

## About

Blab-a-Gag is a fairly simple forum type application which allows:

-   users to post a one-liner joke
-   users to follow the jokes of other users or not (listen or ignore)
-   users to comment on other users messages (heckle)

### URLs

`/reset` will reset the data in the database with a load of:

-   users
-   jokes
-   heckles

`/feed` shows the jokes/heckles that are relevant to the current user.

`/blabbers` shows a list of all other users and allows the current user to listen or ignore.

`/profile` allows the current user to modify their profile.

`/login` allows you to log in to your account

`/register` allows you to create a new user account

`/tools` shows a tools page that shows a fortune or lets you ping a host.

## Build

To build Verademo [Maven](https://maven.apache.org) is required.

`mvn package` will build the web application and output a war file to `target/verademo.war`. This war file can be uploaded to Veracode for static analysis.

## Configure

To run Verademo [MySQL](https://www.mysql.com/) and [Tomcat](https://tomcat.apache.org/) are required.

The simplest way to aquire these on MacOS is via [Homebrew](http://brew.sh/). Install Homebrew then:

    brew install mysql tomcat

### Database

Set up a database in MySQL called `blab` with a user of `blab` and password `z2^E6J4$;u;d`

## Run

Deploy the build output war file to Tomcat.

Open `/reset` in your browser and follow the instructions to prep the database

Login with a username/password as defined in `Utils.java`

## AWS Deployment

Verademo will also run out-of-the-box in AWS. Simply upload the `target/verademo.war` file into a Tomcat Elastic Beanstalk environment (with associated Amazon RDS). The database credentials listed above are not required when running in AWS.

On the first environment deployment, a script will automatically setup the database. Subsequent application re-deploys (without environment re-deploy), or application server restarts will not alter the database.

## Exploitation Demos

See the `docs` folder

## Docker notes

```bash
# Build image
$ docker build -t verademo .

# Start container which drops into bash (don't use --rm to keep it after exit)
$ docker run -it -p 127.0.0.1:8080:8080 --name verademo verademo

# Install MySQL
root@809a822f230f:/app# cd utils
root@809a822f230f:/app/utils# ./install_mysql.sh
[...]
  1. MySQL Server & Cluster (Currently selected: mysql-8.0)  3. MySQL Preview Packages (Currently selected: Disabled)
  2. MySQL Tools & Connectors (Currently selected: Enabled)  4. Ok
Which MySQL product do you wish to configure? 1
[...]
  1. mysql-5.7  2. mysql-8.0  3. mysql-cluster-7.5  4. mysql-cluster-7.6  5. mysql-cluster-8.0  6. None
Which server version do you wish to receive? 1
[...]
  1. MySQL Server & Cluster (Currently selected: mysql-5.7)  3. MySQL Preview Packages (Currently selected: Disabled)
  2. MySQL Tools & Connectors (Currently selected: Enabled)  4. Ok
Which MySQL product do you wish to configure? 4
[...]
Enter root password: RETURN (leave blank)
[...]
[info] MySQL Community Server 5.7.32 is started.

# Create a blab user and database
root@ac06bd7a5274:/app/utils# mysql < create_user.sql

# Start Tomcat
root@ac06bd7a5274:/app/utils# ./start_tomcat.sh

# Browse to http://localhost:8080/verademo
# Click Reset menu and Reset button
# Notice a bunch of data creation activities in the Tomcat outputs
# Click Register menu and register a user
# Play!


# Restart container after exit (to avoid recreating )
$ docker start -i verademo
root@4d76084d8877:/app#
```
