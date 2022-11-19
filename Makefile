YQ:=$(shell which yq)
JQ:=$(shell which jq)
KUBECTL:=$(shell which kubectl)
DOCKER:=$(shell which docker)
MINIKUBE:=$(shell which minikube)

PROMETHEUS_NAMESPACE:="default"
KEDA_NAMESPACE:="keda"
APP_NAMESPACE:="default"
BASE_IMAGE:="node:18"
APP_NAME:=$(shell ${YQ} e '.name' src/package.json)
VERSION:=$(shell ${YQ} e '.version' src/package.json)
IMAGE_NAME_TAG:=$(APP_NAME):$(VERSION)
ARTIFACT_REGISTRY:=$(shell echo "") # empty
FULLY_QUALIFIED_IMAGE_URL:=$(ARTIFACT_REGISTRY)$(IMAGE_NAME_TAG)

params-guard-%:
	@if [ "${${*}}" = "" ]; then \
			echo "[$*] not set"; \
			exit 1; \
	fi

check_compulsory_params: params-guard-LAB

name:
	@echo $(APP_NAME)

version:
	@echo $(VERSION)

print_mk_var:
	@echo "YQ: [$(YQ)]"
	@echo "KUBECTL: [$(KUBECTL)]"
	@echo "DOCKER: [$(DOCKER)]"
	@echo "MINIKUBE: [$(MINIKUBE)]"
	@echo "ARTIFACT_REGISTRY: [$(ARTIFACT_REGISTRY)]"
	@echo "BASE_IMAGE: [$(BASE_IMAGE)]"
	@echo "APP_NAMESPACE: [$(APP_NAMESPACE)]"
	@echo "APP_NAME: [$(APP_NAME)]"
	@echo "VERSION: [$(VERSION)]"
	@echo "IMAGE_NAME_TAG: [$(IMAGE_NAME_TAG)]"
	@echo "FULLY_QUALIFIED_IMAGE_URL: [$(FULLY_QUALIFIED_IMAGE_URL)]"

wait_for_prom_operator_deploy:
	$(KUBECTL) wait \
	deployment -n $(PROMETHEUS_NAMESPACE) \
	prometheus-operator \
	--for condition=Available=True \
	--timeout=300s

wait_for_prom_statefulset: 
	@sleep 5
	$(KUBECTL) rollout \
	-n $(PROMETHEUS_NAMESPACE) \
	status --watch --timeout=300s \
	statefulset/prometheus-prometheus

wait_for_prom_pods: 
	$(KUBECTL) wait \
	-n $(PROMETHEUS_NAMESPACE) \
	--for condition=ready \
	--timeout=300s \
	pod -l prometheus=prometheus 

wait_for_app_pods: 
	$(KUBECTL) wait \
	-n $(APP_NAMESPACE) \
	--for condition=ready \
	--timeout=300s \
	pod -l app=trying-keda

wait_for_keda_operator_deploy:
	$(KUBECTL) wait \
	deployment -n $(KEDA_NAMESPACE) \
	keda-operator \
	--for condition=Available=True \
	--timeout=300s

# app install
app-build:
	$(DOCKER) build \
	--build-arg BASE_IMAGE=$(BASE_IMAGE) \
	--build-arg APP_NAME=$(APP_NAME) \
	-t $(IMAGE_NAME_TAG) \
	--pull \
	--no-cache \
	-f ./src/Dockerfile \
	./src

tag: 
	$(DOCKER) tag \
	$(IMAGE_NAME_TAG) \
	$(FULLY_QUALIFIED_IMAGE_URL)

load-image: print_mk_var
	$(MINIKUBE) image \
	load $(FULLY_QUALIFIED_IMAGE_URL)

apply:
	$(KUBECTL) apply \
	-n $(APP_NAMESPACE) \
	-f ./app/deployment.yaml
	$(KUBECTL) apply \
	-n $(APP_NAMESPACE) \
	-f ./app/service.yaml

prometheus-app-svc-monitor-install: 
	$(KUBECTL) apply \
	-n $(APP_NAMESPACE) \
	-f ./app/prometheus_svc_monitor.yaml

app-install: app-build load-image apply 

app-install-all: app-build load-image apply wait_for_app_pods prometheus-app-svc-monitor-install
# app install

# app uninstall
app-uninstall: 
	$(KUBECTL) delete --ignore-not-found \
	-n $(APP_NAMESPACE) \
	-f ./app/deployment.yaml
	$(KUBECTL) delete --ignore-not-found \
	-n $(APP_NAMESPACE) \
	-f ./app/service.yaml

