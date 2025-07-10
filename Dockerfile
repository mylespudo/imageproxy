# syntax=docker/dockerfile:1.4

# Build stage
FROM --platform=$BUILDPLATFORM golang:1.21-alpine AS build

# Add metadata labels following Docker best practices
LABEL maintainer="Will Norris <will@willnorris.com>"
LABEL org.opencontainers.image.title="imageproxy"
LABEL org.opencontainers.image.description="A caching image proxy server written in Go"
LABEL org.opencontainers.image.url="https://github.com/mylespudo/imageproxy"
LABEL org.opencontainers.image.source="https://github.com/mylespudo/imageproxy"
LABEL org.opencontainers.image.version="latest"
LABEL org.opencontainers.image.licenses="Apache-2.0"

# Set working directory
WORKDIR /app

# Copy go mod files and download dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the application
ARG TARGETOS
ARG TARGETARCH
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -ldflags="-s -w" -o imageproxy ./cmd/imageproxy

# Runtime stage - use minimal alpine image for better compatibility
FROM alpine:3.18

# Install minimal runtime dependencies
RUN apk add --no-cache ca-certificates curl

# Copy binary from build stage
COPY --from=build /app/imageproxy /app/imageproxy

# Change ownership of the binary to nobody user
RUN chown nobody:nobody /app/imageproxy

# Switch to non-root user
USER nobody:nobody

# Set working directory
WORKDIR /app

# Expose port
EXPOSE 8080

# Add health check using curl
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8080/health-check || exit 1

# Set default command
CMD ["-addr", "0.0.0.0:8080"]
ENTRYPOINT ["/app/imageproxy"]
