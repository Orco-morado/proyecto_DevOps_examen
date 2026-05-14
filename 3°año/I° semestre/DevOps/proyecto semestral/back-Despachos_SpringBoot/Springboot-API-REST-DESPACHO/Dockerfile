#docker build -t api-despacho .
#esto es para construir la imagen de docker con el nombre 
#api-despacho a partir del Dockerfile en el directorio actual

#multi-stage

#etapa 1
FROM maven:3.9.4-eclipse-temurin-17 AS build
WORKDIR /build
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

<<<<<<< HEAD
#la etapa anterior esta por morir
FROM eclipse-temurin:17-jdk
=======
FROM eclipse-temurin:21-jdk
>>>>>>> f061440a9feba86e0f14d4f089f2666412ec53d5
WORKDIR /app
#creo el grupo y el usuario para ejecutar la aplicacion con un usuario no root
RUN groupadd -r devopsgroupback && useradd -r -g devopsgroupback devopsusuariobackdespacho1
COPY --from=build /build/target/*.jar app.jar
#cambio el propietario del archivo jar al usuario creado
RUN chown devopsusuariobackdespacho1:devopsgroupback app.jar
#cambio al usuario creado para ejecutar no debe ser root por seguridad."solicitud de la guia"
USER devopsusuariobackdespacho1

EXPOSE 8085
ENTRYPOINT ["java", "-jar", "app.jar"]