prometheus-app-svc-monitor-uninstall: 
	$(KUBECTL) delete --ignore-not-found \
	-n $(PROMETHEUS_NAMESPACE) \
	-f ./app/prometheus_svc_monitor.yaml

app-uninstall-all: prometheus-app-svc-monitor-uninstall app-uninstall
# app uninstall

# prometheus install
prometheus-operator-install: 
	$(KUBECTL) create -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/master/bundle.yaml

prometheus-rbac-install: 
	$(KUBECTL) apply -n $(PROMETHEUS_NAMESPACE) -f prometheus/prom_rbac.yaml

prometheus-install: 
	$(KUBECTL) apply -n $(PROMETHEUS_NAMESPACE) -f prometheus/prometheus.yaml

prometheus-svc-install: 
	$(KUBECTL) apply -n $(PROMETHEUS_NAMESPACE) -f prometheus/prom_svc.yaml
	$(KUBECTL) patch svc prometheus \
	-n $(PROMETHEUS_NAMESPACE) \
	--type=json -p='[{"op": "add", "path": "/spec/selector/prometheus", "value": "prometheus"}]'
	$(KUBECTL) patch svc prometheus \
	-n $(PROMETHEUS_NAMESPACE) \
	--type=json -p='[{"op": "remove", "path": "/spec/selector/app"}]'

prometheus-service-monitor-install: 
	$(KUBECTL) apply -n $(PROMETHEUS_NAMESPACE) -f prometheus/prometheus_svc_monitor.yaml

prometheus-install-all: 
	$(MAKE) prometheus-operator-install \
	prometheus-rbac-install prometheus-install \
	wait_for_prom_operator_deploy \
	wait_for_prom_statefulset \
	wait_for_prom_pods \
	prometheus-svc-install \
	prometheus-service-monitor-install
# prometheus install

# prometheus uninstall
prometheus-operator-uninstall: 
	$(KUBECTL) delete \
	--ignore-not-found \
	-n $(PROMETHEUS_NAMESPACE) \
	-f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/master/bundle.yaml

prometheus-rbac-uninstall: 
	$(KUBECTL) delete \
	--ignore-not-found \
	-n $(PROMETHEUS_NAMESPACE) \
	-f prometheus/prom_rbac.yaml

prometheus-uninstall: 
	$(KUBECTL) delete \
	--ignore-not-found \
	-n $(PROMETHEUS_NAMESPACE) \
	-f prometheus/prometheus.yaml

prometheus-svc-uninstall: 
	$(KUBECTL) delete \
	--ignore-not-found \
	-n $(PROMETHEUS_NAMESPACE) \
	-f prometheus/prom_svc.yaml

prometheus-service-monitor-uninstall: 
	$(KUBECTL) delete \
	--ignore-not-found \
	-n $(PROMETHEUS_NAMESPACE) \
	-f prometheus/prometheus_svc_monitor.yaml

prometheus-uninstall-all: 
	$(MAKE) prometheus-service-monitor-uninstall \
	prometheus-svc-uninstall \
	prometheus-uninstall \
	prometheus-rbac-uninstall \
	prometheus-operator-uninstall
# prometheus uninstall

# keda install
keda-install:
	$(KUBECTL) apply \
	-f https://github.com/kedacore/keda/releases/download/v2.8.0/keda-2.8.0.yaml

keda-app-scaled-object-install:
	$(KUBECTL) apply \
	-n $(APP_NAMESPACE) \
	-f ./app/scaled-object.yaml

keda-update-app-scaled-object:
	./utils/updateScaledObject.sh

keda-install-all: 
	$(MAKE) \
	keda-install \
	wait_for_keda_operator_deploy \
	keda-update-app-scaled-object \
	keda-app-scaled-object-install
# keda install

# keda uninstall
keda-uninstall:
	$(KUBECTL) delete \
	--ignore-not-found \
	-f https://github.com/kedacore/keda/releases/download/v2.8.0/keda-2.8.0.yaml

keda-app-scaled-object-uninstall:
	$(KUBECTL) delete \
	-n $(APP_NAMESPACE) \
	--ignore-not-found \
	-f ./app/scaled-object.yaml

keda-uninstall-all: keda-app-scaled-object-uninstall keda-uninstall
# keda uninstall

minikube-start:
	$(MINIKUBE) start

minikube-stop:
	$(MINIKUBE) stop

minikube-delete:
	$(MINIKUBE) delete

clean-up: minikube-stop minikube-delete

install-all: 
	$(MAKE) \
	minikube-start \
	prometheus-install-all \
	app-install-all \
	keda-install-all

uninstall-all: 
	$(MAKE) \
	prometheus-uninstall-all \
	keda-uninstall-all \
	app-uninstall-all \
	clean-up 
