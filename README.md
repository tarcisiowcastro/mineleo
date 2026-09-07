# MineLeo

Servidor [Luanti](https://www.luanti.org/) (antigo Minetest) — 100%
open-source e gratuito, servidor e cliente.

## Rodando na VPS

```bash
git clone -b claude/mine-server-g8rzdh https://github.com/tarcisiowcastro/mineleo.git
cd mineleo
cp minetest.example.conf minetest.conf
./scripts/install-mods.sh
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

## Mods instalados

O servidor vem com mods de animais e barco, buscados via `scripts/install-mods.sh`:

- **[Animalia](https://content.luanti.org/packages/ElCeejo/animalia/)** (+ dependência
  **[Creatura](https://content.luanti.org/packages/ElCeejo/creatura/)**) — animais com
  comportamento (cavalo montável, lobo/gato/raposa domesticáveis, reprodução).
- **[Motorboat](https://content.luanti.org/packages/apercy/motorboat/)** (+ dependências
  **[mobkit](https://content.luanti.org/packages/mt-mods/mobkit/)** e
  **[biofuel](https://content.luanti.org/packages/Lokrates/biofuel/)**) — barco a motor.
- **[Privileges Manager](https://content.luanti.org/packages/Impulse/priviledges_manager/)** —
  painel in-game (`/privman`) com toggle pra cada privilégio (`fly`, `fast`, `noclip`,
  `teleport`...) de qualquer jogador. Exige a priv `privs`, que só quem estiver
  configurado como admin (ver seção "Administração") tem por padrão.
- **[Unified Inventory](https://content.luanti.org/packages/RealBadAngel/unified_inventory/)** —
  substitui o inventário criativo padrão por um com busca por nome (inclui os
  itens do Motorboat: procure "hull" e "engine").
- **`mob_spawn_panel`** (mod próprio deste repo, não é de terceiros) — painel
  in-game (`/bichos`) com um botão pra cada um dos 18 animais da Animalia,
  invocando na frente do jogador. Exige a priv `give` (mesma exigida pelo
  `/spawnentity` nativo do Luanti), então só quem for admin usa por padrão.

Pra baixar/atualizar os mods:

```bash
./scripts/install-mods.sh
docker compose up -d --build
```

Os mods são ativados automaticamente no mundo pelo `entrypoint.sh` (roda a cada
start do container) — não precisa editar `world.mt` na mão.

## Estrutura

- `Dockerfile` / `docker-compose.yml` — build e execução do servidor Luanti.
- `entrypoint.sh` — ativa os mods instalados no `world.mt` e sobe o `minetestserver`.
- `scripts/install-mods.sh` — clona/atualiza os mods de terceiros em `mods/`.
- `mods/mob_spawn_panel/` — único mod próprio (versionado no git, ao contrário
  dos demais em `mods/`, que são de terceiros e ignorados).
- `minetest.example.conf` — modelo de configuração.
- `kidlauncher/` — app Android que abre direto o cliente e trava o
  aparelho nele (kiosk mode).
- `world/`, `mods/` — dados do servidor (gerados/baixados automaticamente,
  ignorados pelo git).
