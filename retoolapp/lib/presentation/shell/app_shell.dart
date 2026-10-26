import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/router/rotas.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../state/auth_controller.dart';
import '../state/retool_controller.dart';

/// Índices das abas no `StatefulShellRoute` (ver `app_router.dart`).
class AbaShell {
  AbaShell._();
  static const home = 0;
  static const dispositivos = 1;
  static const reutilizacoes = 2;
  static const categorias = 3;
  static const administracao = 4;
}

/// Barra de navegação inferior do layout mobile do desktop (`.bottom-nav`):
/// Home, Dispositivos, Reutilizações, Categorias (cadastro/edição) e Admin.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const AppShell({super.key, required this.shell});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final itens = <({int aba, IconData icon, String label, int badge})>[
      (aba: AbaShell.home, icon: LucideIcons.house, label: 'Home', badge: 0),
      (aba: AbaShell.dispositivos, icon: LucideIcons.component, label: 'Dispositivos', badge: 0),
      (aba: AbaShell.reutilizacoes, icon: LucideIcons.list, label: 'Reutilizações', badge: 0),
      if (podeVerClassificacoes(auth.roleConfig))
        (aba: AbaShell.categorias, icon: LucideIcons.settings, label: 'Categorias', badge: 0),
      if (auth.canGerenciarUsuarios)
        (aba: AbaShell.administracao, icon: LucideIcons.shieldCheck, label: 'Admin', badge: auth.pendenciasAdmin),
    ];
    var selecionado = itens.indexWhere((i) => i.aba == shell.currentIndex);
    if (selecionado < 0) selecionado = 0;

    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [BoxShadow(color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, -4), spreadRadius: -1)],
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            indicatorColor: AppColors.primarySoft,
            height: 64,
            labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: s.contains(WidgetState.selected) ? AppColors.primary : AppColors.textMuted,
                )),
            iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
                  size: 24,
                  color: s.contains(WidgetState.selected) ? AppColors.primary : AppColors.textMuted,
                )),
          ),
          child: NavigationBar(
            selectedIndex: selecionado,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (i) {
              final aba = itens[i].aba;
              // Tocar na aba atual volta à raiz dela (padrão mobile).
              shell.goBranch(aba, initialLocation: aba == shell.currentIndex);
            },
            destinations: [
              for (final i in itens)
                NavigationDestination(
                  icon: i.badge > 0
                      ? Badge(label: Text('${i.badge}'), backgroundColor: AppColors.primary, child: Icon(i.icon))
                      : Icon(i.icon),
                  label: i.label,
                  tooltip: i.badge > 0 ? '${i.label} (${i.badge} pendências)' : i.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ações do topo presentes em todas as abas: sino de notificações e menu do usuário
/// (equivalentes a `NotificationsMenu` + `UserNavMenu` do desktop).
class TopActions extends StatelessWidget {
  const TopActions({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final perfil = auth.userProfile;
    final naoLidas = auth.notificacoesNaoLidas;
    final conf = auth.roleConfig;
    final inicial = (perfil?.nome.trim().isNotEmpty ?? false) ? perfil!.nome.trim()[0].toUpperCase() : '?';
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        tooltip: naoLidas > 0 ? 'Notificações ($naoLidas não lidas)' : 'Notificações',
        onPressed: () => context.push(Rotas.notificacoes),
        icon: Badge(
          isLabelVisible: naoLidas > 0,
          backgroundColor: AppColors.primary,
          label: Text(naoLidas > 99 ? '99+' : '$naoLidas'),
          child: const Icon(LucideIcons.bell, size: 22, color: AppColors.textDark),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: Semantics(
          button: true,
          label: 'Menu do usuário: ${perfil?.nome ?? ''}, ${conf.tituloCurto}',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.push(Rotas.perfil),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: conf.badgeBg,
                shape: BoxShape.circle,
                border: Border.all(color: conf.borderColor, width: 1.5),
              ),
              child: Text(inicial,
                  style: TextStyle(color: conf.badgeText, fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// AppBar padrão das abas: título à esquerda + [TopActions].
PreferredSizeWidget appBarPadrao(BuildContext context, {Widget? titulo, List<Widget> acoes = const [], PreferredSizeWidget? bottom}) =>
    AppBar(
      title: titulo ?? const ReToolLogo(fontSize: 22),
      actions: [...acoes, const TopActions()],
      bottom: bottom,
    );
