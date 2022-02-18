#!/bin/bash

/prepare-jdk.cmd.sh

lz4 -d /cr.tar.lz4  - | tar x -C /tmp/

/jdk/bin/java -XX:CRaCRestoreFrom=/tmp/cr
# exec /jdk/lib/criu restore -W . --shell-job --action-script /jdk/lib/action-script -D /tmp/cr/ -v1 --exec-cmd -- /jdk/lib/wait
