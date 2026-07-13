# Etapa 1: Construcción
FROM public.ecr.aws/docker/library/node:20-alpine AS builder
WORKDIR /build

ARG VITE_API_DESPACHOS_URL
ARG VITE_API_VENTA_URL
ENV VITE_API_DESPACHOS_URL=$VITE_API_DESPACHOS_URL
ENV VITE_API_VENTA_URL=$VITE_API_VENTA_URL

COPY package.json ./
RUN npm install
COPY . .
RUN npm run build

# Etapa 2: Ejecución
FROM public.ecr.aws/docker/library/nginx:alpine

# Copiar configuración y archivos compilados
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /build/dist /usr/share/nginx/html

# 1. Dar permisos al usuario 'nginx' sobre las carpetas que requiere para funcionar
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    chown -R nginx:nginx /etc/nginx/conf.d && \
    touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid

# 2. Cambiar al usuario no root (ya existe en la imagen base)
USER nginx

# 3. Exponer un puerto no privilegiado
# Se utiliza el puerto 8081 en lugar del 80 por defecto porque el usuario nginx
# no tiene permisos para abrir puertos inferiores al 1024 sin ser root.
EXPOSE 8081