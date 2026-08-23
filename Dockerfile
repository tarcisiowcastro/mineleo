FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        luanti-server \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /luanti

VOLUME ["/luanti/world", "/luanti/mods"]
EXPOSE 30000/udp

ENTRYPOINT ["luantiserver", "--config", "/luanti/minetest.conf"]
