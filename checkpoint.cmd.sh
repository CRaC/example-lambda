#!/bin/bash

detect_native_client() {
	/jdk/bin/java -cp /function:/function/lib/* /usr/local/lib/TryLoad.java $@
}

export AWS_NATIVE_CLIENT=$(detect_native_client /function/lib/jni/libaws-lambda-jni.*.so)

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
		-Dcom.amazonaws.services.lambda.runtime.api.client.runtimeapi.NativeClient.JNI=$AWS_NATIVE_CLIENT \
		--add-opens java.base/java.util=ALL-UNNAMED \
		com.amazonaws.services.lambda.runtime.api.client.AWSLambda $0' "$@"
