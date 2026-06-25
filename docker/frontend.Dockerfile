# Production-ready Multi-stage Dockerfile for React Frontend
# Stage 1: Build stage - Node build environment
FROM node:22-alpine AS node-builder

LABEL maintainer="Platform Engineering Team"
LABEL description="EMS Frontend - React UI Build Stage"

WORKDIR /build

# Install dependencies
COPY package*.json ./

# Clean npm cache and install production dependencies with optimizations
RUN npm ci --prefer-offline --no-audit

# Copy source code
COPY . .

# Build optimized production bundle with Vite
RUN npm run build

# Stage 2: Runtime stage - Nginx production server
FROM nginx:1.27-alpine

RUN apk add --no-cache curl

RUN rm -f /etc/nginx/conf.d/default.conf

COPY nginx.conf /etc/nginx/conf.d/default.conf

COPY --from=node-builder /build/dist /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s \
CMD curl -f http://localhost/health || exit 1

CMD ["nginx","-g","daemon off;"]
