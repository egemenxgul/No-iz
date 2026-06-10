FROM golang:alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/bin/iz-server cmd/server/main.go

FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/bin/iz-server .
COPY --from=builder /app/migrations ./migrations

EXPOSE 8080
CMD ["./iz-server"]
