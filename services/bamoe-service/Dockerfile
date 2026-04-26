FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /build
COPY pom.xml .
RUN mvn -B dependency:go-offline -DskipTests || true
COPY src ./src
RUN mvn -B package -DskipTests -Dquarkus.container-image.build=false

FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=build /build/target/quarkus-app/lib/ ./lib/
COPY --from=build /build/target/quarkus-app/*.jar ./
COPY --from=build /build/target/quarkus-app/app/ ./app/
COPY --from=build /build/target/quarkus-app/quarkus/ ./quarkus/
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "quarkus-run.jar"]
