# Analisis del Pipeline CI/CD — devopsVG

Documento para la evaluacion: analisis de desempeno, tiempos y oportunidades de mejora.

---

## Flujo del pipeline (`deploy.yml`)

| Job | Funcion | Dependencia |
|-----|---------|-------------|
| `build-push-deploy` | Terraform apply → Build 3 imagenes → Push ECR → Deploy EKS → Validar | — |

---

## Metricas a registrar (desde GitHub Actions)

Completar tras ejecutar el pipeline al menos una vez:

| Paso | Tiempo estimado | Tiempo real | Observaciones |
|------|-----------------|-------------|---------------|
| Terraform init + apply | ~3-5 min | ___ min | |
| Build + push backend despachos | ~3-4 min | ___ min | Maven + Docker |
| Build + push backend ventas | ~3-4 min | ___ min | Maven + Docker |
| Build + push frontend | ~2-3 min | ___ min | Node + Vite + Docker |
| Deploy a EKS (kubectl) | ~8-12 min | ___ min | Rollout Spring Boot tarda |
| Validacion | ~2-3 min | ___ min | Espera del Load Balancer |
| **Total** | ~21-31 min | ___ min | |

---

## Optimizaciones implementadas

1. **Cache de estado Terraform** — evita recrear infraestructura en cada deploy.
2. **Tag por commit SHA** — trazabilidad imagen ↔ codigo desplegado.
3. **Orden de deploy** — mysql primero, luego backends, luego frontend.
4. **Kill Switch** — workflow manual para destruir infraestructura y no consumir creditos.

---

## Oportunidades de mejora futuras

| Mejora | Impacto | Complejidad |
|--------|---------|-------------|
| Cache de dependencias Maven (`~/.m2`) | -2 min en build | Baja |
| Cache de `node_modules` | -1 min en build | Baja |
| Matrix de builds en paralelo | -4 min en total | Media |
| Tests unitarios en CI (no skip) | Calidad | Media |
| Blue/green con Argo Rollouts | Zero downtime | Alta |
| AWS RDS en lugar de MySQL en K8s | Produccion real | Media |

---

## Errores comunes y solucion

| Error | Causa | Solucion |
|-------|-------|----------|
| `403 ECR` | Credenciales expiradas (Academy) | Renovar secrets en GitHub |
| `ImagePullBackOff` | Imagen no existe en ECR | Verificar push en paso anterior |
| Rollout timeout Spring Boot | MySQL no listo | Orden de deploy: mysql primero |
| LB sin hostname | AWS tarda en provisionar | validate espera hasta 300s |
