#!/bin/bash
OUT_DIR=target/debug/shared
mkdir -p $OUT_DIR
gcc -fPIC src/stomp.c -shared -o$OUT_DIR/libstomp.so -I. -I/usr/include/apr-1.0 -lapr-1
