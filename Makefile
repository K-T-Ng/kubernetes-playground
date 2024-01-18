KIND_VERSION 						?= v0.20.0
KUBECTL_VERSION 					?= v1.29.0
NGINX_INGRESS_CONTROLLER_VERSION	?= 1.9.5
NGINX_VERSION 						?= 1.25.3
GRAFANA_VERSION						?= 10.2.3
PROMETHEUS_ALERT_MANAGER_VERSION 	?= 0.26.0
PROMETHEUS_VERSION					?= 2.48.1

CLUSTER_NAME ?= cluster

GRAFANA_DNS ?= grafana.local
PROMETHEUS_ALERT_MANAGER_DNS ?= alertmanager.prometheus.local
PROMETHEUS_DNS ?= prometheus.local

all: install-prerequisite get-helm-charts create-stack
clean: delete-cluster

create-stack: create-cluster install-nginx-ingress-controller install-grafana

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
	./kind create cluster --name $(CLUSTER_NAME) --config=cluster/kind.yaml

	# Create namespaces
	./kubectl apply -f cluster/namespace.yaml

	# Create resource quota for namespaces
	./kubectl apply -f cluster/resource-quota.yaml

	# Create namespaces
	./kubectl apply -f cluster/namespace.yaml

	# Create resource quota for namespaces
	./kubectl apply -f cluster/resource-quota.yaml

	# Create nginx ingress controller
	./kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
	kubectl wait --namespace ingress-nginx \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/component=controller \
		--timeout=180s

delete-cluster:
	./kind delete cluster --name $(CLUSTER_NAME)

# =====
# Infra
# =====
install-nginx-ingress-controller:
	helm upgrade --install nginx-ingress-controller bitnami/nginx-ingress-controller \
		-f cluster/nginx-ingress-controller/values.yaml \
		--set image.tag=$(NGINX_INGRESS_CONTROLLER_VERSION) \
		--set defaultBackend.image.tag=$(NGINX_VERSION) \
		--namespace infra

	./kubectl wait --namespace infra \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/component=controller \
		--timeout=90s

delete-nginx-ingress-controller:
	helm uninstall nginx-ingress-controller --namespace infra

# ========
# Monitors
# ========
install-grafana:
	helm upgrade --install grafana bitnami/grafana \
		-f monitor/grafana/values.yaml \
		--set image.tag=$(GRAFANA_VERSION) \
		--set ingress.hostname=$(GRAFANA_DNS) \
		--namespace monitor

delete-grafana:
	helm uninstall grafana --namespace monitor

install-prometheus:
	helm upgrade --install prometheus bitnami/prometheus \
		-f monitor/prometheus/values.yaml \
		--set alertmanager.image.tag=$(PROMETHEUS_ALERT_MANAGER_VERSION) \
		--set alertmanager.ingress.hostname=$(PROMETHEUS_ALERT_MANAGER_DNS) \
		--set server.image.tag=$(PROMETHEUS_VERSION) \
		--set server.ingress.hostname=$(PROMETHEUS_DNS) \
		--namespace monitor

get-prometheus-manifest:
	helm template prometheus bitnami/prometheus \
		-f monitor/prometheus/values.yaml \
		--set alertmanager.image.tag=$(PROMETHEUS_ALERT_MANAGER_VERSION) \
		--set alertmanager.ingress.hostname=$(PROMETHEUS_ALERT_MANAGER_DNS) \
		--set server.image.tag=$(PROMETHEUS_VERSION) \
		--set server.ingress.hostname=$(PROMETHEUS_DNS) \
		--namespace monitor >  manifest.yaml

delete-prometheus:
	helm uninstall prometheus --namespace monitor

# ==============
# Image & Charts
# ==============
get-helm-charts:
	helm repo add bitnami https://charts.bitnami.com/bitnami
	helm repo add projectcalico https://projectcalico.docs.tigera.io/charts
	helm repo update
