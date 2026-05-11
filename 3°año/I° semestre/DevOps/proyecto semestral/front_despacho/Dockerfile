#etapa 1
FROM node:20-alpine AS builder
WORKDIR /build
COPY package.json ./
RUN npm install
COPY . .
RUN npm run build

#etapa 2
FROM nginx:alpine

# Copiar configuración y archivos compilados
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /build/dist /usr/share/nginx/html

# 1. Dar permisos al usuario 'nginx' sobre las carpetas que requiere para funcionar 
#recuerda que el \ sirve para continuar la linea de comando abajo
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    chown -R nginx:nginx /etc/nginx/conf.d && \
    touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid

# 2. Cambiar al usuario no root (ya existe en la imagen base)
USER nginx

# 3. Exponer un puerto no privilegiado
# Se utiliza el puerto 8080 en lugar del 80 por defecto esto es porque el usuario de nginx
# no tiene permisos para abrir puertos inferiores al 1024 sin ser root
# porlotanto al establecer el puerto 8080 se asegura que nginx pueda usarlo sin problemas
EXPOSE 8081