# MineLeo

Servidor Minecraft Bedrock escrito em Go, usando a biblioteca [Dragonfly](https://github.com/df-mc/dragonfly).

## Requisitos

- Go 1.21 ou superior

## Configuração

1. Copie o arquivo de configuração de exemplo:

   ```bash
   cp config.example.toml config.toml
   ```

2. Ajuste `config.toml` conforme necessário (endereço, nome do mundo, número máximo de jogadores, etc).

## Executando

```bash
go mod tidy
go run main.go
```

O servidor abrirá por padrão na porta `19132/udp`, usada pelo protocolo do Minecraft Bedrock Edition.

## Rodando com Docker

1. Na VPS, clone o repositório e entre na pasta:

   ```bash
   git clone -b claude/mine-server-g8rzdh https://github.com/tarcisiowcastro/mineleo.git
   cd mineleo
   ```

2. Crie o `config.toml` a partir do exemplo:

   ```bash
   cp config.example.toml config.toml
   ```

3. Suba o container:

   ```bash
   docker compose up -d --build
   ```

4. Acompanhe os logs:

   ```bash
   docker compose logs -f
   ```

O servidor ficará exposto na porta `19132/udp`. Os diretórios `world/` e `resources/` são persistidos via volume no host.

## Estrutura

- `main.go` — ponto de entrada do servidor.
- `config.example.toml` — modelo de configuração.
- `world/` — dados do mundo (gerado automaticamente, ignorado pelo git).
