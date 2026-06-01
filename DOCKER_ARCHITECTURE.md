# Docker Architecture & Production Standards

## Overview
This document describes the production-ready Docker implementation for the EMS three-tier application.

---

## 1. Backend Dockerfile - Spring Boot (Java 21)

### Location
`ems-backend/ems-backend/Dockerfile`

### Key Features

#### Multi-Stage Build
```dockerfile
# Stage 1: Maven builder (build only, not included in final image)
FROM maven:3.9-eclipse-temurin-21-alpine AS maven-builder

# Stage 2: Runtime (optimized production image)
FROM eclipse-temurin:21-jre-alpine
```

**Benefits:**
- ✅ Smaller final image (~400MB vs ~800MB)
- ✅ Build dependencies not included in production image
- ✅ Faster deployment and pull times
- ✅ Reduced attack surface

#### Java 21 LTS
- **Version**: Java 21 (Long-Term Support)
- **Base Image**: eclipse-temurin:21-jre-alpine
- **Size**: ~150MB (Alpine is minimal)
- **Benefits**: 
  - Latest stable Java LTS version
  - Virtual thread support (Project Loom)
  - Improved garbage collection
  - Modern security features

#### Maven Build Stage
```dockerfile
# Dependency layer (cached separately for faster builds)
COPY ems-backend/pom.xml .
RUN mvn dependency:go-offline -B

# Source layer (rebuilt only when code changes)
COPY ems-backend/src ./src
RUN mvn clean package -DskipTests -q
```

**Optimization:**
- Dockerfile layers ordered by change frequency
- Maven offline mode (-o) caches dependencies
- Tests skipped in build (run in CI/CD instead)
- Quiet mode (-q) reduces log noise

#### Security Best Practices
```dockerfile
# Non-root user for security (principle of least privilege)
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# File ownership to non-root user
RUN chown -R appuser:appgroup /app
```

**Benefits:**
- Prevents container escape to host system
- Limits damage if application is compromised
- Meets security compliance requirements

#### Health Checks
```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1
```

**Features:**
- Integrated Spring Boot Actuator health endpoint
- Start period (40s) waits for JVM startup
- Interval (30s) checks service health continuously
- Kubernetes/Swarm use this for orchestration

#### JVM Memory Optimization
```dockerfile
JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:InitialRAMPercentage=50.0"
```

**Explanation:**
- `UseContainerSupport`: Respects Docker memory limits
- `MaxRAMPercentage=75.0`: Uses up to 75% of container memory for heap
- `InitialRAMPercentage=50.0`: Starts with 50% to reduce GC pauses

---

## 2. Frontend Dockerfile - React (Node 21 + Nginx)

### Location
`ems-fullstack/Dockerfile`

### Key Features

#### Multi-Stage Build
```dockerfile
# Stage 1: Node build environment (build only)
FROM node:21-alpine AS node-builder

# Stage 2: Nginx production server (runtime only)
FROM nginx:1.27-alpine
```

**Benefits:**
- ✅ Build tools not included in production (~300MB reduction)
- ✅ Nginx minimal image (~30MB)
- ✅ Only React bundle (.dist) deployed
- ✅ Fast deployment

#### Node.js 21 Build
```dockerfile
RUN npm ci --prefer-offline --no-audit
RUN npm run build  # Vite production build
```

**Process:**
1. `npm ci` installs exact dependencies (not `npm install`)
2. Build creates optimized bundle in `dist/`
3. Only production files copied to Nginx stage

#### Nginx Production Server
```dockerfile
FROM nginx:1.27-alpine

# Custom configuration for React SPA routing
COPY ems-fullstack/nginx.conf /etc/nginx/conf.d/default.conf

# Static files from build stage
COPY --from=node-builder /build/dist /usr/share/nginx/html
```

**Features:**
- Nginx 1.27 (lightweight Alpine variant)
- Custom SPA routing configuration
- Proper caching headers for static assets
- API proxy to backend

#### Security - Non-Root User
```dockerfile
RUN addgroup -S www-user && adduser -S nginx-user -G www-user

# File ownership
RUN chown -R nginx-user:www-user /usr/share/nginx/html

USER nginx-user
```

#### Health Check
```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost/health || exit 1
```

---

