#!/bin/bash

LAMBDA_NAME=crac-test
LAMBDA_IMAGE=crac-test

IOLIM=60m
DEV=/dev/nvme0n1
CPU=0.88

  dev() {   DEV=$1; }
iolim() { IOLIM=$1; }
  cpu() {   CPU=$1; }

dojlink() {
	local JDK=$1
	rm -rf jdk
	$JDK/bin/jlink --bind-services --output jdk --module-path $JDK/jmods --add-modules java.base,jdk.unsupported,java.sql
	# XXX
	cp $JDK/lib/criu jdk/lib/
}

s00_init() {
	curl -L -o aws-lambda-rie https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/download/v1.3/aws-lambda-rie-$(uname -m)
	chmod +x aws-lambda-rie

	echo
	echo "Take the latest build of openjdk/crac and run: "$0" dojlink ./path/to/crac/jdk"
	echo "https://github.com/CRaC/openjdk-builds/actions/workflows/release.yml"

	#CRAC_VERSION=17-crac+2
	#curl -LO https://github.com/CRaC/openjdk-builds/releases/download/$CRAC_VERSION/jdk$CRAC_VERSION.tar.gz
	#tar axf jdk$CRAC_VERSION.tar.gz
	#dojlink jdk$CRAC_VERSION
}

s01_build() {
	mvn clean compile dependency:copy-dependencies -DincludeScope=runtime
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

make_cold_local() {
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
		--security-opt seccomp=$PWD/seccomp.json \
		"$@"
}

s05_local_restore() {
	local_test \
		crac-lambda-restore \
		/aws-lambda-rie /bin/bash /restore.cmd.sh
}

local_baseline() {
	local_test crac-lambda-checkpoint \
		/aws-lambda-rie /jdk/bin/java \
			-XX:-UsePerfData \
			-cp /function:/function/lib/* \
			-Dcom.amazonaws.services.lambda.runtime.api.client.NativeClient.libsBase=/function/lib/ \
			--add-opens java.base/java.util=ALL-UNNAMED \
			com.amazonaws.services.lambda.runtime.api.client.AWSLambda \
			example.Handler::handleRequest
}

ltest() {
	local_test \
		-v /home:/home \
		-v $PWD/logdir:/tmp/log \
		crac-lambda-restore \
		/bin/bash $PWD/restore.cmd.sh
}

s06_init_aws() {
	ACCOUNT=$(aws sts get-caller-identity | jq -r '.Account')
	echo export ACCOUNT=$ACCOUNT
	REGION=$(aws configure get region)
	echo export REGION=$REGION
	ECR=$ACCOUNT.dkr.ecr.$REGION.amazonaws.com
	echo export ECR=$ECR
	REMOTEIMG=$ECR/$LAMBDA_IMAGE
	echo export REMOTEIMG=$REMOTEIMG
	aws ecr get-login-password | docker login --username AWS --password-stdin $ECR 1>&2
}

s07_deploy_aws() {
        docker tag crac-lambda-restore $REMOTEIMG
        docker push $REMOTEIMG

        local digest=$(docker inspect -f '{{ index .RepoDigests 0 }}' $REMOTEIMG)
        aws lambda update-function-code --function-name $LAMBDA_NAME --image $digest
        aws lambda wait function-updated --function-name $LAMBDA_NAME
}

s08_invoke_aws() {
	rm -f response.json log.json

	aws lambda invoke  \
		--cli-binary-format raw-in-base64-out \
		--function-name $LAMBDA_NAME \
		--payload "$(< event.json) " \
		--log-type Tail \
		response.json \
		> log.json

	jq . < response.json 
	jq -r .LogResult < log.json | base64 -d
}

make_cold_aws() {
	local mem=$(aws lambda get-function-configuration --function-name $LAMBDA_NAME | jq -r '.MemorySize')
	local min=256
	local max=512
	aws lambda update-function-configuration --function-name $LAMBDA_NAME --memory-size $(($min + (($mem + 1) % ($max - $min))))
	aws lambda wait function-updated --function-name $LAMBDA_NAME
}

steps() {
	for i; do
		$i || break
	done
}

"$@"
