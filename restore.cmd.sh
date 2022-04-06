#!/bin/bash

/prepare-jdk.cmd.sh

lz4 -q -d /cr.tar.lz4  - | tar x -C /tmp/

/jdk/bin/java -XX:CRaCRestoreFrom=/tmp/cr