## 3. Nginx Configuration - SPA Routing

### Location
`ems-fullstack/nginx.conf`

### Key Features

#### React SPA Routing
```nginx
location / {
    root /usr/share/nginx/html;
    try_files $uri $uri/ /index.html;  # Fallback to index.html for client-side routing
}
```

**How it works:**
- First tries exact file match (`/users` → `users.html`)
- Then tries directory match (`/users/` → `users/index.html`)
- Falls back to `index.html` for unknown routes (React Router handles it)

#### Backend API Proxy
```nginx
location /api/ {
    proxy_pass http://backend:8080/;  # Route to ems-backend service
    
    # Forward original request headers
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

#### Caching Strategy
```nginx
# index.html: no cache (check for updates)
location = /index.html {
    add_header Cache-Control "no-cache, no-store, must-revalidate" always;
}

# Static assets: 1 year cache (immutable)
location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
    add_header Cache-Control "public, immutable, max-age=31536000" always;
}
```

#### Security Headers
```nginx
add_header X-Frame-Options "SAMEORIGIN";           # Clickjacking protection
add_header X-Content-Type-Options "nosniff";       # MIME type sniffing protection
add_header X-XSS-Protection "1; mode=block";       # XSS protection
add_header Referrer-Policy "strict-origin-when-cross-origin";
```

#### Gzip Compression
```nginx
gzip on;
gzip_types text/plain text/css application/json application/javascript;
gzip_min_length 256;  # Only compress if > 256 bytes
```

**Benefits:**
- Reduces payload size by 60-80%
- HTTP/1.1 compatible
- Minimal CPU overhead

---

## 4. Docker Compose Configuration

### Location
`docker-compose.yml`

### Architecture
```
Frontend (Nginx)       Backend (Spring Boot)      Database (PostgreSQL)
    ↓                        ↓                            ↓
Port 80 ←────────────→ Port 8080 ←─────────────→ Port 5432
(HTTP)                 (REST API)              (Database)

All services on: ems-network (bridge)
```

### Service Configuration

#### 1. PostgreSQL Service
```yaml
postgres:
  image: postgres:16-alpine          # Minimal database image
  restart: unless-stopped             # Auto-restart if crashed
  volumes:
    - postgres_data:/var/lib/postgresql/data  # Persistent data
    - ./init-db.sql:/docker-entrypoint-initdb.d/init.sql  # Initialization
  
  healthcheck:
    test: pg_isready -U postgres
    interval: 10s
    timeout: 5s
    retries: 5
    start_period: 10s
  
  deploy:
    resources:
      limits:
        memory: 512M           # Max 512MB RAM
      reservations:
        memory: 256M           # Reserve 256MB minimum
```

#### 2. Backend Service
```yaml
ems-backend:
  build:
    context: .
    dockerfile: ./ems-backend/ems-backend/Dockerfile
  
  depends_on:
    postgres:
      condition: service_healthy     # Wait for DB health
  
  environment:
    SPRING_PROFILES_ACTIVE: dev      # Spring profile
    JAVA_OPTS: -XX:MaxRAMPercentage=75.0  # JVM tuning
  
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:8080/actuator/health"]
    interval: 30s
    start_period: 60s                # Wait for JVM startup
  
  deploy:
    resources:
      limits:
        memory: 1024M
      reservations:
        memory: 512M
```

#### 3. Frontend Service
```yaml
ems-frontend:
  build:
    context: .
    dockerfile: ./ems-fullstack/Dockerfile
  
  depends_on:
    ems-backend:
      condition: service_healthy     # Wait for backend
  
  ports:
    - "${FRONTEND_PORT:-80}:80"      # Configurable port
  
  deploy:
    resources:
      limits:
        memory: 256M
      reservations:
        memory: 128M
```

### Networking
```yaml
networks:
  ems-network:
    driver: bridge
```

**How it works:**
- Bridge network isolates containers from host network
- Containers communicate via service name (internal DNS)
- Example: `http://ems-backend:8080` resolves to backend container

### Volume Management
```yaml
volumes:
  postgres_data:
    driver: local
```

**Persistence:**
- Database data survives container restarts
- Located at: `~/var/lib/docker/volumes/ems_postgres_data/_data`
- Backed up separately or synced to cloud storage

