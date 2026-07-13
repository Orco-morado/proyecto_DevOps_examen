# INFORME COMPLETO DE DESPLIEGUE — devopsvg

```
Fecha:       2026-07-13
Cuenta AWS:  847750225273 (us-east-1)
Lab Role:    LabRole (voc-cancel-cred activo)
Cluster:     devopsvg-eks — ACTIVE
Namespace:   devopsvg
Estado:      INFRAESTRUCTURA OPERATIVA — apps pendientes de despliegue via pipeline
```

---

## 1. RECURSOS APROVISIONADOS

| Categoria | Recursos | Cantidad |
|-----------|----------|:--------:|
| **Red** | VPC (`vpc-00e818c721f012095`), 2 subnets publicas, IGW, route table, 2 asociaciones | 6 |
| **IAM** | LabRole datasource | 1 |
| **EKS** | 1 cluster (`devopsvg-eks`), 1 node group (2x t3.medium), 1 SG | 3 |
| **EKS Addons** | vpc-cni, kube-proxy, coredns | 3 |
| **ECR** | 3 repos privados | 3 |
| **CloudWatch** | 1 log group (`/eks/devopsvg/applications`, 7 dias) | 1 |
| **Datasources** | AZs, LabRole, caller identity | 3 |
| **Total** | | **20** |

---

## 2. TOPOLOGIA DE RED

```
[Internet]
    |
    +-- IGW (igw-0155b548646a3c800)
    |
    +-- Subnet publica 1 (10.20.0.0/24, us-east-1a) — subnet-0762f84988e45bb81
    +-- Subnet publica 2 (10.20.1.0/24, us-east-1b) — subnet-02d144c4cbef9474b
    |
    +-- EKS Cluster + Node Group
```

---

## 3. ORQUESTACION — EKS

| Componente | Valor |
|------------|-------|
| Cluster | `devopsvg-eks` (v1.32) |
| Endpoint | `https://6686DA2FA001399004D99B578EF3BE8F.sk1.us-east-1.eks.amazonaws.com` |
| Node Group | `devopsvg-nodes` — 2 o mas nodos t3.medium (min 2, max 4) |
| Addons | vpc-cni, kube-proxy, coredns (gestionados via Terraform `aws_eks_addon`) |
| Nodos activos | `ip-10-20-0-195` (13.220.1.235) — Ready |
| Nodos drenando | `ip-10-20-0-206`, `ip-10-20-1-90` — NotReady (reciclaje por renovacion de sesion Academy) |

Comando de conexion:
```bash
aws eks update-kubeconfig --name devopsvg-eks --region us-east-1
kubectl get nodes
```

---

## 4. REPOSITORIOS ECR

| Repositorio | URL | Imagen `latest` | Estado |
|-------------|-----|:----------------:|--------|
| devopsvg-frontend | `847750225273.dkr.ecr.us-east-1.amazonaws.com/devopsvg-frontend` | ✅ `13/07 01:59` | Subida |
| devopsvg-back-ventas | `847750225273.dkr.ecr.us-east-1.amazonaws.com/devopsvg-back-ventas` | ❌ Pendiente | Pendiente de push via pipeline (bug Docker Desktop local no afecta GHA) |
| devopsvg-back-despachos | `847750225273.dkr.ecr.us-east-1.amazonaws.com/devopsvg-back-despachos` | ✅ `13/07 02:10` | Subida |

---

## 5. CLOUDWATCH

| Recurso | Detalle |
|---------|---------|
| Log Group | `/eks/devopsvg/applications` |
| Retencion | 7 dias |

---

## 6. NAMESPACE KUBERNETES — ESTADO ACTUAL

| Servicio | Tipo | Deseado | Real | Notas |
|----------|------|:-------:|:----:|-------|
| MySQL 8.0 | Deployment + ClusterIP | 1 replica | ✅ 1/1 Running | Pod migrado a nodo nuevo `ip-10-20-0-195` |
| backend-ventas (:8084) | Deployment + ClusterIP + HPA | 2 replicas | ❌ No desplegado | Se despliega via pipeline en rama `deploy` |
| backend-despachos (:8085) | Deployment + ClusterIP + HPA | 2 replicas | ❌ No desplegado | Se despliega via pipeline en rama `deploy` |
| frontend (nginx :8081) | Deployment + LoadBalancer :80 | 2 replicas | ❌ Solo service (sin pods) | Service LoadBalancer existe pero sin backend; el pipeline hara el deploy |

---

## 7. LIMITACIONES CONOCIDAS (voc-cancel-cred)

| Restriccion | Impacto | Workaround |
|-------------|---------|------------|
| `iam:AttachRolePolicy` bloqueado | No se pueden adjuntar politicas a LabRole | LabRole usado directamente |
| `eks:DescribeCluster` a veces bloqueado | Terraform plan/destroy puede fallar | Renovar credenciales o consola AWS |
| Secrets AWS expiran cada 4h | Pipeline CI/CD no ejecutable | Renovar credenciales antes del CD |
| `bootstrap_self_managed_addons = false` | Addons no se instalan automaticamente | Gestionados via `aws_eks_addon` en Terraform |

---

## 8. PIPELINE — FLUJO DE DESPLIEGUE

El pipeline se ejecuta en GitHub Actions al hacer push a la rama `deploy`:

```
branch deploy → CI/CD (4 jobs):
  1. build        → compila frontend (npm) + backends (Maven)
  2. docker-push  → matrix 3 imagenes → push a ECR (paralelo, linux/amd64)
  3. deploy-eks   → kubectl apply (mysql → backends → frontend) + rollout status
  4. validate     → pods, servicios, HPA, LoadBalancer
```

> Nota: El bug de push Docker que se experimento localmente (manifest list multi-arch colgado en Windows)
> NO ocurre en GitHub Actions porque usa `docker/build-push-action@v6` con `platforms: linux/amd64`
> sobre runners Linux nativos.

---

## 9. COMANDOS DE VERIFICACION (post-despliegue)

```bash
# EKS
aws eks update-kubeconfig --name devopsvg-eks --region us-east-1
kubectl get nodes
kubectl get pods,svc -n devopsvg

# Frontend
kubectl get svc frontend -n devopsvg -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Health check directo
curl -I http://$(kubectl get svc frontend -n devopsvg -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# CloudWatch
aws logs describe-log-groups --log-group-name-prefix "/eks/devopsvg" --region us-east-1

# Terraform
cd infra/terraform
terraform state list
terraform output
```
