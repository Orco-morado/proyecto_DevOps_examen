#!/usr/bin/env bash
# Despliega la aplicacion devopsvg en EKS.
# Variables requeridas: ECR_REGISTRY, IMAGE_TAG
# Variables opcionales: ECR_REPO_FRONTEND, ECR_REPO_VENTAS, ECR_REPO_DESPACHOS

set -euo pipefail

NAMESPACE="${K8S_NAMESPACE:-devopsvg}"
ECR_REGISTRY="${ECR_REGISTRY:?ECR_REGISTRY no definido}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

ECR_REPO_FRONTEND="${ECR_REPO_FRONTEND:-devopsvg-frontend}"
ECR_REPO_VENTAS="${ECR_REPO_VENTAS:-devopsvg-back-ventas}"
ECR_REPO_DESPACHOS="${ECR_REPO_DESPACHOS:-devopsvg-back-despachos}"

export ECR_REGISTRY IMAGE_TAG ECR_REPO_FRONTEND ECR_REPO_VENTAS ECR_REPO_DESPACHOS

echo "==> Namespace: ${NAMESPACE}"
echo "==> ECR Registry: ${ECR_REGISTRY}"
echo "==> Image Tag: ${IMAGE_TAG}"

render_deployment() {
  envsubst '${ECR_REGISTRY} ${IMAGE_TAG} ${ECR_REPO_FRONTEND} ${ECR_REPO_VENTAS} ${ECR_REPO_DESPACHOS}' < "$1"
}

apply_ordered() {
  kubectl apply -f infra/k8s/configmaps/
  kubectl apply -f infra/k8s/mysql/

  render_deployment infra/k8s/back-ventas/deployment.yaml | kubectl apply -f -
  kubectl apply -f infra/k8s/back-ventas/service.yaml

  render_deployment infra/k8s/back-despachos/deployment.yaml | kubectl apply -f -
  kubectl apply -f infra/k8s/back-despachos/service.yaml

  render_deployment infra/k8s/frontend/deployment.yaml | kubectl apply -f -
  kubectl apply -f infra/k8s/frontend/service.yaml
}

wait_rollout() {
  echo "==> Esperando rollout: $1"
  kubectl rollout status "deployment/$1" -n "${NAMESPACE}" --timeout="${2:-300s}"
}

apply_ordered
wait_rollout mysql 300s
wait_rollout backend-ventas 600s
wait_rollout backend-despachos 600s
wait_rollout frontend 300s

echo "==> Despliegue completado."
kubectl get pods,svc -n "${NAMESPACE}"
