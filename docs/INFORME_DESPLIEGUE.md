# Informe de Despliegue — devopsvg

## Resumen ejecutivo

El 13 de julio de 2026 se completo el despliegue de la aplicacion **devopsvg** (frontend React + 2 backends Spring Boot + MySQL 8.0) sobre Amazon EKS, utilizando un pipeline CI/CD automatizado en GitHub Actions.

**Estado final: OPERATIVO** — los 7 pods corren, el frontend responde via LoadBalancer y las APIs estan disponibles internamente.

---

## Datos de la infraestructura

```
Cuenta AWS:     847750225273 (us-east-1)
Cluster:        devopsvg-eks (v1.32)
Namespace:      devopsvg
Node group:     devopsvg-nodes (t3.medium, min 2, max 4)
LoadBalancer:   ac8fb27e764e94113803456d4f4eccd0-1474001629.us-east-1.elb.amazonaws.com
```

---

## Recursos aprovisionados

Se crearon 20 recursos via Terraform:

| Categoria | Recursos |
|-----------|----------|
| **Red** | VPC, 2 subnets publicas, Internet Gateway, route table, 2 asociaciones |
| **IAM** | Datasource de LabRole |
| **EKS** | Cluster, node group, security group |
| **Addons** | vpc-cni, kube-proxy, coredns |
| **ECR** | 3 repositorios privados de imagenes |
| **CloudWatch** | Log group con retencion de 7 dias |

### Topologia de red

```
[Internet]
    |
    +-- IGW (igw-0155b548646a3c800)
    |
    +-- Subnet 1: 10.20.0.0/24 (us-east-1a)
    +-- Subnet 2: 10.20.1.0/24 (us-east-1b)
    |
    +-- EKS Cluster + Nodos t3.medium
```

---

## Estado del despliegue

A las 03:23 UTC del 13/07/2026, todos los servicios estaban operativos:

| Servicio | Replicas | Ready | Tipo | Puerto |
|----------|:--------:|:-----:|------|--------|
| MySQL | 1 | ✅ | ClusterIP | 3306 |
| Backend Ventas | 2 | ✅ | ClusterIP | 8084 |
| Backend Despachos | 2 | ✅ | ClusterIP | 8085 |
| Frontend | 2 | ✅ | LoadBalancer | 80 → 8081 |

### URLs de acceso

- **Frontend**: http://ac8fb27e764e94113803456d4f4eccd0-1474001629.us-east-1.elb.amazonaws.com
- **APIs**: Acceso interno via ClusterIP (no expuestas a internet)

### Autoscaling (HPA)

Ambos backends tienen HPA configurado al 50% de CPU:
- Minimo: 2 replicas
- Maximo: 4 replicas
- Uso actual: ~2% de CPU

---

## Repositorios ECR

Las 3 imagenes estan subidas a Amazon ECR con tag `latest` y por commit SHA:

| Repositorio | Imagen `latest` |
|-------------|:---------------:|
| `847750225273.dkr.ecr.us-east-1.amazonaws.com/devopsvg-frontend` | ✅ Subida |
| `847750225273.dkr.ecr.us-east-1.amazonaws.com/devopsvg-back-ventas` | ✅ Subida |
| `847750225273.dkr.ecr.us-east-1.amazonaws.com/devopsvg-back-despachos` | ✅ Subida |

---

## Pipeline CI/CD

### Flujo de despliegue

El pipeline se activa con un push a la rama `deploy`:

```
Compilacion (build)
    ↓
Build + push a ECR (docker-push) — 3 imagenes en paralelo
    ↓
Despliegue en EKS (deploy-eks) — mysql → backends → frontend
    ↓
Validacion (validate) — pods, servicios, HPA, LoadBalancer
```

### Tiempos de ejecucion (run #28)

| Paso | Duracion |
|------|----------|
| Compilacion | ~4s |
| Build + push Docker | ~7s |
| Despliegue EKS | ~10m 13s (timeout por reinicio de MySQL) |
| Validacion | ~14s |

> El tiempo largo en `deploy-eks` se debio a que MySQL tuvo que reiniciarse con las credenciales correctas y los backends entraron en CrashLoopBackOff hasta que MySQL estuvo listo. En condiciones normales, el despliegue completo toma 5-8 minutos.

---

## Limitaciones conocidas

### AWS Academy (Learner Lab)
- Las credenciales expiran cada ~4 horas. Hay que renovar los secrets en GitHub antes de correr el pipeline.
- `iam:AttachRolePolicy` esta bloqueado → usamos LabRole directamente (no OIDC).
- Al renovar la sesion de Academy, los nodos viejos quedan `NotReady` y hay que escalar el node group o forzar el reciclaje.
- `eks:DescribeCluster` puede fallar intermitentemente → Terraform plan/destroy se ve afectado.
- Los LoadBalancers son Classic ELB (no NL B/ALB), compatible con las restricciones del lab.

### Pipeline
- El push Docker de back-ventas se cuelga en Windows (manifest list multi-arch). No es problema porque GitHub Actions corre en Linux y usa `docker/build-push-action@v6`.
- Si Terraform falla con "Addon already exists", hay que importar el recurso al estado antes de aplicar.

---

## Bitacora del despliegue

| Hora (UTC) | Evento |
|------------|--------|
| 01:59 | Push de `devopsvg-frontend:latest` a ECR |
| 02:10 | Push de `devopsvg-back-despachos:latest` a ECR |
| 02:45 | Pipeline #27: falla `ECR_REGISTRY` vacio (faltaba `AWS_ACCOUNT_ID`) |
| 03:02 | Pipeline #28: corrige `ECR_REGISTRY`, pero falla rollout de backends |
| 03:09 | Pods de backend-ventas en CrashLoopBackOff (credenciales MySQL incorrectas) |
| 03:13 | Se elimina el pod de MySQL para reiniciarlo con credenciales correctas |
| 03:14 | Se eliminan ReplicaSets viejos con `InvalidImageName` |
| 03:19 | MySQL Ready con bases de datos `db_despacho` y `db_venta` |
| 03:20 | Backends reiniciados y conectados a MySQL |
| 03:23 | Todos los pods operativos. Frontend responde HTTP 200 |

---

## Comandos utiles

```bash
# Conectarse al cluster
aws eks update-kubeconfig --name devopsvg-eks --region us-east-1

# Ver estado
kubectl get nodes
kubectl get pods,svc,hpa -n devopsvg

# Obtener URL del frontend
kubectl get svc frontend -n devopsvg \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Health check
curl -I http://$(kubectl get svc frontend -n devopsvg \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Logs de aplicacion
aws logs describe-log-groups --log-group-name-prefix "/eks/devopsvg" \
  --region us-east-1

# Terraform
cd infra/terraform
terraform state list
terraform output
```
