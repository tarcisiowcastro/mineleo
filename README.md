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
  in-game (`/bichos` pros 18 animais da Animalia, `/monstros` pros monstros
  do Mobs Monster + dragões do Dmobs), invocando na frente do jogador. Exige
  a priv `give` (mesma exigida pelo `/spawnentity` nativo do Luanti), então
  só quem for admin usa por padrão.
- **[Crafting Guide Plus](https://content.luanti.org/packages/random_geek/cg_plus/)**
  (`cg_plus`) — no guia de crafting, clique num botão pra preencher a grade
  de crafting sozinho (1 unidade ou o máximo possível).
- **`tree_thinner`** (mod próprio deste repo, não é de terceiros) — remove
  ~60% dos troncos de árvore logo após o terreno ser gerado, deixando a
  floresta mais rala (só afeta terreno gerado depois que o mod entrou).
- **[Multidecor](https://content.luanti.org/packages/Andrey01/multidecor/)** —
  móveis estilo "casa de verdade" (cozinha, banheiro, quarto, sala): sofá,
  cama, banheira, vaso sanitário, armário, luminária, etc. Modpack com 3
  mods internos (`decor_api`, `craft_ingredients`, `modern`).
- **[Edit Skin](https://content.luanti.org/packages/Mr.%20Rar/edit_skin/)** —
  comando `/skin` abre uma tela pra montar a aparência do personagem.
- **[Automobiles Pack](https://content.luanti.org/packages/apercy/automobiles_pck/)** —
  carros dirigíveis (Beetle, Buggy, Coupe, DeLorean, Trans Am, moto, Vespa...).
  Fixado na release 0.68e via zip (não `git clone`), porque o HEAD atual do
  repo já exige Luanti 5.12+ e este servidor roda 5.6.1.
- **`river_flow`** (mod próprio deste repo, não é de terceiros) — aumenta o
  alcance de propagação da água de rio de 2 pra 8 blocos (o máximo que o
  engine permite; não existe "infinito" de verdade).
- **[Travelnet](https://content.luanti.org/packages/mt-mods/travelnet/)** (+
  dependência **[xcompat](https://content.luanti.org/packages/mt-mods/xcompat/)**) —
  portal entre dois pontos: crafta a caixa (vidro nas colunas laterais, aço +
  mese + aço no meio), clique direito pra nomear a estação e a rede, dá um
  soco pra atualizar a lista. Duas caixas com o mesmo nome de rede viram
  portal uma pra outra, nos dois sentidos.
- **[Mese Portals](https://content.luanti.org/packages/mt-historical/meseportals/)**
  (+ `meseportals_public`, mod próprio deste repo) — portal de verdade, tipo
  Nether: atravessa a pé, sem abrir menu. Configura o nome de rede pelo GUI
  do próprio portal pra linkar dois pontos. Por padrão o mod deixa o portal
  exclusivo de quem colocou; `meseportals_public` força todos a serem
  públicos (qualquer jogador atravessa).
- **`turbo_fly`** (mod próprio deste repo, não é de terceiros) — comando
  `/turbo` liga/desliga velocidade extra (x2.5) só pra quem usar o comando;
  não afeta ninguém que não digitar. Reseta sozinho a cada login.
- **[Mobs Monster](https://content.luanti.org/packages/TenPlus1/mobs_monster/)**
  (+ **[Mobs Redo](https://content.luanti.org/packages/TenPlus1/mobs/)**) —
  monstros clássicos com loot ao morrer (pedra, carvão, ferro, obsidiana,
  ouro, mese, diamante): stone monster, spider, mese monster, oerkki,
  dungeon master, tree monster, golem.
- **[Dmobs](https://content.luanti.org/packages/TenPlus1/dmobs/)** — 8 tipos
  de dragão (Minor, Fire, Lightning, Poison, Water, Ice, Great, Boss), soltam
  ovo de dragão. Não são fracos (bastante HP), mas como o dano tá desligado
  no servidor isso só significa luta mais longa, não risco de verdade.

Pra baixar/atualizar os mods:

```bash
./scripts/install-mods.sh
docker compose up -d --build
```

Os mods são ativados automaticamente no mundo pelo `entrypoint.sh` (roda a cada
start do container) — não precisa editar `world.mt` na mão.

## Texture pack

O servidor também envia um texture pack pra todo mundo que conectar (a não ser
que o jogador já tenha escolhido um pack próprio no cliente):

- **[SharpNet Photo Realism 64px](https://content.luanti.org/packages/Sharpik/sharpnet_textures/)** —
  reskin realista do jogo base (blocos, ferramentas). Não cobre os mods
  (Animalia, Multidecor, Unified Inventory continuam com a arte original).

Baixado pelo mesmo `scripts/install-mods.sh`, em `textures/sharpnet/`.

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
