#!/usr/bin/env bash
# Sincroniza el state de Terraform con los recursos reales de AWS.
# Uso: ./scripts/sync-terraform-state.sh
set -euo pipefail

cd "$(dirname "$0")/../infra/terraform"

terraform init

echo "==> Importando EKS cluster (si no existe en state)"
terraform import aws_eks_cluster.main devopsvg-eks 2>/dev/null && echo "  OK" || echo "  Ya existe o no aplica"

echo "==> Importando node group"
terraform import aws_eks_node_group.main devopsvg-eks:devopsvg-nodes 2>/dev/null && echo "  OK" || echo "  Ya existe o no aplica"

echo "==> Importando addons"
for addon in vpc-cni kube-proxy coredns; do
  tf_name="${addon//-/_}"
  terraform import "aws_eks_addon.${tf_name}" "devopsvg-eks:${addon}" 2>/dev/null && echo "  ${addon} OK" || echo "  ${addon} ya existe o no aplica"
done

echo "==> Verificando estado"
terraform plan
