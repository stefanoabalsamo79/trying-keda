YQ:=$(shell which yq)
JQ:=$(shell which jq)
KUBECTL:=$(shell which kubectl)
DOCKER:=$(shell which docker)
KIND:=$(shell which kind)

INFO_FILE:="./infra/info.yaml"
CLUSTER_NAME:=$(shell ${YQ} e '.clusterName' ${INFO_FILE})
DEFAULT_CLUSTER_NAME:=$(shell ${YQ} e '.defaultClusterName' ${INFO_FILE})
PROMETHEUS_NAMESPACE:=$(shell ${YQ} e '.prometheusNamespace' ${INFO_FILE})
KEDA_NAMESPACE:=$(shell ${YQ} e '.kedaNamespace' ${INFO_FILE})
APP_NAMESPACE:=$(shell ${YQ} e '.appNamespace' ${INFO_FILE})
BASE_IMAGE:=$(shell ${YQ} e '.appBaseImage' ${INFO_FILE})
APP_NAME:=$(shell ${YQ} e '.name' src/package.json)
VERSION:=$(shell ${YQ} e '.version' src/package.json)
IMAGE_NAME_TAG:=$(APP_NAME):$(VERSION)
ARTIFACT_REGISTRY:=$(shell echo "") # empty
FULLY_QUALIFIED_IMAGE_URL:=$(ARTIFACT_REGISTRY)$(IMAGE_NAME_TAG)

HAS_YQ:=$(shell which yq > /dev/null 2> /dev/null && echo true || echo false)
HAS_JQ:=$(shell which jq > /dev/null 2> /dev/null && echo true || echo false)
HAS_KUBECTL:=$(shell which kubectl > /dev/null 2> /dev/null && echo true || echo false)
HAS_DOCKER:=$(shell which docker > /dev/null 2> /dev/null && echo true || echo false)
HAS_KIND:=$(shell which kind > /dev/null 2> /dev/null && echo true || echo false)

check_prerequisites:
ifeq ($(HAS_YQ),false) 
	$(info yq not installed!)
	@exit 1
endif
ifeq ($(HAS_JQ),false) 
	$(info jq not installed!)
	@exit 1
endif
ifeq ($(HAS_KUBECTL),false) 
	$(info kubectl not installed!)
	@exit 1
endif
ifeq ($(HAS_DOCKER),false) 
	$(info docker not installed!)
	@exit 1
endif
ifeq ($(HAS_KIND),false) 
	$(info kind not installed!)
	@exit 1
endif

# params-guard-%:
# 	@if [ "${${*}}" = "" ]; then \
# 			echo "[$*] not set"; \
# 			exit 1; \
# 	fi

name: check_prerequisites
	@echo $(APP_NAME)

version: check_prerequisites
	@echo $(VERSION)

print_mk_var: check_prerequisites
	@echo "YQ: [$(YQ)]"
	@echo "JQ: [$(JQ)]"
	@echo "KUBECTL: [$(KUBECTL)]"
	@echo "DOCKER: [$(DOCKER)]"
	@echo "KIND: [$(KIND)]"
	@echo "INFO_FILE: [$(INFO_FILE)]"
	@echo "CLUSTER_NAME: [$(CLUSTER_NAME)]"
	@echo "DEFAULT_CLUSTER_NAME: [$(DEFAULT_CLUSTER_NAME)]"
	@echo "PROMETHEUS_NAMESPACE: [$(PROMETHEUS_NAMESPACE)]"
	@echo "KEDA_NAMESPACE: [$(KEDA_NAMESPACE)]"
	@echo "APP_NAMESPACE: [$(APP_NAMESPACE)]"
	@echo "BASE_IMAGE: [$(BASE_IMAGE)]"
	@echo "APP_NAME: [$(APP_NAME)]"
	@echo "IMAGE_NAME_TAG: [$(IMAGE_NAME_TAG)]"
	@echo "ARTIFACT_REGISTRY: [$(ARTIFACT_REGISTRY)]"
	@echo "FULLY_QUALIFIED_IMAGE_URL: [$(FULLY_QUALIFIED_IMAGE_URL)]"

config_installation:
	./utils/configInstallation.sh "local"

ingress_controller_install: check_prerequisites
	$(KUBECTL) apply -f infra/ingress_controller.yaml
	@sleep 30
	$(MAKE) wait_for_ingress_controller
  
wait_for_ingress_controller: check_prerequisites
	$(KUBECTL) wait \
	-n ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

