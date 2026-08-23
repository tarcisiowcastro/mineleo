# MineLeo Kiosk Launcher

App Android original (não é o Minecraft, não modifica o Minecraft) que:

1. Abre o Minecraft (Bedrock) automaticamente ao ligar/tocar no ícone.
2. Se instalado como **dono do dispositivo** (device owner), trava a tela
   nesse app + no Minecraft (Lock Task Mode) — sem home, sem recentes, sem
   trocar de app, até desativar via ADB.
3. Sem device owner, ele só abre o Minecraft; você pode travar manualmente
   com o "Pin de app" nativo do Android (veja abaixo).

Combine com o bloqueio de firewall na sua VPS (só a porta 19132 do seu IP
liberada) para que, mesmo se a criança visse outro servidor na lista, a
conexão simplesmente não funcionaria.

## Como compilar

### Opção A: GitHub Actions (recomendado, sem precisar instalar nada)

O workflow `.github/workflows/kidlauncher-apk.yml` já compila o APK a cada
push que toque na pasta `kidlauncher/`. Depois do push:

1. Vá em **Actions** no repositório GitHub.
2. Abra a execução mais recente de "Build kidlauncher APK".
3. Baixe o artefato `kidlauncher-debug-apk` — é o `.apk` pronto.

### Opção B: Localmente com Android Studio

1. Abra a pasta `kidlauncher/` no Android Studio.
2. Build > Build APK(s).
3. O APK sai em `app/build/outputs/apk/debug/app-debug.apk`.

## Instalando no aparelho da criança

```bash
adb install -r app-debug.apk
```

## Modo 1 — Kiosk completo (recomendado, requer dispositivo "zerado")

Isso exige que o app seja o **dono do dispositivo**, o que só funciona em um
aparelho sem nenhuma conta Google configurada (ou logo após um reset de
fábrica, antes de adicionar contas):

```bash
adb shell dpm set-device-owner com.mineleo.kidlauncher/.KioskDeviceAdminReceiver
```

Depois disso, defina o MineLeo Kiosk como launcher padrão (tela inicial) do
aparelho, nas configurações de "App padrão > Aplicativo inicial".

Para desativar depois (ex.: emprestar o aparelho, resetar):

```bash
adb shell dpm remove-active-admin com.mineleo.kidlauncher/.KioskDeviceAdminReceiver
```

## Modo 2 — Sem device owner (aparelho já em uso)

1. Instale o app e abra-o uma vez (ele já abre o Minecraft).
2. Nas Configurações do Android: **Segurança > Avançado > Fixar app**
   (ou "App pinning"), ative a opção.
3. Vá para os apps recentes, toque no ícone do Minecraft no topo do card e
   escolha **Fixar**.
4. Agora o aparelho fica travado só no Minecraft até alguém desbloquear com
   PIN/senha/padrão (segure Voltar + Visão geral, ou deslize conforme o
   Android pedir).

## Limitações

- Isso não remove a lista de servidores públicos de dentro do Minecraft —
  só impede a criança de sair do app/trocar de servidor com sucesso, se
  combinado com o bloqueio de firewall na VPS.
- `assembleDebug` gera um APK de debug (não assinado para produção). Para uso
  pessoal em um único aparelho isso é suficiente.
