#!/bin/bash

IOLIM=60m
DEV=/dev/nvme0n1
CPU=0.88

  dev() {   DEV=$1; }
iolim() { IOLIM=$1; }
  cpu() {   CPU=$1; }

s00_init() {

	if [ -z $JAVA_HOME ]; then
	       echo "No	JAVA_HOME specified"
	       return 1
	fi

	rm -rf jdk
	cp -r $JAVA_HOME jdk

	curl -L -o aws-lambda-rie https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/download/v1.3/aws-lambda-rie-$(uname -m) 
	chmod +x aws-lambda-rie
}

dojlink() {
	$JAVA_HOME/bin/jlink --bind-services --output jdk --module-path $JAVA_HOME/jmods --add-modules java.base,jdk.unsupported,java.sql
}

s01_build() {
	mvn compile dependency:copy-dependencies -DincludeScope=runtime
	docker build -t crac-lambda-checkpoint -f Dockerfile.checkpoint .
}

s02_start_checkpoint() {
	docker run \
		--privileged \
		--rm \
		--name crac-checkpoint \
		-v $PWD/aws-lambda-rie:/aws-lambda-rie \
		-v $PWD/cr:/cr \
		-p 8080:8080 \
		-e AWS_REGION=us-west-2 \
		crac-lambda-checkpoint
}

rawpost() {
        local c=0
        while [ $c -lt 20 ]; do
                curl -XPOST --no-progress-meter -d "$@" http://localhost:8080/2015-03-31/functions/function/invocations && break
                sleep 0.2
                c=$(($c + 1))
        done
}

post() {
        rawpost "{ Records : [ { body : \"${1}\" } ] }"
}

s03_checkpoint() {
        post checkpoint
        sleep 2
        post fini
	docker rm -f crac-checkpoint
}

s04_prepare_restore() {
	sudo rm -f cr/dump4.log # XXX
	docker build -t crac-lambda-restore -f Dockerfile.restore .
}

dropcache() {
        sync
        echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null
}

local_test() {
	docker run \
		--rm \
		--name crac-test \
		-v $PWD/aws-lambda-rie:/aws-lambda-rie \
		-p 8080:8080 \
		--device-read-bps $DEV:$IOLIM \
		--device-write-bps $DEV:$IOLIM \
		--cpus $CPU \
		--entrypoint '' \
		"$@"
}

s05_local_restore() {
	local_test crac-lambda-restore \
		/aws-lambda-rie /bin/bash /restore.cmd.sh
}

local_baseline() {
	local_test crac-lambda-baseline \
		/aws-lambda-rie /jdk/bin/java \
			-XX:-UsePerfData \
			-cp /function:/function/lib/* \
			com.amazonaws.services.lambda.runtime.api.client.AWSLambda \
			example.Handler::handleRequest
}

for i; do
	$i || break
done
