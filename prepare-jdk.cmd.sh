#!/bin/bash

[ -d /tmp/sub/jdk ] && exit 0

# ensure umask is consistent between environments
umask 0002

mkdir -p /tmp/sub/jdk/lib/server/
lz4 -d /jdk/lib/server/libjvm.so.lz4 /tmp/sub/jdk/lib/server/libjvm.so
ln -s -t /tmp/sub/jdk/lib /jdk/lib/* 2>/dev/null
