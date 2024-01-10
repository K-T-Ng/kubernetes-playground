KIND_VERSION 		?= v0.20.0
KUBECTL_VERSION 	?= v1.29.0
GRAFANA_VERSION		?= 10.2.3

CLUSTER_NAME ?= cluster

GRAFANA_DNS ?= grafana.local

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
	./kubectl apply -f cluster/namespace.yaml

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

# ========
# Monitors
# ========
install-grafana:
	helm upgrade --install grafana bitnami/grafana \
		-f monitor/grafana/values.yaml \
		--set ingress.hostname=$(GRAFANA_DNS) \
		--namespace monitor

delete-grafana:
	helm uninstall grafana --namespace monitor

# ==============
# Image & Charts
# ==============
get-images:
	docker pull bitnami/grafana:$(GRAFANA_VERSION)

load-images:
	./kind load docker-image bitnami/grafana:$(GRAFANA_VERSION) --name $(CLUSTER_NAME) 

get-helm-charts:
	helm repo add bitnami https://charts.bitnami.com/bitnami
	helm repo update
