# Build stage
FROM golang:alpine AS builder

WORKDIR /app
RUN apk add --no-cache git

COPY server/go.mod server/go.sum ./
RUN go mod download

COPY server/ ./
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o /app/server-bin ./cmd/api

# Final production image
FROM alpine:latest
RUN apk --no-cache add ca-certificates tzdata

WORKDIR /app
COPY --from=builder /app/server-bin /app/server-bin

EXPOSE 8080
ENV PORT=8080
ENV DB_PATH=/app/data/app.db

RUN mkdir -p /app/data

CMD ["/app/server-bin"]
