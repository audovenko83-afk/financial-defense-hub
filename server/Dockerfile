# Build stage
FROM golang:1.24-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache git

COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Build statically linked binary
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o /app/server-bin ./cmd/api

# Final minimal production image
FROM alpine:latest

RUN apk --no-cache add ca-certificates tzdata

WORKDIR /app

# Copy binary from builder
COPY --from=builder /app/server-bin /app/server-bin

# Expose default port
EXPOSE 8080

ENV PORT=8080
ENV DB_PATH=/app/data/app.db

# Ensure data directory exists for SQLite
RUN mkdir -p /app/data

CMD ["/app/server-bin"]
