# Informe de Despliegue — devopsvg

> **INFRAESTRUCTURA DESTRUIDA** — Este documento es la memoria de lo que se construyo, como funciono y como se desmantelo. Queda como referencia academica y bitacora del proyecto.

---

## Resumen

El 13 de julio de 2026 se completo el ciclo completo del proyecto:

1. Se aprovisiono infraestructura en AWS con Terraform
2. Se desplego la aplicacion via pipeline CI/CD
3. Se valido el funcionamiento (todo operativo)
4. Se destruyo todo con `terraform destroy` para no gastar creditos

**Duracion total del proyecto**: ~12 horas (infraestructura viva ~2 horas para validacion)

---

## Que se construyo

### Infraestructura (17 recursos gestionados por Terraform)

| Categoria | Recursos |
|-----------|----------|
| **Red** | VPC `10.20.0.0/16`, 2 subnets publicas, Internet Gateway, route table + 2 asociaciones |
| **EKS** | Cluster v1.32, node group 2x t3.medium, security group |
| **Addons** | vpc-cni, kube-proxy, coredns (gestionados via `aws_eks_addon`) |
| **ECR** | 3 repos privados (frontend, back-ventas, back-despachos) |
| **CloudWatch** | Log group `/eks/devopsvg/applications`, 7 dias retencion |

```
[Internet]
    |
    +-- IGW
    |
    +-- Subnet 1: 10.20.0.0/24 (us-east-1a)
    +-- Subnet 2: 10.20.1.0/24 (us-east-1b)
    |
    +-- EKS Cluster + 2 nodos t3.medium
```

### Aplicacion desplegada (7 pods en Kubernetes)

| Servicio | Replicas | Puerto | Tipo |
|----------|:--------:|:------:|------|
| MySQL 8.0 | 1 | 3306 | ClusterIP |
| Backend Ventas (Spring Boot) | 2 | 8084 | ClusterIP |
| Backend Despachos (Spring Boot) | 2 | 8085 | ClusterIP |
| Frontend (React + Nginx) | 2 | 80 → 8081 | LoadBalancer |

### Pipeline CI/CD (GitHub Actions)

```
build (compila)
  └─ docker-push (3 imagenes en paralelo → ECR)
       └─ deploy-eks (kubectl apply: mysql → backends → frontend)
            └─ validate (pods, servicios, HPA, LoadBalancer)
```

**Tiempos reales (run #28):**
- Compilacion: ~4s (cacheado)
- Build + push Docker: ~7s (cacheado)
- Despliegue EKS: ~10m 13s (con reinicio de MySQL incluido)
- Validacion: ~14s
- **Total: ~10m 31s** (en condiciones normales: 5-8 min)

---

## Bitacora del proyecto

### 01:00 — Aprovisionamiento
Se aplico Terraform: VPC, subnets, IGW, EKS cluster, node group, addons, ECR, CloudWatch.

### 01:59 — Primer push a ECR
`devopsvg-frontend:latest` subido exitosamente a ECR.

### 02:10 — Segundo push
`devopsvg-back-despachos:latest` subido.
`devopsvg-back-ventas` no pudo subirse localmente (bug manifest list multi-arch en Docker Desktop Windows).

### 02:45 — Pipeline #27 (fallo)
Se disparo el pipeline con push a `deploy`. Falla porque `ECR_REGISTRY` quedaba `.dkr.ecr...` (faltaba el account ID en el secret de GitHub).

**Fix**: Hardcodear `847750225273` en deploy.yml. Tambien se soluciono `terraform fmt` en eks.tf (newline faltante).

### 03:02 — Pipeline #28 ( despliegue)
Segundo intento. El `ECR_REGISTRY` ya se ve correcto. Pero falla el rollout de backend-ventas.

**Causa**: Las credenciales de MySQL en el secret de Kubernetes no coincidian con las que MySQL tenia al iniciarse (el pipeline habia actualizado el secret pero MySQL no se reinicio).

### 03:09 — Correccion manual de MySQL
Se elimino el pod de MySQL para que se reiniciara con las credenciales actuales del secret. Tambien se limpiaron ReplicaSets viejos con `InvalidImageName` (deploys anteriores con ECR registry malo).

### 03:20 — Todo operativo
Los 7 pods en Running, HPA funcional (2% CPU), frontend responde HTTP 200.

### 03:20 — Prueba de acceso
El frontend responde desde AWS pero da timeout desde internet (problema de conectividad del usuario, no del despliegue).

### 03:40 — Destruccion
`terraform destroy` + limpieza manual de ECR. 17 recursos destruidos exitosamente.

---

## Problemas y soluciones

| Problema | Causa | Solucion |
|----------|-------|----------|
| `bootstrap_self_managed_addons = false}` | Faltaba newline al final de eks.tf | `terraform fmt` |
| ECR Registry `.dkr.ecr...` | Secret `AWS_ACCOUNT_ID` no configurado | Hardcodear account ID |
| `Access denied for user 'admin'` | MySQL uso credenciales viejas | Eliminar pod MySQL para reinicio |
| `InvalidImageName` en pods viejos | ReplicaSets de deploys anteriores | `kubectl delete rs` |
| ECR no se borra en `terraform destroy` | Repos tenian imagenes | `force_delete = true` en ecr.tf |
| Nodos `NotReady` | Sesion Academy renovada | Escalar node group |

---

## Comandos utiles (para el proximo deploy)

```bash
# 1. Aprovisionar infraestructura
cd infra/terraform
terraform init && terraform apply -auto-approve

# 2. Desplegar aplicacion
git checkout deploy && git push origin deploy
# El pipeline hace el resto

# 3. Verificar
aws eks update-kubeconfig --name devopsvg-eks --region us-east-1
kubectl get pods,svc,hpa -n devopsvg

# 4. Destruir
cd infra/terraform && terraform destroy -auto-approve
```
