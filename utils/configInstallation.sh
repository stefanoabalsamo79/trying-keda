#!/bin/sh
set -e

pullTagPush() {
  IMAGE_SRC=$1
  QUALIFIED_IMAGE_URL=$2
  CLUSTER_NAME=$3

  $DOCKER pull "$IMAGE_SRC"
  $DOCKER tag "$IMAGE_SRC" "$QUALIFIED_IMAGE_URL"
  $KIND load docker-image \
  "$QUALIFIED_IMAGE_URL" \
  --name "$CLUSTER_NAME"
}

ENV=$1

YQ=`which yq`
KUBECTL=`which kubectl`
DOCKER=`which docker`
KIND=`which kind`
INFO_FILE="infra/info.yaml"
INGRESS_CONTROLLER="./infra/ingress_controller.yaml"
KEDA="./keda/keda-2.8.0.yaml"
PROMETHEUS_OPERATOR_FILE="./prometheus/prometheus_operator.yaml"
PROMETHEUS_FILE="./prometheus/prometheus.yaml"

CLUSTER_NAME=`$YQ e ".clusterName" $INFO_FILE`


INGRESS_NGINX_CONTROLLER_IMAGE_SRC=`$YQ e ".ingress-nginx-controller.$ENV.imageSrc" $INFO_FILE`
INGRESS_NGINX_CONTROLLER_IMAGE_DEST=`$YQ e ".ingress-nginx-controller.$ENV.imageDest" $INFO_FILE`
INGRESS_NGINX_CONTROLLER_IMAGE_TAG_DEST=`$YQ e ".ingress-nginx-controller.$ENV.imageTagDest" $INFO_FILE`
INGRESS_NGINX_CONTROLLER_QUALIFIED_IMAGE_URL=${INGRESS_NGINX_CONTROLLER_IMAGE_DEST}:${INGRESS_NGINX_CONTROLLER_IMAGE_TAG_DEST}
pullTagPush "$INGRESS_NGINX_CONTROLLER_IMAGE_SRC" "$INGRESS_NGINX_CONTROLLER_QUALIFIED_IMAGE_URL" "$CLUSTER_NAME"
$YQ e -i "select(.kind == \"Deployment\" and .metadata.name == \"ingress-nginx-controller\").spec.template.spec.containers[0].image |= \"$INGRESS_NGINX_CONTROLLER_QUALIFIED_IMAGE_URL\"" $INGRESS_CONTROLLER

KUBE_WEBHOOK_CERTGEN_IMAGE_SRC=`$YQ e ".kube-webhook-certgen.$ENV.imageSrc" $INFO_FILE`
KUBE_WEBHOOK_CERTGEN_IMAGE_DEST=`$YQ e ".kube-webhook-certgen.$ENV.imageDest" $INFO_FILE`
KUBE_WEBHOOK_CERTGEN_IMAGE_TAG_DEST=`$YQ e ".kube-webhook-certgen.$ENV.imageTagDest" $INFO_FILE`
KUBE_WEBHOOK_CERTGEN_QUALIFIED_IMAGE_URL=${KUBE_WEBHOOK_CERTGEN_IMAGE_DEST}:${KUBE_WEBHOOK_CERTGEN_IMAGE_TAG_DEST}
pullTagPush "$KUBE_WEBHOOK_CERTGEN_IMAGE_SRC" "$KUBE_WEBHOOK_CERTGEN_QUALIFIED_IMAGE_URL" "$CLUSTER_NAME"
$YQ e -i "select(.kind == \"Job\" and .metadata.name == \"ingress-nginx-admission-create\").spec.template.spec.containers[0].image |= \"$KUBE_WEBHOOK_CERTGEN_QUALIFIED_IMAGE_URL\"" $INGRESS_CONTROLLER
$YQ e -i "select(.kind == \"Job\" and .metadata.name == \"ingress-nginx-admission-patch\").spec.template.spec.containers[0].image |= \"$KUBE_WEBHOOK_CERTGEN_QUALIFIED_IMAGE_URL\"" $INGRESS_CONTROLLER

KEDA_METRICS_APISERVER_IMAGE_SRC=`$YQ e ".keda-metrics-apiserver.$ENV.imageSrc" $INFO_FILE`
KEDA_METRICS_APISERVER_IMAGE_DEST=`$YQ e ".keda-metrics-apiserver.$ENV.imageDest" $INFO_FILE`
KEDA_METRICS_APISERVER_IMAGE_TAG_DEST=`$YQ e ".keda-metrics-apiserver.$ENV.imageTagDest" $INFO_FILE`
KEDA_METRICS_APISERVER_QUALIFIED_IMAGE_URL=${KEDA_METRICS_APISERVER_IMAGE_DEST}:${KEDA_METRICS_APISERVER_IMAGE_TAG_DEST}
pullTagPush "$KEDA_METRICS_APISERVER_IMAGE_SRC" "$KEDA_METRICS_APISERVER_QUALIFIED_IMAGE_URL" "$CLUSTER_NAME"
$YQ e -i "select(.kind == \"Deployment\" and .metadata.name == \"keda-metrics-apiserver\").spec.template.spec.containers[0].image |= \"$KEDA_METRICS_APISERVER_QUALIFIED_IMAGE_URL\"" $KEDA

