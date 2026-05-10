#multi-stage

#etapa 1
FROM maven:3.9.4-eclipse-temurin-17 AS build
WORKDIR /build
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

#la etapa anterior esta por morir
FROM eclipse-temurin:21-jdk
WORKDIR /app
#creo el grupo y el usuario para ejecutar la aplicacion con un usuario no root
RUN groupadd -r devopsgroupback && useradd -r -g devopsgroupback devopsusuariobackdespacho1
COPY --from=build /build/target/*.jar app.jar
#cambio el propietario del archivo jar al usuario creado
RUN chown devopsusuariobackdespacho1:devopsgroupback app.jar
#cambio al usuario creado para ejecutar no debe ser root por seguridad."solicitud de la guia"
USER devopsusuariobackdespacho1

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
