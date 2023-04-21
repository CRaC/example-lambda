#!/bin/bash

# Ensure small PID, for privileged-less criu to be able to restore PID by bumping.
# But not too small, to avoid clashes with other occasional processes on restore.
exec /aws-lambda-rie /bin/bash -c '\
	while [ 128 -ge $(cat /proc/sys/kernel/ns_last_pid) ]; do :; done; \
	CRAC_CRIU_OPTS="--compress" \
	setsid /jdk/bin/java \
		-Xshare:off \
		-XX:-UsePerfData \
		-XX:CRaCCheckpointTo=/cr \
		-cp /function:/function/lib/* \
		-Dcom.amazonaws.services.lambda.runtime.api.client.NativeClient.libsBase=/function/lib/ \
		--add-opens java.base/java.util=ALL-UNNAMED \
		com.amazonaws.services.lambda.runtime.api.client.AWSLambda $0' "$@"
