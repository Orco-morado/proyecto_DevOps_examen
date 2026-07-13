#docker-compose up -d --build
#esto es para construir la imagen de docker con el nombre 
#api-despacho a partir del Dockerfile en el directorio actual

#multi-stage

# Multi-stage build

# Etapa 1: Construcción
FROM public.ecr.aws/docker/library/maven:3.9.4-eclipse-temurin-17 AS build
WORKDIR /build
COPY pom.xml .
COPY src ./src
# Saltamos las pruebas aquí; la validación se realiza en GitHub Actions
RUN mvn clean package -DskipTests

# Etapa 2: Ejecución
FROM public.ecr.aws/docker/library/eclipse-temurin:17-jre
WORKDIR /app

# Creación de grupo y usuario no root por seguridad
RUN groupadd -r devopsgroupback && useradd -r -g devopsgroupback devopsusuariobackdespacho1

COPY --from=build /build/target/*.jar app.jar

# Cambio de propietario y usuario
RUN chown devopsusuariobackdespacho1:devopsgroupback app.jar
USER devopsusuariobackdespacho1

EXPOSE 8085
ENTRYPOINT ["java", "-jar", "app.jar"]