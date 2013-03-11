Welcome to libstomp
===================

libstomp is a c library used to talk the Stomp which is a simple to implement client protocol for
working with ActiveMQ and other messaging systems.

Getting Started
http://stomp.codehaus.org/Getting+Started+with+libstomp?refresh=1

Building
http://stomp.codehaus.org/Building+libstomp?refresh=1

Examples
http://stomp.codehaus.org/libstomp+Examples?refresh=1

We welcome contributions of all kinds, for details of how you can help
http://stomp.codehaus.org/Contributing

Please refer to the website for details of finding the issue tracker, email lists, wiki or IRC channel
http://stomp.codehaus.org/

Please help us make libstomp better - we appreciate any feedback you may have.

Enjoy!

-----------------
The Stomp team

Building libstomp client on linux
=====================

By Niklas Bivald on November 9, 2009 11:08 AM | Permalink | Comments (0)
STOMP (Streaming text oriented messaging protocol) is a wonderful protocol to use as simple messaging for real time applications and is integrated in (for example) Apache MQ and Orbited. However, all their clients are for online languages (php, perl, ruby) and the client was built using Mac.

Don't get me wrong, I love my mac, but my servers run linux. Here is how you do it (from http://www.jboss.org/community/wiki/buildingblacktie?decorator=print)

The entire next section is based from above mentioned source, albeit altered to fit Debian:

INSTALL LIBSTOMP

    svn co -r 85 http://svn.codehaus.org/stomp/trunk/c libstomp

ON LINUX

In order to create the library for use with our Stomp transport on Linux you need to make a couple of alterations:

    apt-get install libapr1
    apt-get install libapr1-dev
    Download the attached stomp.c.patch to your home directory (their src, my mirror)
    cd libstomp
    Create the following file as build.sh

    #!/bin/bash
    OUT_DIR=target/debug/shared
    mkdir -p $OUT_DIR
    gcc -fPIC src/stomp.c -shared -o$OUT_DIR/libstomp.so -I. -I/usr/include/apr-1.0 -lapr-1
    patch -p0 -i ~/stomp.c.patch
    ./build.sh


I've taken the liberty to mirror the patches as well.

stomp.c.patch
stompconnect.patch


1¡¢libstomp.tar.gz
http://svn.stomp.codehaus.org/browse/stomp/trunk/c/src
http://bivald.com/lessons-learned/2009/11/building_libstomp_client_on_li.html

2¡¢libstompa3linux.tar.gz
https://github.com/a3linux/libstomp
