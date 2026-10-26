# ReTool Mobile

Versão Android (Flutter) do **ReTool — Gestão de Dispositivos e Ferramentas Industriais**
(FATEC Matão × Baldan). Usa **o mesmo Firebase do ReTool desktop**: mesmas coleções, regras,
perfis de acesso, fluxo de reutilização e auditoria. O que é feito no celular aparece no desktop
em tempo real, e vice-versa.

Arquitetura e convenções: [`docs/ARQUITETURA.md`](docs/ARQUITETURA.md).

## 1. Pré-requisitos (uma vez)

1. **Modo de desenvolvedor do Windows** (obrigatório para compilar apps Flutter com plugins):
   `Configurações > Sistema > Para desenvolvedores > Modo de desenvolvedor: Ativado`
   (atalho: `start ms-settings:developers`). Sem isso aparece o erro
   *"Building with plugins requires symlink support"*.
2. Android Studio com um emulador (AVD) criado, ou um celular com depuração USB.

## 2. Chaves do Firebase (`.env`)

```bash
cd retoolapp
cp .env.example .env     # no Windows: copy .env.example .env
```

Preencha o `.env` com as chaves do **app Web** do Firebase — são exatamente as mesmas variáveis
`VITE_FIREBASE_*` do `.env` do ReTool desktop, então você pode copiar os valores de lá.
O `.env` não vai para o git. Se as chaves estiverem vazias, o app abre uma tela explicando o que falta.

> **Atenção:** se a API key estiver restrita por *HTTP referrer* (sites) no Google Cloud Console,
> o Android é bloqueado. Nesse caso, em *APIs e serviços > Credenciais*, deixe a chave sem
> restrição de aplicativo (as regras do Firestore/Storage continuam protegendo os dados) ou crie
> uma chave separada para o app Android.

## 3. Rodar

```bash
flutter pub get
flutter run              # com o emulador aberto
```

No Android Studio: abra a pasta `retoolapp`, escolha o emulador e clique em **Run**.

## 4. Testes

```bash
flutter analyze
flutter test             # unidade (domínio, casos de uso, repositórios) + widget (telas e fluxos)
```

Os testes não precisam de Firebase: usam fakes em memória (`test/support/fakes.dart`) e
`fake_cloud_firestore` para validar o formato gravado no banco.

## 5. Emuladores do Firebase (opcional)

No `.env`: `VITE_USE_FIREBASE_EMULATORS=true` e, no emulador Android, `VITE_FIREBASE_EMULATOR_HOST=10.0.2.2`.
Suba os emuladores pelo projeto desktop (`npm run emuladores`).
