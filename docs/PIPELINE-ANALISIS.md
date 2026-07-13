# Analisis del Pipeline CI/CD

## Que hace este documento

Analisis del pipeline de despliegue de devopsvg para la evaluacion: tiempos, problemas que encontramos, optimizaciones que hicimos y cosas que podriamos mejorar.

---

## Como funciona el pipeline

El archivo `deploy.yml` tiene 4 jobs que corren en secuencia:

```
build (compila todo)
  └─ docker-push (3 imagenes en paralelo)
       └─ deploy-eks (aplica a Kubernetes)
            └─ validate (verifica que funcione)
```

### Tiempo total estimado vs real

Basado en la ejecucion #28 del pipeline:

| Paso | Tiempo estimado | Tiempo real (#28) | Que paso |
|------|:---------------:|:-----------------:|----------|
| Compilacion (build) | 2-3 min | ~4s | Ya estaba cacheado del commit anterior |
| Build + push 3 imagenes (docker-push) | 3-5 min | ~7s | Cache GHA, imagenes ya construidas |
| Despliegue en EKS (deploy-eks) | 3-5 min | ~10m 13s | MySQL tuvo que reiniciarse por credenciales incorrectas |
| Validacion (validate) | 1-2 min | ~14s | Todo OK |
| **Total** | **~12-15 min** | **~10m 31s** | El deploy fue lento por el reinicio de MySQL |

> **Nota**: En condiciones normales (sin reinicios de MySQL), el pipeline debiera completarse en 5-8 minutos. El run #28 se alargo porque corregimos credenciales de base de datos en caliente.

---

## Optimizaciones que implementamos

1. **Builds en paralelo** — las 3 imagenes Docker se construyen y suben a ECR al mismo tiempo, en vez de una detras de otra.
2. **Cache de Docker layers** — usamos cache de GitHub Actions para no reconstruir capas que no cambiaron.
3. **Tag por commit** — cada imagen se etiqueta con el SHA del commit, asi sabemos exactamente que codigo esta corriendo.
4. **Resumen en GITHUB_STEP_SUMMARY** — al final del deploy se genera un resumen visible directamente en la interfaz de GitHub Actions.
5. **Kill Switch** — workflow manual para destruir toda la infraestructura si algo sale mal.
6. **Orden de despliegue** — primero MySQL, luego los backends (que dependen de la BD), y al final el frontend.

---

## Problemas que encontramos y como los solucionamos

### 1. Error de sintaxis en Terraform (`eks.tf:29`)
- **Sintoma**: `Error: Missing newline after argument — bootstrap_self_managed_addons = false}`
- **Causa**: El archivo no tenia un salto de linea al final, y en Linux Terraform lo interpretaba como si la llave `}` estuviera pegada al argumento.
- **Solucion**: `terraform fmt -recursive infra/terraform/` arreglo el formato y agrego el newline faltante.

### 2. ECR Registry vacio
- **Sintoma**: Las imagenes apuntaban a `.dkr.ecr.us-east-1.amazonaws.com/...` (partia con punto, faltaba el account ID).
- **Causa**: El secret `AWS_ACCOUNT_ID` no estaba configurado en GitHub Actions, asi que `secrets.AWS_ACCOUNT_ID` se resolvia como string vacio.
- **Solucion**: Hardcodeamos el account ID (`847750225273`) directamente en el workflow. No es un valor sensible.

### 3. Credenciales de MySQL desincronizadas
- **Sintoma**: Los backends fallaban con `Access denied for user 'admin'@'...' (using password: YES)`.
- **Causa**: El pipeline actualizo el secret de Kubernetes con nuevas credenciales, pero MySQL ya estaba corriendo con las credenciales viejas (creadas en su primera inicializacion).
- **Solucion**: Eliminamos el pod de MySQL para que se recreara con las credenciales actuales del secret. Como usa `emptyDir`, los datos persisten solo mientras el pod vive (para un proyecto academico es aceptable).

### 4. Pods viejos con `InvalidImageName`
- **Sintoma**: Varios pods quedaron con estado `InvalidImageName` de deploys anteriores.
- **Causa**: Los ReplicaSets viejos seguian activos, recreando pods con la imagen incorrecta.
- **Solucion**: Eliminamos los ReplicaSets antiguos (`kubectl delete rs`).

### 5. Nodos `NotReady` por renovacion de sesion Academy
- **Sintoma**: Al renovar credenciales AWS Academy, los nodos viejos quedaban `NotReady` y no habia suficientes recursos.
- **Causa**: La sesion del Learner Lab expiro y al renovarse los nodos existentes quedaron huérfanos.
- **Solucion**: Escalamos el node group para agregar un nodo nuevo y los pods se reasignaron.

---

## Oportunidades de mejora

Si el proyecto continuara, estas son las cosas que valdria la pena hacer:

| Mejora | Por que | Esfuerzo |
|--------|---------|:--------:|
| Cachear `.m2` y `node_modules` en CI | Ahorraria ~1 min en cada build de los backends | Bajo |
| Agregar tests unitarios al pipeline | Hoy se saltan con `-DskipTests` | Medio |
| Migrar MySQL a Amazon RDS | MySQL en Kubernetes no es ideal para produccion (datos efimeros con `emptyDir`) | Medio |
| Terraform Cloud o S3 backend | El estado de Terraform esta en el repo (no es lo ideal para un equipo) | Bajo |
| Blue/green deployment con Argo Rollouts | Despliegues sin downtime | Alto |
| Notificaciones Slack/Discord | Saber cuando el pipeline falla sin tener que revisar GitHub | Bajo |

---

## Comandos de referencia

```bash
# Ver las ejecuciones del pipeline
gh run list --branch deploy

# Ver los logs de una ejecucion
gh run view <run-id> --log

# Forzar la ejecucion del pipeline
gh workflow run deploy.yml --ref deploy
```
