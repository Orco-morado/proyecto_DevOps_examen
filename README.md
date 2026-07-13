# devopsVG — Proyecto DevOps

Aplicacion full-stack containerizada sobre **Amazon EKS** con pipeline CI/CD automatizado, desplegada mediante **Terraform** y orquestada con **Kubernetes**.

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
| frontend (nginx + React) | 80 (LB) → 8081 (non-root) | Node 20 / Vite | 2 | — |
| backend-ventas | 8084 | Java 17 / Spring Boot | 2 | CPU 50% |
| backend-despachos | 8085 | Java 17 / Spring Boot | 2 | CPU 50% |
| mysql | 3306 | MySQL 8.0 | 1 | — |

---

## Estructura del proyecto

```
proyecto_DevOps_nota2/
├── infra/
│   ├── terraform/          # IaC (7 archivos separados)
│   │   ├── main.tf         # Provider, VPC, subnets, IGW, route tables
│   │   ├── variables.tf    # aws_region, project_name, cluster_version
│   │   ├── outputs.tf      # cluster_name, vpc_id, 3 ECR URLs
│   │   ├── eks.tf          # EKS v1.32 + node group t3.medium
│   │   ├── ecr.tf          # 3 repos ECR
│   │   ├── iam.tf          # LabRole datasource
│   │   └── cloudwatch.tf   # Log Group
│   └── k8s/                # Manifiestos por servicio
│       ├── namespace/      # Namespace devopsVG
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
│   ├── deploy.yml          # CD a EKS (17 pasos)
│   └── destroy.yml         # Kill Switch manual
├── front_despacho/         # React + Vite + Tailwind + Nginx
├── back-Ventas_SpringBoot/ # Backend ventas :8084
├── back-Despachos_SpringBoot/ # Backend despachos :8085
└── docs/
    ├── INFORME_DESPLIEGUE.md
    ├── PIPELINE-ANALISIS.md
    └── CONTEXTO_CD_GORDON.md
```

---

## Infraestructura (Terraform)

La infraestructura se aprovisiona automaticamente via Terraform (`.tfstate` cacheado en GitHub Actions):

| Recurso | Detalle |
|---------|---------|
| **VPC** | `10.20.0.0/16` con 2 subnets publicas |
| **EKS** | v1.32, 2 nodos t3.medium (min 2, max 4) |
| **ECR** | 3 repos privados: `devopsVG-frontend`, `devopsVG-back-ventas`, `devopsVG-back-despachos` |
| **CloudWatch** | Log Group `/eks/devopsVG/applications`, retencion 7 dias |
| **Total recursos** | ~17 gestionados por Terraform |

```bash
cd infra/terraform
terraform init
terraform validate
terraform apply -auto-approve
```

---

## Pipeline CI/CD

### CI (`ci.yml`)
Se activa en push/PR a `main`. Compila en paralelo:
1. Frontend (npm ci + build)
2. Backend ventas (Maven package)
3. Backend despachos (Maven package)

### CD (`deploy.yml`)
Se activa en push a rama `deploy` o manualmente. Flujo completo:

```
Checkout → AWS creds → Terraform init → TF apply → Login ECR
→ Build+push 3 imagenes → kubectl connect
→ Namespace + Metrics Server + Secrets
→ deploy-k8s.sh (envsubst + rollout)
→ validate-deployment.sh
```

### Kill Switch (`destroy.yml`)
Workflow manual que ejecuta `terraform destroy` con timeout de 45 min. Limpia el cluster EKS, repos ECR, VPC y Log Group.

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
- MySQL usa `emptyDir` (no EBS CSI, requiere OIDC)
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
> En EKS el ruteo lo hace Nginx via proxy_pass interno.
