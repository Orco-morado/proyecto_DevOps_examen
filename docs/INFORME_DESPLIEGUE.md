# INFORME COMPLETO DE DESPLIEGUE — devopsVG

```
Fecha:       2026-07-12
Cuenta AWS:  {{AWS_ACCOUNT_ID}} (us-east-1)
Lab Role:    LabRole (voc-cancel-cred activo)
Estado:      PRODUCCION — todos los recursos operativos
```

---

## 1. RECURSOS APROVISIONADOS

| Categoria | Recursos | Cantidad |
|-----------|----------|:--------:|
| **Red** | VPC, 2 subnets publicas, IGW, route table, 2 asociaciones | 6 |
| **IAM** | LabRole datasource | 1 |
| **EKS** | 1 cluster, 1 node group (2x t3.medium), 1 SG | 3 |
| **ECR** | 3 repos privados | 3 |
| **CloudWatch** | 1 log group (/eks/devopsVG/applications, 7 dias) | 1 |
| **Datasources** | AZs, LabRole, caller identity | 3 |
| **Total** | | **17** |

---

## 2. TOPOLOGIA DE RED

```
[Internet]
    |
    +-- IGW
    |
    +-- Subnet publica 1 (10.20.0.0/24, us-east-1a)
    +-- Subnet publica 2 (10.20.1.0/24, us-east-1b)
    |
    +-- EKS Cluster + Node Group
```

---

## 3. ORQUESTACION — EKS

| Componente | Valor |
|------------|-------|
| Cluster | `devopsVG-eks` |
| Version | 1.32 |
| Node Group | `devopsVG-nodes` — 2 nodos t3.medium (min 2, max 4) |

Comando de conexion:
```bash
aws eks update-kubeconfig --name devopsVG-eks --region us-east-1
kubectl get nodes
```

---

## 4. REPOSITORIOS ECR

| Repositorio | URL |
|-------------|-----|
| devopsVG-frontend | `{{AWS_ACCOUNT_ID}}.dkr.ecr.us-east-1.amazonaws.com/devopsVG-frontend` |
| devopsVG-back-ventas | `{{AWS_ACCOUNT_ID}}.dkr.ecr.us-east-1.amazonaws.com/devopsVG-back-ventas` |
| devopsVG-back-despachos | `{{AWS_ACCOUNT_ID}}.dkr.ecr.us-east-1.amazonaws.com/devopsVG-back-despachos` |

---

## 5. CLOUDWATCH

| Recurso | Detalle |
|---------|---------|
| Log Group | `/eks/devopsVG/applications` |
| Retencion | 7 dias |

---

## 6. NAMESPACE KUBERNETES

| Namespace | Servicios |
|-----------|-----------|
| `devopsVG` | MySQL, backend-ventas, backend-despachos, frontend |

---

## 7. LIMITACIONES CONOCIDAS (voc-cancel-cred)

| Restriccion | Impacto | Workaround |
|-------------|---------|------------|
| `iam:AttachRolePolicy` bloqueado | No se pueden adjuntar politicas a LabRole | LabRole usado directamente |
| `eks:DescribeCluster` a veces bloqueado | Terraform plan/destroy puede fallar | Renovar credenciales o consola AWS |
| Secrets AWS expiran cada 4h | Pipeline CI/CD no ejecutable | Workaround documentado en README |

---

## 8. COMANDOS DE VERIFICACION (post-despliegue)

```bash
# EKS
aws eks describe-cluster --name devopsVG-eks --region us-east-1
aws eks update-kubeconfig --name devopsVG-eks --region us-east-1
kubectl get nodes
kubectl get pods,svc -n devopsVG

# Frontend
kubectl get svc frontend -n devopsVG -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# CloudWatch
aws logs describe-log-groups --log-group-name-prefix "/eks/devopsVG" --region us-east-1

# Terraform
terraform state list
terraform output
```
