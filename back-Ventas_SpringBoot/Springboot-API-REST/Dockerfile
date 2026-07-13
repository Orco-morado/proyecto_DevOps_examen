
# Multi-stage build

# Etapa 1: Construcción
FROM public.ecr.aws/docker/library/maven:3.9-eclipse-temurin-17 as builder
WORKDIR /build
COPY pom.xml .
COPY src ./src
# Saltamos las pruebas aquí; la validación se realiza en GitHub Actions
RUN mvn clean package -DskipTests

# Etapa 2: Ejecución
FROM public.ecr.aws/docker/library/eclipse-temurin:17-jre
WORKDIR /app

# Creación de grupo y usuario no root por seguridad
RUN groupadd -r devopsgroupback && useradd -r -g devopsgroupback devopsusuariobackventa1

COPY --from=builder /build/target/*.jar app.jar

# Cambio de propietario y usuario
RUN chown devopsusuariobackventa1:devopsgroupback app.jar
USER devopsusuariobackventa1

EXPOSE 8084
ENTRYPOINT ["java","-jar","app.jar"]