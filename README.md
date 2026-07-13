# devopsvg — Proyecto DevOps

Una aplicacion web full-stack (React + Spring Boot + MySQL) desplegada en Amazon EKS con pipeline CI/CD automatizado. Construido como proyecto transversal para el ramo ISY1101.

```
Frontend → Nginx → Backend Ventas (:8084) → MySQL
                 → Backend Despachos (:8085) → MySQL
```

---

## Estado actual del despliegue

| Servicio | Replicas | Estado | Acceso |
|----------|:--------:|--------|--------|
| Frontend (React + Nginx) | 2 | ✅ Running | [LoadBalancer](http://ac8fb27e764e94113803456d4f4eccd0-1474001629.us-east-1.elb.amazonaws.com) |
| Backend Ventas (Spring Boot) | 2 | ✅ Running | Interno ClusterIP :8084 |
| Backend Despachos (Spring Boot) | 2 | ✅ Running | Interno ClusterIP :8085 |
| MySQL 8.0 | 1 | ✅ Running | Interno ClusterIP :3306 |

---

## Que hace cada cosa

Imagina una tienda online chica. Necesitas:

- **Un mostrador** (frontend) — hecho en React, con Vite y Tailwind. Atiende en el puerto 8081.
- **Una bodega de productos** (backend-ventas) — API en Spring Boot que maneja todo el catalogo y las ventas. Puerto 8084.
- **Una central de despachos** (backend-despachos) — otra API Spring Boot que se encarga de las entregas. Puerto 8085.
- **Un libro de contabilidad** (MySQL) — base de datos compartida donde ambos backends guardan y leen informacion.

En el medio hay un **Nginx** que actua como portero (API Gateway): recibe las peticiones del frontend y las redirige al backend que corresponda.

---

## Estructura del proyecto

```
proyecto_DevOps_examen/
├── infra/
│   ├── terraform/              # Infraestructura como codigo (8 archivos .tf)
│   └── k8s/                    # Manifiestos de Kubernetes
│       ├── namespace/          # Namespace devopsvg
│       ├── configmaps/         # Configuracion (URLs de BD, etc.)
│       ├── secrets/            # Credenciales de MySQL
│       ├── mysql/              # Base de datos
│       ├── back-ventas/        # Backend de ventas
│       ├── back-despachos/     # Backend de despachos
│       └── frontend/           # Frontend con LoadBalancer
├── scripts/
│   ├── deploy-k8s.sh           # Despliegue automatico a EKS
│   └── validate-deployment.sh  # Verificacion post-despliegue
├── .github/workflows/
│   ├── ci.yml                  # Compilacion automatica
│   ├── deploy.yml              # Despliegue continuo a EKS
│   └── destroy.yml             # Destruccion manual de infraestructura
├── front_despacho/             # Codigo fuente del frontend (React)
├── back-Ventas_SpringBoot/     # Codigo fuente backend ventas
├── back-Despachos_SpringBoot/  # Codigo fuente backend despachos
└── docs/
    ├── INFORME_DESPLIEGUE.md   # Reporte completo del despliegue
    └── PIPELINE-ANALISIS.md    # Analisis del pipeline CI/CD
```

---

## Como funciona el pipeline

### CI — Compilacion (`.github/workflows/ci.yml`)
Cada vez que haces push a `main`, se compila todo:
1. Frontend con `npm ci && npm run build`
2. Backend ventas con Maven
3. Backend despachos con Maven

Los 3 jobs corren en paralelo.

### CD — Despliegue (`.github/workflows/deploy.yml`)
Cuando haces push a la rama `deploy`, arranca el despliegue completo:

```
build → docker-push (3 imagenes en paralelo) → deploy-eks → validate
```

1. **build** — compila todo (igual que CI)
2. **docker-push** — construye las 3 imagenes Docker y las sube a Amazon ECR (el repositorio de imagenes)
3. **deploy-eks** — aplica los manifiestos a Kubernetes en orden: primero MySQL, luego los backends, luego el frontend
4. **validate** — verifica que todo haya quedado funcionando

### Kill Switch (`.github/workflows/destroy.yml`)
Si quieres destruir toda la infraestructura (VPC, EKS, todo), ejecutas este workflow manualmente desde GitHub Actions.

---

## Como usarlo

### Para desplegar en EKS
```bash
git checkout deploy
git push origin deploy
# El pipeline corre solo en GitHub Actions
```

### Para ver el estado del cluster
```bash
aws eks update-kubeconfig --name devopsvg-eks --region us-east-1
kubectl get pods,svc -n devopsvg
```

### Para desarrollo local
```bash
cp .env.example .env
# Editar .env con tus credenciales
docker compose up -d --build
```

| Servicio | URL local |
|----------|-----------|
| Frontend | http://localhost:8081 |
| Backend despachos | http://localhost:8082 |
| Backend ventas | http://localhost:8083 |

---

## Infraestructura (Terraform)

Todo el aprovisionamiento de AWS se maneja con Terraform:

| Recurso | Que hace |
|---------|----------|
| **VPC** | Red virtual con 2 subnets publicas (10.20.0.0/16) |
| **EKS** | Cluster Kubernetes v1.32 con 2 nodos t3.medium |
| **ECR** | 3 repositorios para las imagenes Docker |
| **CloudWatch** | Logs de aplicacion con retencion de 7 dias |
| **~20 recursos** en total, gestionados por Terraform |

```bash
cd infra/terraform
terraform init
terraform apply -auto-approve
```

---

## Cosas que aprendimos en el camino

### Sobre AWS Academy (Learner Lab)
- Las credenciales expiran cada ~4 horas. Hay que renovarlas antes de ejecutar el pipeline.
- No se pueden adjuntar politicas IAM nuevas (`voc-cancel-cred` bloquea). Usamos LabRole directamente.
- El LoadBalancer que creamos es clasico (Classic ELB), no NL B/ALB, porque el Learner Lab lo restringe.
- Si la sesion expira y se renueva, los nodos del cluster se reciclan (quedan `NotReady` y hay que agregar nuevos).

### Sobre el pipeline
- El bug del push Docker de back-ventas (manifest list multi-arch colgado en Windows) solo ocurre localmente. En GitHub Actions corre perfecto con runners Linux nativos.
- Si Terraform falla con "Addon already exists", hay que importar el recurso al state: `terraform import aws_eks_addon.vpc_cni ...`
- El node group tarda 8-12 minutos en crearse. Si el `apply` se va a timeout, solo importa el node group al state y vueleve a aplicar.

### Sobre los problemas que tuvimos
1. **Error de sintaxis en eks.tf** — el archivo no tenia un salto de linea al final, y Terraform en Linux lo interpretaba como `false}` en la misma linea. Lo soluciono `terraform fmt`.
2. **ECR Registry vacio** — el secret `AWS_ACCOUNT_ID` no estaba configurado en GitHub, asi que las imagenes apuntaban a `.dkr.ecr...` (sin el ID de cuenta). Se soluciono hardcodeando el account ID.
3. **MySQL con contrasena incorrecta** — el pipeline actualizo el secret de Kubernetes, pero MySQL ya estaba corriendo con la contrasena anterior. Se soluciono eliminando el pod de MySQL para que se reiniciara con las credenciales correctas.

---

## Secretos requeridos (GitHub Actions)

| Secret | Para que sirve |
|--------|----------------|
| `AWS_ACCESS_KEY_ID` | Credenciales de AWS Academy |
| `AWS_SECRET_ACCESS_KEY` | Credenciales de AWS Academy |
| `AWS_SESSION_TOKEN` | Token temporal (renovar cada 4h) |
| `AWS_ACCOUNT_ID` | ID de la cuenta AWS (12 digitos) |
| `MYSQL_ROOT_PASSWORD` | Contrasena root de MySQL |
| `MYSQL_USER` | Usuario de aplicacion para MySQL |
| `MYSQL_PASSWORD` | Contrasena del usuario de aplicacion |
