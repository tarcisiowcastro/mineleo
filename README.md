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

## Estrutura

- `main.go` — ponto de entrada do servidor.
- `config.example.toml` — modelo de configuração.
- `world/` — dados do mundo (gerado automaticamente, ignorado pelo git).
