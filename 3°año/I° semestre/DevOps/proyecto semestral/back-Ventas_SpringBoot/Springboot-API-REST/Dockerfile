

# multi-stage

FROM maven:3.9-eclipse-temurin-17 as builder
WORKDIR /build
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests


FROM eclipse-temurin:17-jdk
WORKDIR /app
RUN groupadd -r devopsgroupback && useradd -r -g devopsgroupback devopsusuariobackventa1

COPY --from=builder /build/target/*.jar app.jar
RUN chown devopsusuariobackventa1:devopsgroupback app.jar
USER devopsusuariobackventa1

<<<<<<< HEAD
EXPOSE 8084
=======
EXPOSE 8083
>>>>>>> f061440a9feba86e0f14d4f089f2666412ec53d5
ENTRYPOINT ["java","-jar","app.jar"]