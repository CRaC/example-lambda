#!/bin/bash

lz4 -d /jdk.tar.lz4 - | tar x -C /tmp/
lz4 -d /cr.tar.lz4  - | tar x -C /tmp/

exec /tmp/jdk/bin/java -XX:CRaCRestoreFrom=/tmp/cr
