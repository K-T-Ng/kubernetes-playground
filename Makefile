CLUSTER_NAME 	?= cluster
KIND_VERSION 	?= v0.20.0
KUBECTL_VERSION ?= v1.29.0

all: install-prerequisite get-helm-charts create-stack
clean: delete-cluster

create-monitor: install-grafana install-prometheus install-node-exporter intsall-kube-state-metrics
create-stack: create-cluster install-nginx-ingress-controller create-monitor

# ============
# Prerequisite	
# ============
install-prerequisite:
	# Kind
	[ $$(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/$(KIND_VERSION)/kind-linux-amd64
	chmod u+x ./kind

	# Kubectl
	curl -LO "https://dl.k8s.io/release/$(KUBECTL_VERSION)/bin/linux/amd64/kubectl"
	chmod u+x ./kubectl

	# Helm
	curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
	chmod 700 get_helm.sh
	./get_helm.sh
	rm get_helm.sh

# =======
# Cluster	
# =======
create-cluster:
	# Create KinD Cluster
	./kind create cluster --name $(CLUSTER_NAME) --config=config/kind/kind.yaml

	# Create namespaces
	./kubectl apply -f config/kind/namespace.yaml

	# Create resource quota for namespaces
	./kubectl apply -f config/kind/resource-quota.yaml

delete-cluster:
	./kind delete cluster --name $(CLUSTER_NAME)

# =======
# Common
# =======
install-common:
	# Nginx ingress contoller
	@$(call deploy_by_helm,nginx-ingress-controller,bitnami/nginx-ingress-controller,10.5.2,common,config/bitnami/nginx-ingress-controller/values.yaml)

check-common:
	# Nginx ingress contoller
	@$(call check_pod_ready,app.kubernetes.io/component=controller,common,90s)

delete-common:
	# Nginx ingress contoller
	@$(call delete_by_helm,nginx-ingress-controller,common)

# =======
# Monitor
# =======
install-monitor-backend:
	# Grafana
	@$(call deploy_by_helm,grafana,bitnami/grafana,9.10.2,monitor,config/bitnami/grafana/values.yaml)

	# Prometheus
	@$(call deploy_by_helm,prometheus,bitnami/prometheus,0.11.4,monitor,config/bitnami/prometheus/values.yaml)

	# ElasticSearch
	@$(call deploy_by_helm,elasticsearch,bitnami/elasticsearch,19.19.3,monitor,config/bitnami/elasticsearch/values.yaml)

	# Jaeger
	@$(call deploy_by_helm,jaeger,jaegertracing/jaeger,1.0.2,monitor,config/jaegertracing/jaeger/values.yaml)

	# OpenTelemetry collector
	@$(call deploy_by_helm,opentelemetry-collector,open-telemetry/opentelemetry-collector,0.82.0,monitor,config/open-telemetry/opentelemetry-collector/values.yaml)

check-monitor-backend:
	# ElasticSearch
	@$(call check_pod_ready,app.kubernetes.io/name=elasticsearch,monitor,300s)

	# Grafana
	@$(call check_pod_ready,app.kubernetes.io/name=grafana,monitor,300s)

	# Prometheus
	@$(call check_pod_ready,app.kubernetes.io/name=prometheus,monitor,300s)

	# Jaeger
	@$(call check_pod_ready,app.kubernetes.io/name=jaeger,monitor,300s)

	# OpenTelemetry collector
	@$(call check_pod_ready,app.kubernetes.io/name=opentelemetry-collector,monitor,300s)

delete-monitor-backend:
	# Grafana
	@$(call delete_by_helm,grafana,monitor)

	# Prometheus
	@$(call delete_by_helm,prometheus,monitor)

	# ElasticSearch
	@$(call delete_by_helm,elasticsearch,monitor)

	# Jaeger
	@$(call delete_by_helm,jaeger,monitor)

	# OpenTelemetry Collector
	@$(call delete_by_helm,opentelemetry-collector,monitor)

# ==============
# Image & Charts
# ==============
get-helm-charts:
	helm repo add bitnami https://charts.bitnami.com/bitnami
	helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
	helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
	helm repo update

# ========
# Misc
# ========
define deploy_by_helm
	$(eval $@_NAME = $(1))
	$(eval $@_CHART = $(2))
	$(eval $@_VERSION = $(3))
	$(eval $@_NAMESPACE = $(4))
	$(eval $@_VALUE = $(5))

	helm upgrade --install ${$@_NAME} ${$@_CHART} \
		-f ${$@_VALUE} \
		--version ${$@_VERSION} \
		--namespace ${$@_NAMESPACE}
endef

define delete_by_helm
	$(eval $@_NAME = $(1))
	$(eval $@_NAMESPACE = $(2))

	helm uninstall ${$@_NAME} --namespace ${$@_NAMESPACE}
endef

define check_pod_ready
	$(eval $@_SELECTOR = $(1))
	$(eval $@_NAMESPACE = $(2))
	$(eval $@_TIMEOUT = $(3))

	./kubectl wait --namespace ${$@_NAMESPACE} \
		--for=condition=ready pod \
		--selector=${$@_SELECTOR} \
		--timeout=${$@_TIMEOUT}
endef