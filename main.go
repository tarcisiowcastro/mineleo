package main

import (
	"os"

	"github.com/df-mc/dragonfly/server"
	"github.com/df-mc/dragonfly/server/player"
	"github.com/df-mc/dragonfly/server/player/chat"
	"github.com/sirupsen/logrus"
)

func main() {
	log := logrus.New()
	log.Formatter = &logrus.TextFormatter{ForceColors: true}
	log.Level = logrus.InfoLevel

	conf, err := readConfig(log)
	if err != nil {
		log.Fatalln(err)
	}

	srv := conf.New()
	srv.CloseOnProgramEnd()

	chat.Global.Subscribe(chat.StdoutSubscriber{})

	srv.Listen()
	for srv.Accept(func(p *player.Player) {
		p.Message("Bem-vindo ao servidor MineLeo!")
	}) {
	}
}

// readConfig lê o config.toml (ou cria um a partir do exemplo, se não existir)
// e retorna a configuração pronta para o Dragonfly.
func readConfig(log server.Logger) (server.Config, error) {
	c := server.DefaultConfig()
	if _, err := os.Stat("config.toml"); os.IsNotExist(err) {
		data, err := os.ReadFile("config.example.toml")
		if err != nil {
			return server.Config{}, err
		}
		if err := os.WriteFile("config.toml", data, 0644); err != nil {
			return server.Config{}, err
		}
	}
	return c.Config(log)
}
