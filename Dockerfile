FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        minetest-server \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /luanti

VOLUME ["/luanti/world", "/luanti/mods"]
EXPOSE 30000/udp

ENTRYPOINT ["minetestserver", "--config", "/luanti/minetest.conf"]
