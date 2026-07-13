# Frontend Despacho

Aplicacion React/Vite para administrar ventas y despachos.

## Variables

- `VITE_API_DESPACHOS_URL`: URL base de la API de despachos.
- `VITE_API_VENTA_URL`: URL base de la API de ventas.

En EKS se dejan vacias para usar rutas relativas por el ALB:

- `/api/v1/despachos`
- `/api/v1/ventas`

En local se pueden configurar con:

```bash
VITE_API_DESPACHOS_URL=http://localhost:8082
VITE_API_VENTA_URL=http://localhost:8083
```

## Comandos

```bash
npm install
npm run dev
npm run build
```
