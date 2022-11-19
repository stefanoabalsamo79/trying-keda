#!/bin/sh

set -e

YQ=`which yq`
JQ=`which jq`
KUBECTL=`which kubectl`
APP_NAMESPACE="default"

CIP=`$KUBECTL get svc -n $APP_NAMESPACE prometheus  -o json | $JQ -r '.spec.clusterIP'`
CPORT=`$KUBECTL get svc -n $APP_NAMESPACE prometheus  -o json | $JQ -r '.spec.ports[0].port'`
URL="http://$CIP:$CPORT"

echo $URL

$YQ e ".spec.triggers[0].metadata.serverAddress=\"$URL\"" \
./app/scaled-object.yaml > ./app/scaled-object.yaml.tmp && \
mv  ./app/scaled-object.yaml.tmp ./app/scaled-object.yaml 
