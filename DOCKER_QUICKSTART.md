# 🚀 Quick Start - EMS Application with Docker

Get the Employee Management System up and running in 5 minutes!

## Prerequisites
- Docker Desktop installed ([download](https://www.docker.com/products/docker-desktop))
- 4GB+ RAM available
- Ports 80, 8080, 5432 available

## Quick Start (5 Steps)

### 1. Clone/Prepare Repository
```bash
cd aks-3tier-application-terraform
```

### 2. Create Environment File
```bash
cp .env.example .env
# Default values work for development - no changes needed!
```

### 3. Start All Services
```bash
docker-compose up -d
```

### 4. Wait for Services (30-60 seconds)
```bash
# Watch startup progress
docker-compose logs -f

# Exit when you see "healthy" for all services
# Press Ctrl+C to exit logs view
```

### 5. Access Application
- **Frontend**: http://localhost
- **Backend API**: http://localhost:8080/api/employees
- **Health Check**: http://localhost:8080/actuator/health

## Verify Everything Works
```bash
# Check all services are running
docker-compose ps

# Expected output: All containers should show "Up (healthy)"
```

## Common Commands

```bash
# View logs
docker-compose logs -f

# Stop services
docker-compose stop

# Start services again
docker-compose start

# Complete restart
docker-compose restart

# Remove everything
docker-compose down -v

# Rebuild after code changes
docker-compose build
docker-compose up -d
```

## Test API

### List employees
```bash
curl http://localhost/api/employees
```

### Add employee
```bash
curl -X POST http://localhost/api/employees \
  -H "Content-Type: application/json" \
  -d '{"firstName":"John","lastName":"Doe","emailId":"[REDACTED_EMAIL_ADDRESS_1]"}'
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Port already in use | Change port in `.env` (e.g., `BACKEND_PORT=8081`) |
| Containers won't start | Check logs: `docker-compose logs` |
| Cannot connect to backend | Wait longer for startup (~60s) or check: `docker-compose ps` |
| Database connection error | Verify `DB_[REDACTED_GENERIC_PASSWORD_1]` in `.env` |

## Next Steps
- Read [DOCKER_GUIDE.md](./DOCKER_GUIDE.md) for complete documentation
- Review [docker-compose.yml](./docker-compose.yml) for architecture
- Check [.env.example](./.env.example) for configuration options

## Architecture
```
Browser (http://localhost)
    ↓
Nginx Frontend (Port 80)
    ↓
Spring Boot API (Port 8080)
    ↓
PostgreSQL Database (Port 5432)
```

**That's it! 🎉 Your EMS application is now running!**

---
For more details, see [DOCKER_GUIDE.md](./DOCKER_GUIDE.md)
