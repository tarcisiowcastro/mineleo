FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        minetest-server \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /luanti

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

VOLUME ["/luanti/world", "/luanti/mods"]
EXPOSE 30000/udp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
