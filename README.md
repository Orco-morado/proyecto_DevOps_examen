# devopsvg — Proyecto DevOps

Una aplicacion web full-stack (React + Spring Boot + MySQL) desplegada en Amazon EKS con pipeline CI/CD automatizado. Proyecto transversal para el ramo ISY1101.

```
Frontend → Nginx → Backend Ventas (:8084) → MySQL
                 → Backend Despachos (:8085) → MySQL
```

---

## Estado actual

| Componente | Estado |
|------------|--------|
| Infraestructura AWS | Destruida |
| Pipeline CI/CD | Listo para usar |
| Codigo fuente | En el repo |

El 13/07/2026 se desplego completo en EKS, se valido operativo y luego se destruyo todo con `terraform destroy` para no gastar creditos del AWS Academy. El proyecto queda listo para redeploy cuando sea necesario.

---

## Que hace cada cosa

Imagina una tienda online chica. Necesitas:

- **Un mostrador** (frontend) — React con Vite y Tailwind, puerto 8081
- **La bodega de productos** (backend-ventas) — API Spring Boot para catalogo y ventas, puerto 8084
- **La central de despachos** (backend-despachos) — API Spring Boot para entregas, puerto 8085
- **El libro de contabilidad** (MySQL) — BD compartida, puerto 3306

En el medio hay un **Nginx** que recibe las peticiones del frontend y las redirige al backend correcto.

---

## Estructura del proyecto

```
proyecto_DevOps_examen/
├── infra/
│   ├── terraform/              # Infraestructura como codigo (.tf)
│   └── k8s/                    # Manifiestos de Kubernetes
│       ├── namespace/          # Namespace devopsvg
│       ├── configmaps/         # Configuracion
│       ├── secrets/            # Credenciales MySQL
│       ├── mysql/              # Base de datos
│       ├── back-ventas/        # Backend ventas
│       ├── back-despachos/     # Backend despachos
│       └── frontend/           # Frontend con LoadBalancer
├── scripts/
│   ├── deploy-k8s.sh           # Despliegue automatico a EKS
│   └── validate-deployment.sh  # Verificacion post-despliegue
├── .github/workflows/
│   ├── ci.yml                  # Compilacion automatica
│   ├── deploy.yml              # Despliegue a EKS
│   └── destroy.yml             # Destruccion de infraestructura
├── front_despacho/             # Codigo frontend (React)
├── back-Ventas_SpringBoot/     # Codigo backend ventas
├── back-Despachos_SpringBoot/  # Codigo backend despachos
└── docs/
    ├── INFORME_DESPLIEGUE.md   # Memoria del despliegue
    └── PIPELINE-ANALISIS.md    # Analisis del CI/CD
```

---

## Como funciona el pipeline

### CI — Compilacion (`ci.yml`)
Push a `main` → compila en paralelo: frontend (npm) + backends (Maven).

### CD — Despliegue (`deploy.yml`)
Push a `deploy` → 4 jobs en secuencia:

```
build → docker-push (3 imagenes en paralelo) → deploy-eks → validate
```

### Kill Switch (`destroy.yml`)
Workflow manual que ejecuta `terraform destroy`. Mata toda la infraestructura.

---

## Como usarlo

### Para desplegar en EKS desde cero
```bash
cd infra/terraform
terraform init && terraform apply -auto-approve   # ~15 min
git checkout deploy && git push origin deploy      # pipeline CI/CD
```

### Para desarrollo local
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

---

## Infraestructura (Terraform)

Todo se aprovisiona con Terraform (~20 recursos):

| Recurso | Detalle |
|---------|---------|
| **VPC** | 10.20.0.0/16, 2 subnets publicas, IGW |
| **EKS** | v1.32, 2 nodos t3.medium, addons gestionados |
| **ECR** | 3 repos con `force_delete = true` |
| **CloudWatch** | Log group, 7 dias retencion |

```bash
cd infra/terraform
terraform init
terraform apply -auto-approve
```

---

## Lo que aprendimos

### AWS Academy
- Credenciales expiran cada ~4h. Renovar antes de cada deploy.
- `voc-cancel-cred` bloquea `iam:AttachRolePolicy`. Usamos LabRole.
- Classic ELB, no NL B/ALB (restriccion del lab).
- Al renovar sesion, nodos viejos quedan `NotReady`.

### Pipeline
- Push Docker multi-arch se cuelga en Windows pero funciona perfecto en GHA (Linux).
- Si Terraform falla con "Addon already exists": `terraform import` y re-aplicar.
- Node group tarda 8-12 min en crearse.
- `terraform destroy` no borra ECR si tienen imagenes a menos que `force_delete = true`.

### Bugs que corregimos
1. **eks.tf sin salto de linea final** → Terraform en Linux lo leia como `false}`. `terraform fmt` lo arreglo.
2. **ECR Registry vacio** — faltaba `AWS_ACCOUNT_ID` como secret. Lo hardcodeamos.
3. **MySQL con contrasena incorrecta** — el pipeline actualizo el secret pero MySQL no se reinicio. Se elimino el pod para forzar reinicio.
4. **Pods viejos con `InvalidImageName`** — ReplicaSets de deploys anteriores seguian activos. `kubectl delete rs`.
5. **Nodos `NotReady`** — por renovacion de sesion Academy. Se agrego un nodo nuevo.

---

## Secretos requeridos (GitHub Actions)

| Secret | Para que sirve |
|--------|----------------|
| `AWS_ACCESS_KEY_ID` | Credenciales AWS Academy |
| `AWS_SECRET_ACCESS_KEY` | Credenciales AWS Academy |
| `AWS_SESSION_TOKEN` | Token temporal (4h) |
| `AWS_ACCOUNT_ID` | ID de cuenta AWS |
| `MYSQL_ROOT_PASSWORD` | Password root MySQL |
| `MYSQL_USER` | Usuario app MySQL |
| `MYSQL_PASSWORD` | Password app MySQL |
