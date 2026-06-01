# MySQL to PostgreSQL Migration Guide

## Overview
This document outlines the complete migration of the Employee Management System from MySQL to PostgreSQL with enterprise-grade improvements.

## Migration Objectives
✅ Replace MySQL with PostgreSQL
✅ Externalize database configuration using environment variables
✅ Add Spring Boot Actuator endpoints for health checks
✅ Implement Global Exception Handler
✅ Add structured logging throughout the application
✅ Create environment-specific configuration profiles
✅ Containerize application with Docker and Docker Compose

## Key Changes Summary

### 1. **Dependencies Migration (pom.xml)**

#### Removed:
```xml
<dependency>
    <groupId>com.mysql</groupId>
    <artifactId>mysql-connector-j</artifactId>
    <scope>runtime</scope>
</dependency>
```

#### Added:
```xml
<!-- PostgreSQL Driver -->
<dependency>
    <groupId>org.postgresql</groupId>
    <artifactId>postgresql</artifactId>
    <scope>runtime</scope>
</dependency>

<!-- Spring Boot Actuator for health checks -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>

<!-- Structured Logging -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-logging</artifactId>
</dependency>
```

**Why PostgreSQL Driver?**
- Better performance and reliability
- Superior support for complex queries
- Better compliance with SQL standards
- Built-in JSON/JSONB support for future enhancements

---

### 2. **Database Configuration Changes**

#### Before (MySQL):
```properties
spring.datasource.url=jdbc:mysql://localhost:3306/employee
spring.datasource.username=root
spring.datasource.password=hardcoded_password
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.MySQL8Dialect
```

#### After (PostgreSQL with Environment Variables):
```yaml
spring.datasource.url=jdbc:postgresql://${DB_HOST:localhost}:${DB_PORT:5432}/${DB_NAME:employee_dev}
spring.datasource.username=${DB_USERNAME:postgres}
spring.datasource.password=${DB_[REDACTED_GENERIC_PASSWORD_2]}
spring.datasource.driver-class-name=org.postgresql.Driver
spring.jpa.database-platform=org.hibernate.dialect.PostgreSQLDialect
```

**Environment Variables Required:**
- `DB_HOST` - PostgreSQL server hostname
- `DB_PORT` - PostgreSQL server port (default: 5432)
- `DB_NAME` - Database name
- `DB_USERNAME` - Database user
- `DB_PASSWORD` - Database password

---

### 3. **Hibernate Dialect Update**

| Database | Dialect Class |
|----------|---------------|
| MySQL 8 | `org.hibernate.dialect.MySQL8Dialect` |
| PostgreSQL | `org.hibernate.dialect.PostgreSQLDialect` |

**PostgreSQL Dialect Benefits:**
- Optimized UUID generation
- Better sequence handling
- Native ARRAY and JSON type support
- Improved query optimization

---

### 4. **Configuration Profiles**

Created three environment-specific profiles:

#### **application-dev.yml** (Development)
- DDL: `create-drop` (recreate schema on startup)
- SQL logging: Enabled with TRACE level for bind parameters
- All actuator endpoints exposed
- Show SQL: True for debugging

#### **application-qa.yml** (Quality Assurance)
- DDL: `validate` (only validates existing schema)
- SQL logging: Minimal (WARN level)
- Limited actuator endpoints
- Connection pooling: Basic configuration

#### **application-prod.yml** (Production)
- DDL: `validate` (prevents accidental schema changes)
- SQL logging: Disabled
- Connection pooling: Optimized (max 20, min 5 connections)
- Structured logging with rotation and size limits
- Security: Limited actuator endpoints
- Performance: Batch size 20, query optimization enabled
- Session timeout: 30 minutes

---

### 5. **Global Exception Handler**

**File:** `GlobalExceptionHandler.java`

Handles exceptions across the application:
- `ResourceNotFoundException` → HTTP 404 (Not Found)
- `ProductNotFoundException` → HTTP 404 (Not Found)
- `IllegalArgumentException` → HTTP 400 (Bad Request)
- Generic `Exception` → HTTP 500 (Internal Server Error)

