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
- **[Privileges Manager](https://content.luanti.org/packages/Impulse/priviledges_manager/)** —
  painel in-game (`/privman`) com toggle pra cada privilégio (`fly`, `fast`, `noclip`,
  `teleport`...) de qualquer jogador. Exige a priv `privs`, que só quem estiver
  configurado como admin (ver seção "Administração") tem por padrão.
- **[Unified Inventory](https://content.luanti.org/packages/RealBadAngel/unified_inventory/)** —
  substitui o inventário criativo padrão por um com busca por nome.
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
- **[Visual Harm 1Ndicators](https://content.luanti.org/packages/Mantar/visual_harm_1ndicators/)** —
  barra de vida (verde→vermelho) acima de qualquer mob do Mobs Redo
  (monstros, dragões), automático, sem configurar nada.
- **[WorldEdit](https://content.luanti.org/packages/sfan5/worldedit/)** —
  ferramenta de terraformar em massa via comando `//`. Não tem um comando
  "flatten" pronto, mas dá pra achatar uma área inteira em duas passadas:
  1. Marca dois cantos da área, um bem embaixo e outro bem em cima (acima de
     qualquer morro): `//pos1` (no canto A, no fundo) e `//pos2` (no canto B,
     no alto), depois `//set air` — limpa tudo (morro, árvore) naquele volume.
  2. Marca de novo do fundo até a altura que você quer de chão:
     `//pos1`/`//pos2` nessa faixa mais baixa, depois `//set dirt_with_grass`
     (ou outro bloco) — preenche o chão sólido nessa altura.
  Exige a priv `worldedit`; se `//pos1` der "sem permissão", concede pelo
  `/privman`. **Cuidado com o tamanho**: 300x300 com bastante altura passa
  fácil de milhões de blocos num `//set` só, o que trava o servidor por um
  tempo — recomendo fazer em pedaços menores (tipo 100x100) em vez de tudo
  de uma vez.
- **[Steampunk Blimp](https://content.luanti.org/packages/apercy/steampunk_blimp/)**
  (+ **[AirUtils](https://content.luanti.org/packages/apercy/airutils/)**) —
  dirigível a vapor, carrega até 7 pessoas. Combustível (carvão/madeira) +
  água na caldeira; suba com `Espaço`, desça segurando `Shift`, acelera
  andando pra frente. Fixado na release 0.47 via zip (não `git clone`),
  porque o HEAD atual do repo já exige Luanti 5.9+ e este servidor roda
  5.6.1.
- **[WW1 Planes](https://content.luanti.org/packages/apercy/ww1_planes/)**
  (+ AirUtils) — dois aviões pilotáveis (Albatros D5, Sopwith F1 Camel).
  **`math_isfinite_polyfill`** (mod próprio deste repo) corrige um crash
  real do AirUtils (`math.isfinite` não existe no Lua do Minetest) que
  travava o servidor em loop toda vez que um avião existia no mundo.
- **[Discovery Maps](https://content.luanti.org/packages/TomCon/discovery_maps/)** —
  mapa em tela cheia com névoa de guerra (só mostra onde já foi explorado),
  marcadores e waypoints.
- **[Elevator](https://content.luanti.org/packages/shacknetisp/elevator/)** —
  elevador de verdade (sobe/desce visível, não é teleporte instantâneo).
- **[Advtrains](https://content.luanti.org/packages/orwell/advtrains/)** +
  **[Advtrains Freight Train](https://content.luanti.org/packages/advtrains_supplemental/advtrains_freight_train/)** —
  trilhos + 4 vagões de carga (dobro de espaço, mais lentos) e uma
  locomotiva a diesel. Só o essencial pra ter trem funcionando (trilho +
  vagão); os pacotes de sinalização/automação do Advtrains ficaram de fora
  por enquanto — dá pra adicionar depois se quiser.

- **[Working Villages](https://content.luanti.org/packages/theFox/working_villages/)** —
  NPCs que moram no mundo e trabalham sozinhos (fazenda, lenhador,
  construção), com rotina que muda ao longo do dia. Modpack com
  `working_villagers` (o mod em si, já traz `modutil` embutido como
  submodule) e `building_sign` (proteção de área + placas de construção,
  descrito pelo próprio autor como "inacabado").
  Depende só de `default` (parte do Minetest Game, já vem no pacote
  `minetest-server` da imagem base). Opcionais pra funcionalidade completa:
  `doors` e `beds` (também vêm no Minetest Game — não precisou instalar à
  parte) e **[Areas](https://github.com/minetest-mods/areas)** (`areas`,
  instalado à parte via `install-mods.sh`) — sem `areas`, o `building_sign`
  perde a parte de proteção de território, mas os NPCs de trabalho
  continuam funcionando normalmente.
  ⚠️ **Manutenção listada como "desconhecida"** na ContentDB e há reviews de
  crash (lenhador cortando árvore, placa de construção) e de bugs que
  pioram combinados com outros mods de mob — aqui já rodamos
  creatura/animalia/dmobs/mobs_monster. Testado num mundo local antes de
  subir pra VPS; se der problema em produção, `rm -rf mods/working_villages
  mods/areas` e remover as linhas correspondentes de `world.mt` reverte sem
  afetar os demais mods.
- **[Villages (mg_villages)](https://content.luanti.org/packages/Sokomine/mg_villages/)**
  (+ dependência **[handle_schematics](https://github.com/Sokomine/handle_schematics)**) —
  gera vilas de verdade (casas, ruas) no terreno, complementando o Working
  Villages (que só dá os NPCs que andam pelo mapa, sem construir nada).
  Comandos in-game: `/villages` lista as vilas já geradas nesta sessão,
  `/visit <número>` teleporta direto pra uma delas.
  ⚠️ **Só gera vila em terreno ainda não explorado** — o mod decide na hora
  em que o chunk é gerado pela primeira vez, então a área que já foi
  visitada/construída no mineleo não ganha vila retroativamente. Pra ver
  uma, é preciso ir (voar) pra fora da área já mapeada; dali em diante,
  qualquer terreno novo tem chance de ter uma.
- **`village_populate`** (mod próprio deste repo, não é de terceiros) — o
  mg_villages já calcula nome, cama e ocupação de cada morador de cada casa
  gerada, mas nunca materializa isso num NPC visível (ele exige um mod de
  integração "mob_world_interaction" que não existe compatível com os mobs
  que já rodamos aqui). Esse mod lê os mesmos dados e spawna um NPC do
  Working Villages em cada cama, com o nome/título do morador como nametag.
  Roda sozinho: uma passada ~30s depois do servidor subir (pega as vilas que
  já existiam antes desse mod) e depois a cada 5 minutos (pega vila nova
  conforme o mg_villages gera). Idempotente — não duplica morador numa vila
  já povoada, mesmo reiniciando o servidor. Comando manual pra forçar uma
  passada na hora: `/povoar_vilas` (priv `server`).
- **[Mobs Animal](https://codeberg.org/tenplus1/mobs_animal)** — animais de
  fazenda (vaca, ovelha, galinha, coelho, gato) usando o mesmo motor Mobs
  Redo do Mobs Monster/Dmobs já instalados aqui; spawna sozinho pelo mapa
  todo, sem precisar de vila.
- **`no_lava`** (mod próprio deste repo, não é de terceiros) — remove toda
  a lava do servidor: terreno novo já nasce sem lava (apagada logo depois
  de gerado), a lava que já existia no mundo some sozinha na hora em que
  aquele trecho carrega (quando alguém chega perto), e qualquer lava
  colocada depois (balde, WorldEdit, `/setnode`) se desfaz na hora. O balde
  de lava também sai do inventário criativo. Onde tinha lava vira ar
  (buraco/caverna vazia).

⚠️ **Não instalado**: o mod `mg` (mapgen experimental do Nore) tem aviso do
próprio autor pra não usar em mundo já existente — como o nosso já tem muita
coisa construída, pular esse foi o mais seguro.

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
- `mods/mob_spawn_panel/`, `mods/tree_thinner/`, `mods/river_flow/`,
  `mods/turbo_fly/`, `mods/no_lava/` — mods próprios (versionados no git, ao contrário dos
  demais em `mods/`, que são de terceiros e ignorados).
- `minetest.example.conf` — modelo de configuração.
- `kidlauncher/` — app Android que abre direto o cliente e trava o
  aparelho nele (kiosk mode).
- `world/`, `mods/` — dados do servidor (gerados/baixados automaticamente,
  ignorados pelo git).
