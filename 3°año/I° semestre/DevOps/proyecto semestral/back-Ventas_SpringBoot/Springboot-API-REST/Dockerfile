

# multi-stage

FROM maven:3.9-eclipse-temurin-21 as builder
WORKDIR /build
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests


FROM eclipse-temurin:21-jdk
WORKDIR /app
RUN groupadd -r devopsgroupback && useradd -r -g devopsgroupback devopsusuariobackventa1

COPY --from=builder /build/target/*.jar app.jar
RUN chown devopsusuariobackventa1:devopsgroupback app.jar
USER devopsusuariobackventa1

EXPOSE 8080
ENTRYPOINT ["java","-jar","app.jar"]