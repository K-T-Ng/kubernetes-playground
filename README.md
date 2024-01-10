# kubernetes-playground
A playground for getting familiar with Kubernetes

# Quick Start
## Start a KinD cluster from draft
1. Install make
   ```sh
   sudo apt-get install make
   ```
2. Install pre-requisite (`kind`, `kubectl` and `helm`)\
   ```sh
   make install-prerequisite
   ```
3. Spin up cluster
   ```
   make create-cluster
   ```
## How to clean up
Delete the KinD cluster by
```sh
make delete-cluster
```


# Reference
- [Kind Documentation](https://kind.sigs.k8s.io/)