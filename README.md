# MineLeo

Servidor [Luanti](https://www.luanti.org/) (antigo Minetest) — 100%
open-source e gratuito, servidor e cliente.

## Rodando na VPS

```bash
git clone -b claude/mine-server-g8rzdh https://github.com/tarcisiowcastro/mineleo.git
cd mineleo
cp minetest.example.conf minetest.conf
docker compose up -d --build
docker compose logs -f
```

O servidor escuta na porta `30000/udp`. Libere no firewall se necessário:

```bash
ufw allow 30000/udp
```

Os diretórios `world/` e `mods/` são persistidos via volume no host.

## Cliente (celular/PC)

1. Baixe o app **Luanti** (gratuito):
   - Android: [Play Store](https://play.google.com/store/apps/details?id=net.minetest.minetest) ou [F-Droid](https://f-droid.org/packages/net.minetest.minetest/)
   - Windows/Linux/Mac: [luanti.org/downloads](https://www.luanti.org/downloads/)
2. Abra o app → **Join Game** (ou "Conectar a servidor").
3. Endereço: `143.95.219.182` — Porta: `30000`.

Diferente do Minecraft, o Luanti não tem lista pública de servidores
pré-carregada dentro do app — só entra quem tem o endereço configurado.

## Administração

Para virar admin, edite `minetest.conf`:

```
name = seu_nome_de_jogador
```

Reinicie o container; na primeira vez que logar com esse nome, defina a
senha pelo próprio jogo.

## Estrutura

- `Dockerfile` / `docker-compose.yml` — build e execução do servidor Luanti.
- `minetest.example.conf` — modelo de configuração.
- `kidlauncher/` — app Android que abre direto o cliente e trava o
  aparelho nele (kiosk mode).
- `world/`, `mods/` — dados do servidor (gerados automaticamente, ignorados
  pelo git).