**Response Format:**
```json
{
  "timestamp": "2024-06-01T10:30:00",
  "status": 404,
  "error": "Not Found",
  "message": "Employee not found with ID: 1",
  "path": "/api/emp/1"
}
```

---

### 6. **Structured Logging**

#### Service Layer (EmployeeService)
```java
logger.info("Adding new employee with email: {}", employee.getEmail());
logger.warn("Employee with ID {} not found", employeeId);
logger.error("Error adding employee with email: {}", employee.getEmail(), e);
```

#### Controller Layer (EmployeeController)
```java
logger.info("Request received to create employee with email: {}", employee.getEmail());
logger.debug("Employee created successfully with ID: {}", emp.getId());
```

#### Global Exception Handler
```java
logger.warn("ResourceNotFoundException caught: {}", ex.getMessage());
logger.error("Global Exception caught: {}", ex.getMessage(), ex);
```

**Logging Levels by Profile:**
| Profile | Root | Application |
|---------|------|-------------|
| dev | INFO | DEBUG |
| qa | WARN | INFO |
| prod | WARN | WARN |

---

### 7. **Spring Boot Actuator Endpoints**

**Enabled Endpoints:**

| Endpoint | Purpose |
|----------|---------|
| `/actuator/health` | Application health status |
| `/actuator/health/readiness` | Readiness check (for Kubernetes) |
| `/actuator/health/liveness` | Liveness check (for Kubernetes) |
| `/actuator/info` | Application information |
| `/actuator/metrics` | Application metrics |
| `/actuator/prometheus` | Prometheus metrics export |

**Health Check Response:**
```json
{
  "status": "UP",
  "components": {
    "db": {
      "status": "UP",
      "details": {
        "database": "PostgreSQL",
        "hello": 1
      }
    }
  }
}
```

---

### 8. **Entity Compatibility**

**Employee Entity - PostgreSQL Compatible:**
```java
@Entity(name = "employeess")
public class Employee {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(name = "first_name")
    private String firstName;
    
    @Column(name = "last_name")
    private String lastName;
    
    @Column(name = "email_id", nullable = false, unique = true)
    private String email;
}
```

**PostgreSQL-Specific Features Used:**
- `BIGSERIAL` for auto-increment (via GenerationType.IDENTITY)
- Constraints: `NOT NULL`, `UNIQUE`
- Indexes on frequently queried columns (email)
- Timestamp columns with default values

---

### 9. **Docker & Container Configuration**

#### Docker Compose Services:
1. **PostgreSQL Service**
   - Image: `postgres:16-alpine`
   - Healthcheck: Port 5432 connectivity
   - Persistent volume for data
   - Auto-initialization script

2. **Backend Service**
   - Multi-stage build for optimized image
   - Non-root user (appuser) for security
   - Healthcheck: `/actuator/health` endpoint
   - Depends on PostgreSQL being healthy

3. **Frontend Service**
   - React application
   - Environment variable support
   - Points to backend API URL

#### Running with Docker Compose:
```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f ems-backend

# Stop all services
docker-compose down

# Clean up including volumes
docker-compose down -v
```

---

### 10. **Files Modified/Created**

#### **Modified Files:**
1. `pom.xml` - Updated dependencies
2. `src/main/java/.../controller/EmployeeController.java` - Added logging
3. `src/main/java/.../service/EmployeeService.java` - Added logging & improved error handling

#### **Created Files:**
1. `src/main/resources/application.yml` - Main configuration
2. `src/main/resources/application-dev.yml` - Development profile
3. `src/main/resources/application-qa.yml` - QA profile
4. `src/main/resources/application-prod.yml` - Production profile
5. `src/main/java/.../exception/GlobalExceptionHandler.java` - Global error handling
6. `docker-compose.yml` - Container orchestration
7. `ems-backend/Dockerfile` - Backend image specification
8. `init-db.sql` - PostgreSQL initialization script
9. `.env.example` - Environment variables template

---

