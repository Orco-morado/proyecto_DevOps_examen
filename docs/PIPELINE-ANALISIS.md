# Analisis del Pipeline CI/CD

## De que va esto

El pipeline automatiza todo: cuando haces push a `deploy`, compila, empaqueta en Docker, sube a ECR y despliega en EKS. Sin intervencion manual.

---

## Arquitectura del pipeline

El archivo `deploy.yml` tiene 4 jobs secuenciales:

```
build (compila apps)
  └─ docker-push (3 imagenes en paralelo)
       └─ deploy-eks (kubectl apply)
            └─ validate (verifica)
```

### Job 1: build
Compila frontend (npm ci + build) y backends (Maven package). Los 3 en paralelo.

### Job 2: docker-push
Matrix con 3 servicios. Cada uno construye su imagen con `docker/build-push-action@v6` y la sube a ECR con dos tags: `latest` y el SHA del commit.

### Job 3: deploy-eks
Aplica los manifiestos en orden: configmaps → MySQL → back-ventas → back-despachos → frontend. Espera el rollout de cada uno antes de seguir.

### Job 4: validate
Verifica pods, servicios, HPA y LoadBalancer. Si todo esta bien, el pipeline pasa.

---

## Tiempos reales (run #28)

| Paso | Duracion | Explicacion |
|------|:--------:|-------------|
| Compilacion | ~4s | Ya estaba cacheado del commit anterior |
| Build + push Docker | ~7s | Cache de capas de GitHub Actions |
| Deploy EKS | ~10m 13s | Se alargo porque MySQL tuvo que reiniciarse |
| Validacion | ~14s | Todo OK |
| **Total** | **~10m 31s** | En condiciones normales serian 5-8 min |

---

## Optimizaciones que metimos

1. **Builds en paralelo** — las 3 imagenes se construyen al mismo tiempo
2. **Cache de Docker layers** — no reconstruye lo que no cambio
3. **Tag por commit SHA** — sabes exactamente que codigo esta corriendo
4. **Resumen automatico** — al final del deploy se genera un resumen visible en GitHub Actions
5. **Kill Switch** — workflow manual para terraform destroy
6. **Orden de deploy** — MySQL primero, luego backends, frontend al final

---

## Problemas que encontramos

### 1. Terraform con error de sintaxis
**Sintoma**: `bootstrap_self_managed_addons = false}` — Terraform veia la llave pegada al argumento.  
**Causa**: El archivo no tenia salto de linea al final. En Windows se veia bien, en Linux no.  
**Solucion**: `terraform fmt -recursive infra/terraform/`.

### 2. ECR Registry apuntaba a la nada
**Sintoma**: Las imagenes se descargaban de `.dkr.ecr...` (partia con punto).  
**Causa**: `AWS_ACCOUNT_ID` no existia como secret en GitHub.  
**Solucion**: Hardcodear `847750225273` en deploy.yml. No es informacion sensible.

### 3. MySQL no aceptaba las credenciales
**Sintoma**: `Access denied for user 'admin'@'...'`  
**Causa**: El pipeline actualizo el secret de Kubernetes, pero MySQL estaba vivo con las credenciales viejas de cuando se creo.  
**Solucion**: Eliminar el pod de MySQL. Al recrearse, tomo las credenciales nuevas del secret.

### 4. Pods fantasmas con `InvalidImageName`
**Sintoma**: Varios pods atorados en estado `InvalidImageName` de deploys anteriores.  
**Causa**: Los ReplicaSets viejos seguian activos y recreaban los pods.  
**Solucion**: `kubectl delete rs` con los ReplicaSets antiguos.

### 5. Nodos muertos despues de renovar sesion
**Sintoma**: Al renovar credenciales AWS Academy, los nodos viejos quedaban `NotReady`.  
**Causa**: La sesion del Learner Lab expiro.  
**Solucion**: Escalar el node group para que AWS creara un nodo nuevo.

---

## Lo que mejoraria si siguiera

| Mejora | Por que |
|--------|---------|
| Cachear `.m2` y `node_modules` | Ahorraria ~1 min en cada build |
| Tests unitarios en CI | Hoy se saltan con `-DskipTests` |
| Migrar MySQL a RDS | MySQL en Kubernetes con `emptyDir` no es para produccion |
| Terraform Cloud o S3 backend | El estado local en el repo no es ideal para equipos |
| Notificaciones Slack/Discord | Saber sin tener que revisar GitHub |

---

## Comandos utiles

```bash
# Ver runs del pipeline
gh run list --branch deploy

# Ver logs de un run
gh run view <run-id> --log

# Disparar manualmente
gh workflow run deploy.yml --ref deploy
```
