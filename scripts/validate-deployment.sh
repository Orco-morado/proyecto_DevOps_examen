#!/usr/bin/env bash
# Valida que el despliegue en EKS este correcto.
# Variables requeridas: K8S_NAMESPACE (opcional, default: devopsvg)

set -euo pipefail

NAMESPACE="${K8S_NAMESPACE:-devopsvg}"
ERRORS=0

echo "=========================================="
echo "  Validacion del Despliegue - devopsvg"
echo "=========================================="
echo ""

echo "==> 1. Verificando pods en el namespace ${NAMESPACE}"
if kubectl get pods -n "${NAMESPACE}" | grep -v "Running" | grep -q -v "NAME"; then
  echo "[ERROR] Hay pods que no estan en estado Running:"
  kubectl get pods -n "${NAMESPACE}" | grep -v "Running" | grep -v "NAME"
  ERRORS=$((ERRORS + 1))
else
  echo "[OK] Todos los pods estan Running"
  kubectl get pods -n "${NAMESPACE}" -o wide
fi
echo ""

echo "==> 2. Verificando servicios en el namespace ${NAMESPACE}"
kubectl get svc -n "${NAMESPACE}"
echo ""

echo "==> 3. Verificando HPA"
kubectl get hpa -n "${NAMESPACE}"
echo ""

echo "==> 4. Verificando LoadBalancer del frontend"
FRONTEND_URL=$(kubectl get svc frontend -n "${NAMESPACE}" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
if [ -n "$FRONTEND_URL" ]; then
  echo "[OK] Frontend disponible en: http://${FRONTEND_URL}"
  echo "     Health check:"
  curl -s -o /dev/null -w "     HTTP Status: %{http_code}\n" "http://${FRONTEND_URL}" --max-time 10 || echo "     [WARN] No responde aun (puede estar aprovisionando el ELB)"
else
  echo "[WARN] LoadBalancer del frontend aun no tiene endpoint (puede tardar ~2 min)"
fi
echo ""

echo "==> 5. Verificando health endpoints internos"
echo "     Nota: Los health checks internos requieren port-forward"
echo "     Para verificar manualmente:"
echo "       kubectl port-forward svc/backend-ventas -n ${NAMESPACE} 8084:8084"
echo "       curl http://localhost:8084/api/v1/ventas"
echo ""

if [ $ERRORS -eq 0 ]; then
  echo "=========================================="
  echo "  Validacion completada: TODO OK"
  echo "=========================================="
else
  echo "=========================================="
  echo "  Validacion completada: ${ERRORS} error(es)"
  echo "=========================================="
  exit 1
fi
