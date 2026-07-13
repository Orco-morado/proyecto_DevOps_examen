# devopsvg — Proyecto DevOps

Aplicacion full-stack containerizada sobre **Amazon EKS** con pipeline CI/CD automatizado en GitHub Actions.

---

## Arquitectura

```
[Internet]
    |
    +-- LoadBalancer (Classic ELB)
        |
        +-- Nginx (API Gateway, non-root :8081)
            |
            +-- /api/v1/ventas/    → backend-ventas:8084
            +-- /api/v1/despachos/ → backend-despachos:8085
            +-- /*                 → React (static)

Servicios internos (ClusterIP):
  - backend-ventas (Spring Boot, :8084)
  - backend-despachos (Spring Boot, :8085)
  - mysql (:3306)
```

| Servicio | Puerto | Lenguaje | Replicas | HPA |
|----------|--------|----------|:--------:|:---:|
| frontend (nginx + React) | 80 (LB) → 8081 | Node 20 / Vite | 2 | — |
| backend-ventas | 8084 | Java 17 / Spring Boot | 2 | CPU 50% |
| backend-despachos | 8085 | Java 17 / Spring Boot | 2 | CPU 50% |
| mysql | 3306 | MySQL 8.0 | 1 | — |

---

## Estructura del proyecto

```
proyecto_DevOps_examen/
├── infra/
│   ├── terraform/          # IaC (8 archivos)
│   │   ├── main.tf         # Provider, VPC, subnets, IGW, route tables
│   │   ├── variables.tf    # region, project_name, cluster_version
│   │   ├── outputs.tf      # cluster_name, vpc_id, 3 ECR URLs
│   │   ├── eks.tf          # EKS v1.32 + node group + addons
│   │   ├── ecr.tf          # 3 repos ECR
│   │   ├── iam.tf          # LabRole datasource
│   │   └── cloudwatch.tf   # Log Group
│   └── k8s/                # Manifiestos por servicio
│       ├── namespace/      # Namespace devopsvg
│       ├── configmaps/     # DB endpoints + datasource URLs
│       ├── secrets/        # Template credenciales MySQL
│       ├── mysql/          # Deployment + Service + init script
│       ├── back-ventas/    # Deployment + Service + HPA
│       ├── back-despachos/ # Deployment + Service + HPA
│       └── frontend/       # Deployment + Service LoadBalancer
├── scripts/
│   ├── deploy-k8s.sh       # Despliegue ordenado con envsubst
│   └── validate-deployment.sh  # Validacion post-despliegue
├── .github/workflows/
│   ├── ci.yml              # Compilacion (3 jobs paralelos)
│   ├── deploy.yml          # CD a EKS (4 jobs: build → docker-push → deploy → validate)
│   └── destroy.yml         # Kill Switch manual
├── front_despacho/         # React + Vite + Tailwind + Nginx
├── back-Ventas_SpringBoot/ # Backend ventas :8084
├── back-Despachos_SpringBoot/ # Backend despachos :8085
└── docs/
    ├── INFORME_DESPLIEGUE.md
    └── PIPELINE-ANALISIS.md
```

---

## Infraestructura (Terraform)

La infraestructura se aprovisiona con Terraform (estado local, gestionado manualmente):

| Recurso | Detalle |
|---------|---------|
| **VPC** | `10.20.0.0/16` con 2 subnets publicas |
| **EKS** | v1.32, 2 nodos t3.medium (min 2, max 4), addons: vpc-cni, kube-proxy, coredns |
| **ECR** | 3 repos privados: `devopsvg-frontend`, `devopsvg-back-ventas`, `devopsvg-back-despachos` |
| **CloudWatch** | Log Group `/eks/devopsvg/applications`, retencion 7 dias |
| **Total recursos** | ~20 gestionados por Terraform |

```bash
cd infra/terraform
terraform init
terraform apply -auto-approve
```

> ⚠️ Terraform `apply` puede fallar si hay addons ya creados. Solucion: `terraform import` seguido de `terraform apply`.

---

## Pipeline CI/CD

### CI (`ci.yml`)
Se activa en push/PR a `main`. 3 jobs paralelos:
1. Frontend (npm ci + build + test)
2. Backend ventas (Maven package)
3. Backend despachos (Maven package)

### CD (`deploy.yml`)
Se activa en push a rama `deploy` o `workflow_dispatch`. 4 jobs secuenciales:

```
build (compila apps)
  └─ docker-push (matrix: 3 imagenes → ECR con docker/build-push-action@v6 + cache GHA)
       └─ deploy-eks (namespace + metrics-server + secrets + rollout ordenado)
            └─ validate (pods, servicios, HPA, LoadBalancer)
```

| Job | Descripción |
|-----|-------------|
| `build` | Compila frontend (npm) + backends (Maven) |
| `docker-push` | Matrix en paralelo: buildx + push a ECR con cache layer GHA |
| `deploy-eks` | kubectl apply + rollout (mysql → backends → frontend) + resumen en $GITHUB_STEP_SUMMARY |
| `validate` | Verifica pods Running, servicios, HPA, health endpoints |

### Kill Switch (`destroy.yml`)
Workflow manual que ejecuta `terraform destroy` con timeout de 45 min. Incluye limpieza previa de k8s (namespace, metrics-server).

---

## Configuracion de Secretos (GitHub Actions)

| Secret | Uso |
|--------|-----|
| `AWS_ACCESS_KEY_ID` | Credenciales AWS Academy |
| `AWS_SECRET_ACCESS_KEY` | Credenciales AWS Academy |
| `AWS_SESSION_TOKEN` | Token temporal (expira cada 4h) |
| `AWS_ACCOUNT_ID` | ID de cuenta AWS (12 digitos) |
| `MYSQL_ROOT_PASSWORD` | Password root de MySQL |
| `MYSQL_USER` | Usuario de aplicacion MySQL |
| `MYSQL_PASSWORD` | Password de aplicacion MySQL |

---

## Notas tecnicas sobre AWS Academy

- **LabRole** se usa directamente (OIDC bloqueado por politica `voc-cancel-cred`)
- **Metrics Server** se instala en el pipeline para habilitar HPA
- **LoadBalancer classic** (no NL B/ALB) compatible con restricciones del Learner Lab
- **bootstrap_self_managed_addons = false** → los addons (vpc-cni, kube-proxy, coredns) se instalan via `aws_eks_addon` en Terraform
- **Node group** tarda ~8-12 min en crearse; si el apply timeout, importar al state
- Las credenciales AWS expiran cada 4 horas → renovar antes de ejecutar el CD

---

## Despliegue Local (Docker Compose)

```bash
cp .env.example .env
# Editar .env con credenciales locales
docker compose up -d --build
```

| Servicio | URL local |
|----------|-----------|
| Frontend | http://localhost:8081 |
| Backend despachos | http://localhost:8082 |
| Backend ventas | http://localhost:8083 |

> En local las APIs se consumen directamente (VITE_API_* apunta a localhost).
> En EKS el ruteo lo hace Nginx via proxy_pass interno (sin trailing slash para preservar el path).
