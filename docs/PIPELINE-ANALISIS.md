# Analisis del Pipeline CI/CD — devopsvg

Documento para la evaluacion: analisis de desempeno, tiempos y oportunidades de mejora.

---

## Flujo del pipeline (`deploy.yml`)

| Job | Funcion | Dependencia |
|-----|---------|-------------|
| `build` | Compilar frontend (npm) + backends (Maven) | — |
| `docker-push` | Matrix: buildx + push 3 imagenes a ECR (paralelo) | `build` |
| `deploy-eks` | kubectl apply + rollout (mysql → backends → frontend) | `docker-push` |
| `validate` | Verificar pods, servicios, HPA, LoadBalancer | `deploy-eks` |

---

## Metricas a registrar (desde GitHub Actions)

| Paso | Tiempo estimado | Tiempo real | Observaciones |
|------|-----------------|-------------|---------------|
| Build (npm + Maven) | ~2-3 min | ___ min | Secuencial dentro del job |
| Build + push frontend | ~1-2 min | ___ min | docker/build-push-action@v6 + cache GHA |
| Build + push back-ventas | ~2-3 min | ___ min | Maven + Docker (multi-stage) |
| Build + push back-despachos | ~2-3 min | ___ min | Maven + Docker (multi-stage) |
| Deploy a EKS (kubectl) | ~3-5 min | ___ min | Rollout Spring Boot + readiness probe |
| Validacion | ~1-2 min | ___ min | Pods, servicios, HPA, LB |
| **Total** | **~11-18 min** | ___ min | |

> Los 3 builds de Docker corren en paralelo (matrix), reduciendo el tiempo total respecto a la version anterior (17 pasos secuenciales).

---

## Optimizaciones implementadas

1. **Matrix de builds en paralelo** — las 3 imagenes se construyen y suben simultaneamente.
2. **Docker layer caching** (type=gha) — reduce tiempo de rebuild al cachear capas entre runs.
3. **Tag por commit SHA** — trazabilidad imagen ↔ codigo desplegado.
4. **docker/build-push-action@v6** — buildx nativo, soporte multi-platform, build summaries.
5. **$GITHUB_STEP_SUMMARY** — resumen del despliegue visible directamente en el run de Actions.
6. **Kill Switch** — workflow manual para destruir infraestructura.
7. **Orden de deploy** — mysql primero, luego backends, luego frontend.

---

## Oportunidades de mejora futuras

| Mejora | Impacto | Complejidad |
|--------|---------|-------------|
| Cache de dependencias Maven (`~/.m2`) | -1 min en build | Baja |
| Cache de `node_modules` | -1 min en build | Baja |
| Tests unitarios en CI (no skip) | Calidad | Media |
| Blue/green con Argo Rollouts | Zero downtime | Alta |
| AWS RDS en lugar de MySQL en K8s | Produccion real | Media |
| Terraform Cloud / S3 backend | Estado compartido | Media |

---

## Errores comunes y solucion

| Error | Causa | Solucion |
|-------|-------|----------|
| `403 ECR` | Credenciales expiradas (Academy, 4h) | Renovar secrets en GitHub |
| `ImagePullBackOff` | Imagen no existe en ECR | Verificar push en paso anterior |
| Rollout timeout Spring Boot | MySQL no listo | Orden de deploy: mysql primero |
| LB sin hostname | AWS tarda en provisionar | validate espera hasta 300s |
| `ResourceInUseException: Addon already exists` | Addon creado manualmente antes que Terraform | `terraform import` del addon al state |
| CoreDNS `DEGRADED` (falso positivo) | Health check transitorio | Verificar con `kubectl get pods -n kube-system` |
| Node group `CREATING` por >10 min | Terraform apply timeouteó; instancias OK | `terraform import aws_eks_node_group.main` |
