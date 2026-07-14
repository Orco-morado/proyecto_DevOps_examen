#!/usr/bin/env bash
# Valida que los servicios desplegados en EKS respondan correctamente.

set -euo pipefail

NAMESPACE="${K8S_NAMESPACE:-devopsvg}"
LB_TIMEOUT=300
LB_INTERVAL=15
ELAPSED=0

echo "==> 1. Validando pods en namespace ${NAMESPACE}..."
kubectl get pods -n "${NAMESPACE}" -o wide

FAILED_PODS=$(kubectl get pods -n "${NAMESPACE}" --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "${FAILED_PODS}" -gt 0 ]; then
  echo "ERROR: Hay pods que no están en estado Running."
  kubectl get pods -n "${NAMESPACE}"
  exit 1
fi

echo ""
echo "==> 2. Validando health checks internos (port-forward)..."
check_internal() {
  local deployment="$1"
  local local_port="$2"
  local container_port="$3"
  local path="$4"

  kubectl port-forward -n "${NAMESPACE}" "deployment/${deployment}" "${local_port}:${container_port}" &
  local PF_PID=$!
  sleep 5

  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${local_port}${path}" || echo "000")
  kill "${PF_PID}" 2>/dev/null || true
  wait "${PF_PID}" 2>/dev/null || true

  if [ "${http_code}" -ge 200 ] && [ "${http_code}" -lt 400 ]; then
    echo "  OK  ${deployment}${path} -> HTTP ${http_code} (${local_port}:${container_port})"
  else
    echo "  FAIL ${deployment}${path} -> HTTP ${http_code}"
    return 1
  fi
}

check_internal backend-ventas 8084 8084 /api/v1/ventas
check_internal backend-despachos 8085 8085 /api/v1/despachos
check_internal frontend 8081 8081 /

echo ""
echo "==> 3. Esperando Load Balancer del frontend (max ${LB_TIMEOUT}s)..."
LB_HOST=""
while [ "${ELAPSED}" -lt "${LB_TIMEOUT}" ]; do
  LB_HOST=$(kubectl get svc frontend -n "${NAMESPACE}" \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  if [ -n "${LB_HOST}" ]; then
    break
  fi
  sleep "${LB_INTERVAL}"
  ELAPSED=$((ELAPSED + LB_INTERVAL))
  echo "  Esperando LB... (${ELAPSED}s)"
done

if [ -z "${LB_HOST}" ]; then
  echo "ADVERTENCIA: Load Balancer aun sin hostname. Validacion interna OK."
  exit 0
fi

echo ""
echo "==> 4. Frontend publico: http://${LB_HOST}"
EXTERNAL_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 30 "http://${LB_HOST}/" || echo "000")
if [ "${EXTERNAL_CODE}" -ge 200 ] && [ "${EXTERNAL_CODE}" -lt 400 ]; then
  echo "  OK  Frontend publico -> HTTP ${EXTERNAL_CODE}"
else
  echo "  FAIL Frontend publico -> HTTP ${EXTERNAL_CODE}"
  exit 1
fi

echo ""
echo "==> Validacion completada: commit -> build -> push -> deploy -> operativo."
