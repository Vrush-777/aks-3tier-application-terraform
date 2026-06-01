# Production-ready Multi-stage Dockerfile for React Frontend
# Stage 1: Build stage - Node build environment
FROM node:21-alpine AS node-builder

LABEL maintainer="Platform Engineering Team"
LABEL description="EMS Frontend - React UI Build Stage"

WORKDIR /build

# Install dependencies
COPY ems-fullstack/package*.json ./

# Clean npm cache and install production dependencies with optimizations
RUN npm ci --prefer-offline --no-audit

# Copy source code
COPY ems-fullstack/ .

# Build optimized production bundle with Vite
RUN npm run build

# Stage 2: Runtime stage - Nginx production server
FROM nginx:1.27-alpine

LABEL maintainer="Platform Engineering Team"
LABEL description="EMS Frontend - Nginx Production Server"

# Install curl for healthchecks
RUN apk add --no-cache curl

# Create non-root user for security
RUN addgroup -S www-user && adduser -S nginx-user -G www-user || true

# Remove default nginx config
RUN rm -f /etc/nginx/conf.d/default.conf

# Copy custom Nginx configuration for SPA routing
COPY ems-fullstack/nginx.conf /etc/nginx/conf.d/default.conf

# Copy built application from builder stage
COPY --from=node-builder /build/dist /usr/share/nginx/html

# Change ownership for security
RUN chown -R nginx-user:www-user /usr/share/nginx/html && \
    chown -R nginx-user:www-user /var/cache/nginx && \
    chown -R nginx-user:www-user /var/log/nginx && \
    chown -R nginx-user:www-user /etc/nginx/conf.d && \
    touch /var/run/nginx.pid && \
    chown -R nginx-user:www-user /var/run/nginx.pid

# Switch to non-root user
USER nginx-user

# Expose standard HTTP port
EXPOSE 80

# Health check for container orchestration
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost/index.html || exit 1

# Run Nginx in foreground mode (PID 1 for proper signal handling)
CMD ["nginx", "-g", "daemon off;"]
