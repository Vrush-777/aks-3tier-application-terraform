# Production-ready Multi-stage Dockerfile for Spring Boot Backend
# Stage 1: Maven build stage
FROM maven:3.9-eclipse-temurin-21-alpine AS maven-builder

WORKDIR /build

# Copy pom.xml for dependency resolution (better layer caching)
COPY ems-backend/pom.xml .

# Download Maven dependencies offline (cached layer)
RUN mvn dependency:go-offline -B

# Copy source code
COPY ems-backend/src ./src

# Build application with optimizations
RUN mvn clean package -DskipTests -q

# Stage 2: Runtime stage - Production image
FROM eclipse-temurin:21-jre-alpine

# Metadata labels
LABEL maintainer="Platform Engineering Team"
LABEL description="EMS Backend - Employee Management System API"
LABEL version="1.0"

WORKDIR /app

# Install runtime dependencies (curl for healthcheck)
RUN apk add --no-cache \
    curl \
    && rm -rf /var/cache/apk/*

# Create non-root user for security (principle of least privilege)
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy built JAR from maven-builder stage
COPY --from=maven-builder /build/target/*.jar app.jar

# Change ownership to non-root user
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose Spring Boot server port
EXPOSE 8080

# JVM memory optimizations (20% heap for small containers, adjust as needed)
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:InitialRAMPercentage=50.0 -Dspring.profiles.active=${SPRING_PROFILES_ACTIVE:-dev}"

# Health check for orchestration platforms (Kubernetes, Docker Swarm)
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

# Startup command using exec form for signal handling
ENTRYPOINT ["java", "-jar"]
CMD ["app.jar"]

# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]