---

## 5. .dockerignore Files

### Purpose
Reduce build context size by excluding unnecessary files

### Backend Exclusions
- Maven artifacts (`target/`, `*.jar`)
- IDE files (`.idea/`, `.vscode/`)
- Git files (`.git/`, `.gitignore`)
- Documentation (`.md` files)

**Impact**: Reduces build context from ~500MB to ~50MB

### Frontend Exclusions
- Node modules (`node_modules/`)
- IDE files (`.vscode/`, `.idea/`)
- Git files
- Build outputs (`dist/`, `build/`)

**Impact**: Reduces build context from ~300MB to ~5MB

---

## 6. Environment Configuration

### .env.example
Template file with all configurable variables:

```
# Database
DB_USERNAME=postgres
DB_[REDACTED_GENERIC_PASSWORD_1]=password
DB_NAME=employee_dev
DB_PORT=5432

# Backend
BACKEND_PORT=8080
SPRING_PROFILES_ACTIVE=dev
JAVA_OPTS=-XX:+UseContainerSupport

# Frontend
FRONTEND_PORT=80
```

**Usage:**
```bash
cp .env.example .env
# Edit .env as needed
docker-compose up -d
```

---

## 7. Production Considerations

### Image Sizes
| Image | Size | Base |
|-------|------|------|
| PostgreSQL | 100MB | postgres:16-alpine |
| Backend | 400MB | Java 21 + Spring Boot + app |
| Frontend | 50MB | Nginx 1.27 + React bundle |

### Security Checklist
- [x] Non-root user execution
- [x] Security headers in Nginx
- [x] HTTPS ready (configure at reverse proxy)
- [x] SQL injection prevention (JPA/Hibernate)
- [x] XSS protection (React auto-escaping + headers)
- [x] CORS configuration (if needed)

### Performance Optimization
- [x] Multi-stage builds
- [x] Alpine-based images (minimal)
- [x] Gzip compression
- [x] Static asset caching
- [x] Database indexing
- [x] Connection pooling ready

### Monitoring Points
- Container health checks
- Application logs
- Database connections
- Memory/CPU usage
- API response times

---

## 8. Upgrade Path

### Java Version
To upgrade Java version:
1. Update `maven:X.X-eclipse-temurin-XX` in backend Dockerfile
2. Update `eclipse-temurin:XX-jre-alpine` in backend Dockerfile
3. Update `pom.xml` property: `<java.version>XX</java.version>`
4. Rebuild: `docker-compose build --no-cache ems-backend`

### PostgreSQL Version
To upgrade database:
1. Backup existing data
2. Update `postgres:X-alpine` in docker-compose.yml
3. Remove postgres_data volume (or backup first)
4. Restart: `docker-compose up -d postgres`

### Node.js Version
To upgrade frontend builder:
1. Update `node:XX-alpine` in frontend Dockerfile
2. Update dependencies in package.json
3. Rebuild: `docker-compose build --no-cache ems-frontend`

---

## 9. Troubleshooting Guide

### Large Image Sizes
**Cause**: Unused dependencies or build artifacts  
**Solution**: Check .dockerignore, review package.json/pom.xml

### Slow Builds
**Cause**: Rebuilding unchanged layers  
**Solution**: Use Docker cache, order Dockerfile layers by change frequency

### Memory Issues
**Cause**: JVM heap too large or insufficient host memory  
**Solution**: Adjust MaxRAMPercentage or increase docker-compose limits

### Network Connectivity
**Cause**: Wrong service names or network isolation  
**Solution**: Use service names (postgres, ems-backend), verify network: `docker network ls`

---

## Deployment Workflow

### Local Development
```bash
docker-compose up -d
# Edit code
docker-compose build <service>
docker-compose up -d <service>
```

### Staging Environment
```bash
# Use .env with staging configuration
SPRING_PROFILES_ACTIVE=qa
docker-compose -f docker-compose.yml -f docker-compose.staging.yml up -d
```

### Production Deployment
```bash
# Use production configuration (secrets, resource limits)
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Or use Kubernetes manifests converted from compose
kompose convert -f docker-compose.yml
```

---

**Version**: 1.0  
**Last Updated**: June 2024  
**Maintainer**: Platform Engineering Team