wait_for_prom_operator_deploy: check_prerequisites
	$(KUBECTL) wait \
	deployment -n $(PROMETHEUS_NAMESPACE) \
	prometheus-operator \
	--for condition=Available=True \
	--timeout=300s

wait_for_prom_statefulset: check_prerequisites
	@sleep 5
	$(KUBECTL) rollout \
	-n $(PROMETHEUS_NAMESPACE) \
	status --watch --timeout=300s \
	statefulset/prometheus-prometheus

wait_for_prom_pods: check_prerequisites
	$(KUBECTL) wait \
	-n $(PROMETHEUS_NAMESPACE) \
	--for condition=ready \
	--timeout=300s \
	pod -l prometheus=prometheus 

wait_for_app_pods: check_prerequisites
	$(KUBECTL) wait \
	-n $(APP_NAMESPACE) \
	--for condition=ready \
	--timeout=300s \
	pod -l app=trying-keda

wait_for_keda_operator_deploy: check_prerequisites
	$(KUBECTL) wait \
	deployment -n $(KEDA_NAMESPACE) \
	keda-operator \
	--for condition=Available=True \
	--timeout=300s

# app install
app_build: check_prerequisites
	$(DOCKER) build \
	--build-arg BASE_IMAGE=$(BASE_IMAGE) \
	--build-arg APP_NAME=$(APP_NAME) \
	-t $(IMAGE_NAME_TAG) \
	--pull \
	--no-cache \
	-f ./src/Dockerfile \
	./src

tag: check_prerequisites
	$(DOCKER) tag \
	$(IMAGE_NAME_TAG) \
	$(FULLY_QUALIFIED_IMAGE_URL)

load_image: check_prerequisites
	$(KIND) load \
	docker-image $(FULLY_QUALIFIED_IMAGE_URL) \
	--name $(CLUSTER_NAME)

apply: check_prerequisites
	$(KUBECTL) apply \
	-n $(APP_NAMESPACE) \
	-f ./app/deployment.yaml
	$(KUBECTL) apply \
	-n $(APP_NAMESPACE) \
	-f ./app/service.yaml
	$(KUBECTL) apply \
	-n $(APP_NAMESPACE) \
	-f ./app/ingress.yaml

prometheus_app_svc_monitor_install: check_prerequisites
	$(KUBECTL) apply \
	-n $(APP_NAMESPACE) \
	-f ./app/prometheus_svc_monitor.yaml

app_install: check_prerequisites 
	$(MAKE) \
	app-build \
	load-image \
	apply 

app_install_all: check_prerequisites
	$(MAKE) \
	app_build \
	load_image \
	apply \
	wait_for_app_pods \
	prometheus_app_svc_monitor_install
# app install

# app uninstall
app_uninstall: check_prerequisites
	$(KUBECTL) delete --ignore-not-found \
	-n $(APP_NAMESPACE) \
	-f ./app/deployment.yaml
	$(KUBECTL) delete --ignore-not-found \
	-n $(APP_NAMESPACE) \
	-f ./app/service.yaml

prometheus_app_svc_monitor_uninstall: check_prerequisites
	$(KUBECTL) delete --ignore-not-found \
	-n $(PROMETHEUS_NAMESPACE) \
	-f ./app/prometheus_svc_monitor.yaml

app_uninstall_all: check_prerequisites
	$(MAKE) \
	prometheus_app_svc_monitor_uninstall \
	app_uninstall
# app uninstall

# prometheus install
prometheus_operator_install: check_prerequisites
	$(KUBECTL) create -f ./prometheus/prometheus_operator.yaml

prometheus_rbac_install: check_prerequisites
	$(KUBECTL) apply \
	-n $(PROMETHEUS_NAMESPACE) \
	-f prometheus/prom_rbac.yaml

prometheus_install: check_prerequisites
	$(KUBECTL) apply \
	-n $(PROMETHEUS_NAMESPACE) \
	-f prometheus/prometheus.yaml

prometheus_svc_install: check_prerequisites
	$(KUBECTL) apply \
	-n $(PROMETHEUS_NAMESPACE) \
	-f prometheus/prom_svc.yaml
	$(KUBECTL) patch svc prometheus \
	-n $(PROMETHEUS_NAMESPACE) \
	--type=json -p='[{"op": "add", "path": "/spec/selector/prometheus", "value": "prometheus"}]'
	$(KUBECTL) patch svc prometheus \
	-n $(PROMETHEUS_NAMESPACE) \
	--type=json -p='[{"op": "remove", "path": "/spec/selector/app"}]'

