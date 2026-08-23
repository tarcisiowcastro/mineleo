FROM golang:1.24-bookworm AS build

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /out/mineleo .

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /out/mineleo /app/mineleo
COPY config.example.toml /app/config.example.toml

VOLUME ["/app/world", "/app/resources"]
EXPOSE 19132/udp

ENTRYPOINT ["/app/mineleo"]
