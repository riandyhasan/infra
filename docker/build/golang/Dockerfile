# Build stage
FROM golang:1.21-alpine AS builder

# Set working directory
WORKDIR /app

# Install dependencies required for build
RUN apk add --no-cache git ca-certificates

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s" \
    -o /app/bin/main .

# Final stage
FROM alpine:3.19

# Install SSL certificates (needed for HTTPS requests)
RUN apk --no-cache add ca-certificates

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Set working directory
WORKDIR /app

# Copy binary from builder
COPY --from=builder --chown=appuser:appgroup /app/bin/main /app/main

# Switch to non-root user
USER appuser

# Expose port (adjust according to your application)
EXPOSE 8080

# Command to run the application
ENTRYPOINT ["/app/main"]