prometheus_service_monitor_install: check_prerequisites
	$(KUBECTL) apply \
	-n $(PROMETHEUS_NAMESPACE) \
	-f prometheus/prometheus_svc_monitor.yaml

prometheus_install_all: check_prerequisites
	$(MAKE) \
	prometheus_operator_install \
	prometheus_rbac_install prometheus_install \
	wait_for_prom_operator_deploy \
	wait_for_prom_statefulset \
	wait_for_prom_pods \
	prometheus_svc_install \
	prometheus_service_monitor_install
# prometheus install

# prometheus uninstall
prometheus_operator_uninstall: check_prerequisites
	$(KUBECTL) delete \
	--ignore-not-found \
	-n $(PROMETHEUS_NAMESPACE) \
	-f ./prometheus/prometheus_operator.yaml

prometheus_rbac_uninstall: check_prerequisites
	$(KUBECTL) delete \
	--ignore-not-found \
	-n $(PROMETHEUS_NAMESPACE) \
	-f prometheus/prom_rbac.yaml

prometheus_uninstall: check_prerequisites
	$(KUBECTL) delete \
	--ignore-not-found \
	-n $(PROMETHEUS_NAMESPACE) \
	-f prometheus/prometheus.yaml

prometheus_svc_uninstall: check_prerequisites
	$(KUBECTL) delete \
	--ignore-not-found \
	-n $(PROMETHEUS_NAMESPACE) \
	-f prometheus/prom_svc.yaml

prometheus_service_monitor_uninstall: check_prerequisites
	$(KUBECTL) delete \
	--ignore-not-found \
	-n $(PROMETHEUS_NAMESPACE) \
	-f prometheus/prometheus_svc_monitor.yaml

prometheus_uninstall_all: check_prerequisites
	$(MAKE) \
	prometheus_service_monitor_uninstall \
	prometheus_svc_uninstall \
	prometheus_uninstall \
	prometheus_rbac_uninstall \
	prometheus_operator_uninstall
# prometheus uninstall

# keda install
keda_install: check_prerequisites
	$(KUBECTL) apply \
	-f ./keda/keda-2.8.0.yaml

keda_app_scaled_object_install: check_prerequisites
	$(KUBECTL) apply \
	-n $(APP_NAMESPACE) \
	-f ./app/scaled-object.yaml

keda_update_app_scaled_object: check_prerequisites
	./utils/updateScaledObject.sh

keda_install_all: check_prerequisites
	$(MAKE) \
	keda_install \
	wait_for_keda_operator_deploy \
	keda_update_app_scaled_object \
	keda_app_scaled_object_install
# keda install

# keda uninstall
keda-uninstall: check_prerequisites
	$(KUBECTL) delete \
	--ignore-not-found \
	-f keda/keda-2.8.0.yaml

keda_app_scaled_object_uninstall: check_prerequisites
	$(KUBECTL) delete \
	-n $(APP_NAMESPACE) \
	--ignore-not-found \
	-f ./app/scaled-object.yaml

keda_uninstall_all: check_prerequisites
	$(MAKE) keda_app_scaled_object_uninstall keda_uninstall
# keda uninstall

cluster_start: check_prerequisites
	$(KIND) create cluster

cluster_delete: check_prerequisites
	$(KIND) delete cluster --name $(CLUSTER_NAME)
	$(KIND) delete cluster --name $(DEFAULT_CLUSTER_NAME)

create_cluster: check_prerequisites
	$(KIND) create \
	cluster --config=infra/cluster.yaml \
	--name $(CLUSTER_NAME)

set_context_cluster: check_prerequisites
	$(KUBECTL) config set-context $(CLUSTER_NAME)

cluster_info: check_prerequisites
	$(KUBECTL) cluster-info --context kind-$(CLUSTER_NAME)

install_all: 
	$(MAKE) \
	print_mk_var \
	cluster_start \
	create_cluster \
	set_context_cluster \
	cluster_info \
	config_installation \
	ingress_controller_install \
	wait_for_ingress_controller \
	prometheus_install_all \
	app_install_all \
	keda_install_all

uninstall-all: 
	$(MAKE) \
	prometheus_uninstall_all \
	keda_uninstall_all \
	app_uninstall_all \

clean_up: cluster_delete
