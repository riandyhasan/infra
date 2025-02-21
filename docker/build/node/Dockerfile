# Stage 1: Build and install dependencies
FROM node:18-alpine AS builder

WORKDIR /app

# Install build dependencies (python/pip needed for some node-gyp modules)
RUN apk add --no-cache python3 make g++

# Copy package files
COPY package.json package-lock.json* ./

# Install dependencies (including devDependencies)
RUN npm ci --no-audit --prefer-offline

# Copy source code
COPY . .

# Build application (if needed for TypeScript, etc)
RUN npm run build --if-present

# Prune development dependencies
RUN npm prune --production

# Stage 2: Production image
FROM node:18-alpine

WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup

# Copy necessary files from builder
COPY --from=builder --chown=appuser:appgroup /app/node_modules ./node_modules
COPY --from=builder --chown=appuser:appgroup /app/package.json ./
# For TypeScript projects
COPY --from=builder --chown=appuser:appgroup /app/dist ./dist  
# COPY --from=builder --chown=appuser:appgroup /app .          # For JavaScript projects

# Environment variables
ENV NODE_ENV production
ENV PORT 3000

# Switch to non-root user
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
    CMD curl -f http://localhost:$PORT/health || exit 1

# Expose and run
EXPOSE $PORT
CMD ["node", "dist/index.js"]  # Adjust based on your entry point
# CMD ["npm", "start"]         # Alternative if using package.json scripts