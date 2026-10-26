# ReTool Mobile — Arquitetura e convenções

Versão Flutter do **ReTool desktop** (`../../ReTool/retool`, React + Firebase). O desktop é a
referência de **aparência, regras de negócio e textos**: mesmas coleções do Firestore, mesmos
campos, mesmos status, mesmas mensagens em português. Os dois apps usam o **mesmo banco** ao
mesmo tempo, então nada pode gravar dados em formato diferente do desktop.

## Camadas (`lib/`)

| Pasta | Conteúdo | Equivalente no desktop |
|---|---|---|
| `domain/entities` | Modelos + regras puras (RBAC, máquina de estados, propagação de imagens, duplicados, sanitização de auditoria) | `src/domain/entities` |
| `domain/repositories/repositories.dart` | Contratos de dados (`AuthGateway`, `UsersRepository`, `DispositivosRepository`, ...) | `src/domain/repositories` |
| `domain/services` | Senha temporária, validação de arquivos | `src/domain/services`, `src/utils` |
| `application/usecases` | Fluxos de acesso (cadastro, aprovação, conta com senha temporária, troca de senha, cargo) | `src/application/usecases` |
| `data/` | Implementações Firebase (Firestore, Auth, Storage, Functions) | `src/data` |
| `presentation/state` | `AuthController` e `ReToolController` (ChangeNotifier) | `AuthContext`, `ReToolContext` |
| `presentation/shell` | Barra inferior + `TopActions` (sino + avatar) + `appBarPadrao()` | `Layout.tsx` |
| `core/` | Tema (cores do `index.css`), widgets compartilhados, rotas, formatadores, env | `index.css`, componentes base |
| `features/<modulo>` | Telas de cada módulo | `src/pages`, `src/components` |

## Regras para quem escreve telas

1. **Estado**: leia com `context.watch<ReToolController>()` / `context.watch<AuthController>()`;
   chame mutações com `context.read<...>()`. Toda mutação já faz checagem de permissão, auditoria,
   notificações e toast (`announce`). **Não** acesse repositórios/Firebase direto nas telas.
2. **Permissões**: use `auth.canCadastrar`, `canEditar`, `canExcluir`, `canAprovar`,
   `canSolicitar`, `canGerenciarUsuarios`, `auth.currentRole`. Esconda o que o perfil não pode fazer
   (igual ao desktop).
3. **UI**: use os widgets de `core/widgets/widgets.dart` (`AppButton`, `AppIconButton`,
   `AppTextField`, `AppSearchField`, `AppDropdown`, `AppCard`, `InfoBox`, `Pill`, `RoleBadge`,
   `StatusReutilizacaoBadge`, `EmptyState`, `SkeletonList`, `PageHeader`, `InfoRow`,
   `showAppSheet`, `confirmar`, `pedirTexto`, `Toasts.mostrar`) e as cores/espaçamentos de
   `core/theme/app_theme.dart` (`AppColors`, `AppSpacing`, `AppRadius`). Ícones: `LucideIcons`
   (mesmo pacote de ícones do desktop, `lucide`). Modais do desktop viram **bottom sheets**.
4. **Abas** (Home, Dispositivos, Reutilizações, Categorias, Administração) usam
   `Scaffold(appBar: appBarPadrao(context, titulo: ..., acoes: [...]))` para ter sino + avatar.
   Telas empilhadas (detalhe, formulário, sobre, perfil, notificações) usam `AppBar` normal com voltar.
5. **Navegação**: `context.push(Rotas.dispositivo(id))`, `context.go(Rotas.reutilizacoes)` etc.
   (`core/router/rotas.dart`).
6. **Velocidade**: listas sempre com `ListView.builder`/`SliverList`; nada de filtrar listas
   inteiras dentro de `itemBuilder`; use os índices do controller (`retool.dispositivo(id)`,
   `retool.categoria(id)`, `retool.reutilizacoesDo(id)`, `retool.buscarDispositivos(q)`);
   imagens via `ImagemRemota` (cache + decodificação no tamanho certo); `const` sempre que der;
   debounce de ~200 ms em buscas por digitação.
7. **Textos** em pt-BR, copiados do desktop sempre que existirem. Campos vazios exibem
   "Não informado" (Open World Assumption).
8. **Testes** obrigatórios para cada tela/regra nova, em `test/` espelhando `lib/`. Use
   `test/support/fakes.dart` (`FakeBackend` com `criarUsuario(..., logar: true)` e
   `semearDadosFabris()`) e `test/support/harness.dart` (`pumpApp` para fluxos com rotas,
   `pumpTela` para uma tela isolada, `assentar`, `tocar`). Não use `pumpAndSettle` (spinners
   infinitos travam); use `assentar(tester)`.

## Rodando

```bash
flutter pub get
flutter analyze
flutter test
flutter run            # com o emulador do Android Studio aberto
```
