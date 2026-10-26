import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/user.dart';
import '../../features/administracao/administracao_screen.dart';
import '../../features/auth/aguardando_aprovacao_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/troca_senha_screen.dart';
import '../../features/categorias/categorias_screen.dart';
import '../../features/conta/notificacoes_screen.dart';
import '../../features/conta/perfil_screen.dart';
import '../../features/dispositivos/dispositivo_detalhes_screen.dart';
import '../../features/dispositivos/dispositivo_form_screen.dart';
import '../../features/dispositivos/dispositivos_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/reutilizacoes/reutilizacoes_screen.dart';
import '../../features/sobre/sobre_screen.dart';
import '../../presentation/shell/app_shell.dart';
import '../../presentation/state/auth_controller.dart';
import '../../presentation/state/retool_controller.dart';
import '../widgets/widgets.dart';
import 'rotas.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Para onde a sessão deve ir (guardas `ProtectedLayout`, `PublicRoute` e `RoleRoute` do desktop).
String? redirecionar(AuthController auth, String local) {
  if (auth.loading) return local == Rotas.carregando ? null : Rotas.carregando;
  switch (auth.tela) {
    case TelaDaSessao.login:
      return local == Rotas.login ? null : Rotas.login;
    case TelaDaSessao.aguardandoAprovacao:
      return local == Rotas.aguardando ? null : Rotas.aguardando;
    case TelaDaSessao.trocaSenha:
      return local == Rotas.trocaSenha ? null : Rotas.trocaSenha;
    case TelaDaSessao.sistema:
      if (Rotas.sessaoRestrita.contains(local)) return Rotas.home;
      if (local.startsWith(Rotas.categorias) && !podeVerClassificacoes(auth.roleConfig)) return Rotas.dispositivos;
      if (local.startsWith(Rotas.administracao) && !auth.canGerenciarUsuarios) return Rotas.dispositivos;
      if ((local == Rotas.novoDispositivo || local.endsWith('/editar')) && !auth.canCadastrar && !auth.canEditar) {
        return Rotas.dispositivos;
      }
      return null;
  }
}

GoRouter criarRouter(AuthController auth) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Rotas.home,
    refreshListenable: auth,
    redirect: (context, state) => redirecionar(auth, state.matchedLocation),
    routes: [
      GoRoute(
        path: Rotas.carregando,
        builder: (_, _) => const Scaffold(body: LoadingView(mensagem: 'Sincronizando sessão ReTool...')),
      ),
      GoRoute(path: Rotas.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Rotas.aguardando, builder: (_, _) => const AguardandoAprovacaoScreen()),
      GoRoute(path: Rotas.trocaSenha, builder: (_, _) => const TrocaSenhaScreen()),

      // Formulário de dispositivo em tela cheia, acima da barra inferior.
      GoRoute(
        path: Rotas.novoDispositivo,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const DispositivoFormScreen(),
      ),
      GoRoute(
        path: '/dispositivos/:id/editar',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) => DispositivoFormScreen(id: s.pathParameters['id']),
      ),
      GoRoute(path: Rotas.sobre, parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const SobreScreen()),
      GoRoute(
        path: Rotas.notificacoes,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const NotificacoesScreen(),
      ),
      GoRoute(path: Rotas.perfil, parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const PerfilScreen()),

      // Abas com estado preservado (cada aba mantém rolagem e filtros ao alternar).
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Rotas.home, builder: (_, _) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Rotas.dispositivos,
              builder: (_, s) => DispositivosScreen(buscaInicial: s.uri.queryParameters['q']),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, s) => DispositivoDetalhesScreen(id: s.pathParameters['id']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Rotas.reutilizacoes,
              builder: (_, s) => ReutilizacoesScreen(destaqueId: s.uri.queryParameters['destaque']),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Rotas.categorias, builder: (_, _) => const CategoriasScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Rotas.administracao,
              builder: (_, s) => AdministracaoScreen(abaInicial: s.uri.queryParameters['aba']),
            ),
          ]),
        ],
      ),
    ],
  );
}
