# Stage 1: Build application
FROM node:18-alpine AS builder

WORKDIR /app

# Install dependencies first for better caching
COPY package.json package-lock.json* ./
RUN npm ci --no-audit --prefer-offline

# Copy source files
COPY . .

# Build application
RUN npm run build

# Prune development dependencies
RUN npm prune --production

# Stage 2: Production image
FROM node:18-alpine

WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001 -G nodejs

# Copy necessary files from builder
COPY --from=builder --chown=nextjs:nodejs /app/package.json /app/package-lock.json ./
COPY --from=builder --chown=nextjs:nodejs /app/.next ./.next
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/node_modules ./node_modules

# Environment variables
ENV NODE_ENV production
ENV NEXT_TELEMETRY_DISABLED 1

# Switch to non-root user
USER nextjs

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
    CMD curl -f http://localhost:3000/api/health || exit 1

# Expose and run
EXPOSE 3000
CMD ["npm", "start"]