KEDA_IMAGE_SRC=`$YQ e ".keda.$ENV.imageSrc" $INFO_FILE`
KEDA_IMAGE_DEST=`$YQ e ".keda.$ENV.imageDest" $INFO_FILE`
KEDA_IMAGE_TAG_DEST=`$YQ e ".keda.$ENV.imageTagDest" $INFO_FILE`
KEDA_QUALIFIED_IMAGE_URL=${KEDA_IMAGE_DEST}:${KEDA_IMAGE_TAG_DEST}
pullTagPush "$KEDA_IMAGE_SRC" "$KEDA_QUALIFIED_IMAGE_URL" "$CLUSTER_NAME"
$YQ e -i "select(.kind == \"Deployment\" and .metadata.name == \"keda-operator\").spec.template.spec.containers[0].image |= \"$KEDA_QUALIFIED_IMAGE_URL\"" $KEDA

PROMETHEUS_CONFIG_RELOADER_IMAGE_SRC=`$YQ e ".prometheus-config-reloader.$ENV.imageSrc" $INFO_FILE`
PROMETHEUS_CONFIG_RELOADER_IMAGE_DEST=`$YQ e ".prometheus-config-reloader.$ENV.imageDest" $INFO_FILE`
PROMETHEUS_CONFIG_RELOADER_IMAGE_TAG_DEST=`$YQ e ".prometheus-config-reloader.$ENV.imageTagDest" $INFO_FILE`
PROMETHEUS_CONFIG_RELOADER_QUALIFIED_IMAGE_URL=${PROMETHEUS_CONFIG_RELOADER_IMAGE_DEST}:${PROMETHEUS_CONFIG_RELOADER_IMAGE_TAG_DEST}
pullTagPush "$PROMETHEUS_CONFIG_RELOADER_IMAGE_SRC" "$PROMETHEUS_CONFIG_RELOADER_QUALIFIED_IMAGE_URL" "$CLUSTER_NAME"
$YQ e -i "select(.kind == \"Deployment\" and .metadata.name == \"prometheus-operator\").spec.template.spec.containers[0].args[1] |= \"--prometheus-config-reloader=$PROMETHEUS_CONFIG_RELOADER_QUALIFIED_IMAGE_URL\"" $PROMETHEUS_OPERATOR_FILE

PROMETHEUS_OPERATOR_IMAGE_SRC=`$YQ e ".prometheus-operator.$ENV.imageSrc" $INFO_FILE`
PROMETHEUS_OPERATOR_IMAGE_DEST=`$YQ e ".prometheus-operator.$ENV.imageDest" $INFO_FILE`
PROMETHEUS_OPERATOR_IMAGE_TAG_DEST=`$YQ e ".prometheus-operator.$ENV.imageTagDest" $INFO_FILE`
PROMETHEUS_OPERATOR_QUALIFIED_IMAGE_URL=${PROMETHEUS_OPERATOR_IMAGE_DEST}:${PROMETHEUS_OPERATOR_IMAGE_TAG_DEST}
pullTagPush "$PROMETHEUS_OPERATOR_IMAGE_SRC" "$PROMETHEUS_OPERATOR_QUALIFIED_IMAGE_URL" "$CLUSTER_NAME"
$YQ e -i "select(.kind == \"Deployment\" and .metadata.name == \"prometheus-operator\").spec.template.spec.containers[0].image |= \"$PROMETHEUS_OPERATOR_QUALIFIED_IMAGE_URL\"" $PROMETHEUS_OPERATOR_FILE

PROMETHEUS_IMAGE_SRC=`$YQ e ".prometheus.$ENV.imageSrc" $INFO_FILE`
PROMETHEUS_IMAGE_DEST=`$YQ e ".prometheus.$ENV.imageDest" $INFO_FILE`
PROMETHEUS_IMAGE_TAG_DEST=`$YQ e ".prometheus.$ENV.imageTagDest" $INFO_FILE`
PROMETHEUS_QUALIFIED_IMAGE_URL=${PROMETHEUS_IMAGE_DEST}:${PROMETHEUS_IMAGE_TAG_DEST}
pullTagPush "$PROMETHEUS_IMAGE_SRC" "$PROMETHEUS_QUALIFIED_IMAGE_URL" "$CLUSTER_NAME"
$YQ e -i "select(.kind == \"Prometheus\" and .metadata.name == \"prometheus\").spec.image |= \"$PROMETHEUS_QUALIFIED_IMAGE_URL\"" $PROMETHEUS_FILE