## Migration Steps

### Step 1: Update Dependencies
```bash
cd ems-backend
mvn clean install
```

### Step 2: Configure Environment Variables
```bash
cp .env.example .env
# Edit .env with your PostgreSQL credentials
```

### Step 3: Start Services with Docker Compose
```bash
docker-compose up -d
```

### Step 4: Verify Database Connection
```bash
# Check logs
docker-compose logs ems-backend

# Test health endpoint
curl http://localhost:8080/actuator/health
```

### Step 5: Test API Endpoints
```bash
# Create employee
curl -X POST http://localhost:8080/api/emp \
  -H "Content-Type: application/json" \
  -d '{"firstName":"John","lastName":"Doe","email":"john@example.com"}'

# Get all employees
curl http://localhost:8080/api/emp

# Get employee by ID
curl http://localhost:8080/api/emp/1

# Get employee by email
curl http://localhost:8080/api/emp/email-id/john@example.com

# Update employee
curl -X PUT http://localhost:8080/api/emp/1 \
  -H "Content-Type: application/json" \
  -d '{"firstName":"Jane","lastName":"Doe","email":"jane@example.com"}'

# Delete employee
curl -X DELETE http://localhost:8080/api/emp/1
```

---

## Running Locally (Without Docker)

### Prerequisites:
- PostgreSQL 16+ installed
- Java 17+ installed
- Maven 3.6+

### Steps:

1. **Create PostgreSQL Database:**
```sql
CREATE DATABASE employee_dev;
CREATE USER postgres WITH PASSWORD 'password';
GRANT ALL PRIVILEGES ON DATABASE employee_dev TO postgres;
```

2. **Configure Environment Variables:**
```bash
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=employee_dev
export DB_USERNAME=postgres
export DB_[REDACTED_GENERIC_PASSWORD_2]=your_password
export SPRING_PROFILES_ACTIVE=dev
```

3. **Build and Run:**
```bash
cd ems-backend
mvn clean spring-boot:run
```

4. **Access Application:**
- API: `http://localhost:8080`
- Health: `http://localhost:8080/actuator/health`
- Metrics: `http://localhost:8080/actuator/metrics`

---

## Performance Optimizations

### Connection Pooling (Production)
```yaml
hikari:
  maximum-pool-size: 20
  minimum-idle: 5
  connection-timeout: 20000
  idle-timeout: 300000
  max-lifetime: 1200000
```

### Batch Processing
```yaml
hibernate:
  jdbc:
    batch_size: 20
  order_inserts: true
  order_updates: true
```

### Query Optimization
- Indexes on frequently queried columns (email_id)
- Prepared statements for security and performance
- Connection pooling for better resource utilization

---

## Monitoring & Observability

### Prometheus Metrics
```bash
curl http://localhost:8080/actuator/prometheus
```

### Custom Metrics
- Request count by endpoint
- Response time distribution
- Database query performance
- JVM metrics (memory, GC)

---

## Troubleshooting

### Connection Failed
```
Error: Cannot connect to PostgreSQL
Solution: Verify DB_HOST, DB_PORT, and credentials in .env
```

### Schema Mismatch
```
Error: Tables not found
Solution: Check application-prod.yml has ddl-auto: validate
         Use dev profile for automatic schema creation
```

### Port Already in Use
```bash
# Change port in application.yml
server.port: 8081
```

---

## Rollback Plan

If needed, to rollback to MySQL:

1. Revert pom.xml to use MySQL connector
2. Update application.yml dialect to MySQL8Dialect
3. Restore MySQL database dump
4. Rebuild and restart application

---

## Conclusion

✅ Successfully migrated from MySQL to PostgreSQL
✅ Implemented environment-specific configurations
✅ Added enterprise-grade logging and monitoring
✅ Containerized application for scalability
✅ Ready for Kubernetes deployment with health checks

**Next Steps:**
- Deploy to Kubernetes (AKS) using Terraform
- Set up CI/CD pipeline
- Configure monitoring with Prometheus/Grafana
- Implement database backup strategy
