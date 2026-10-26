import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/router/rotas.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/entities/solicitacao_cargo.dart';
import '../../domain/entities/user.dart';
import '../../presentation/state/auth_controller.dart';
import 'solicitar_cargo_sheet.dart';

/// Ícone de cada cargo (`getRoleIcon` do `UserNavMenu`).
IconData iconeDoPerfil(String perfil) => switch (perfil) {
      'admin' => LucideIcons.slidersHorizontal,
      'projetista' => LucideIcons.hardHat,
      'engenharia' => LucideIcons.cpu,
      'gerencia' => LucideIcons.building2,
      _ => LucideIcons.userRound,
    };

/// Permissões exibidas no perfil (matriz do `CONTROLE_DE_ACESSO.md`).
List<({String label, bool permitido})> permissoesDo(RoleConfig c) => [
      (label: 'Consultar dispositivos e reutilizações', permitido: c.canConsultar),
      (label: 'Cadastrar registros', permitido: c.canCadastrar),
      (label: 'Editar registros', permitido: c.canEditar),
      (label: 'Excluir registros', permitido: c.canExcluir),
      (label: 'Aprovar solicitações', permitido: c.canAprovar),
      (label: 'Solicitar reutilização', permitido: c.canSolicitar),
      (label: 'Gerenciar usuários', permitido: c.canGerenciarUsuarios),
      (label: 'Ver histórico de ações (auditoria)', permitido: c.canVerLogs),
    ];

/// Menu do usuário em tela cheia (`UserNavMenu` do desktop): dados da conta,
/// cargo e permissões, alteração de cargo, atalhos e saída.
class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  Future<void> _sair(BuildContext context) async {
    final auth = context.read<AuthController>();
    final ok = await confirmar(
      context,
      titulo: 'Sair da conta',
      mensagem: 'Deseja encerrar sua sessão no ReTool?',
      confirmarLabel: 'Sair',
      perigoso: true,
    );
    if (ok) await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final perfil = auth.userProfile;
    if (perfil == null) {
      return Scaffold(appBar: AppBar(title: const Text('Minha conta')), body: const LoadingView());
    }
    final conf = auth.roleConfig;
    final inicial = perfil.nome.trim().isNotEmpty ? perfil.nome.trim()[0].toUpperCase() : '?';
    final podeSolicitar = podeSolicitarAlteracaoCargo(perfil);
    final pendente = auth.solicitacoesCargo
        .where((s) => s.usuarioUid == perfil.uid && s.status == SolicitacaoCargoStatus.pendente)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Minha conta')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl),
        children: [
          // Identificação
          AppCard(
            child: Row(children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: conf.badgeBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: conf.borderColor, width: 2),
                ),
                child: Text(inicial,
                    style: TextStyle(color: conf.badgeText, fontWeight: FontWeight.w800, fontSize: 22)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(perfil.nome.isEmpty ? 'Usuário ReTool' : perfil.nome,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                  const SizedBox(height: 2),
                  Text(perfil.email,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSubtle), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  RoleBadge(perfil: auth.currentRole),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.md),

          // Cargo e permissões
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: conf.badgeBg,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: conf.borderColor),
                ),
                child: Row(children: [
                  Icon(iconeDoPerfil(conf.id), size: 16, color: conf.iconColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(conf.titulo,
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: conf.badgeText)),
                  ),
                ]),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(conf.descricao, style: const TextStyle(fontSize: 13, color: AppColors.textBody, height: 1.5)),
              const SizedBox(height: AppSpacing.md),
              const SectionLabel('Permissões'),
              for (final p in permissoesDo(conf))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Icon(p.permitido ? LucideIcons.check : LucideIcons.x,
                        size: 16,
                        color: p.permitido ? AppColors.sucessoText : AppColors.erroText,
                        semanticLabel: p.permitido ? 'Permitido' : 'Não permitido'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(p.label,
                          style: TextStyle(
                              fontSize: 13.5, color: p.permitido ? AppColors.textDark : AppColors.textSubtle)),
                    ),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: AppSpacing.md),

          // Ações
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              if (auth.canGerenciarUsuarios)
                _ItemMenu(
                  icon: LucideIcons.users,
                  cor: const Color(0xFF7C3AED),
                  label: 'Administração: usuários e aprovações',
                  onTap: () => context.go(Rotas.administracao),
                ),
              if (auth.canVerLogs)
                _ItemMenu(
                  icon: LucideIcons.fileText,
                  cor: const Color(0xFF2563EB),
                  label: 'Histórico de ações (auditoria)',
                  onTap: () => context.go(Rotas.administracaoAba('logs')),
                ),
              if (podeSolicitar)
                _ItemMenu(
                  icon: LucideIcons.arrowUpDown,
                  cor: const Color(0xFFEA580C),
                  label: pendente != null ? 'Alteração de cargo (pendente)' : 'Solicitar alteração de cargo',
                  onTap: () => abrirSolicitacaoCargo(context),
                ),
              _ItemMenu(
                icon: LucideIcons.info,
                cor: AppColors.textSubtle,
                label: 'Sobre o Projeto',
                onTap: () => context.push(Rotas.sobre),
              ),
              _ItemMenu(
                icon: LucideIcons.logOut,
                cor: const Color(0xFFEF4444),
                label: 'Sair da Conta',
                destrutivo: true,
                onTap: () => _sair(context),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _ItemMenu extends StatelessWidget {
  final IconData icon;
  final Color cor;
  final String label;
  final VoidCallback onTap;
  final bool destrutivo;
  const _ItemMenu({required this.icon, required this.cor, required this.label, required this.onTap, this.destrutivo = false});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, size: 20, color: cor),
        title: Text(label,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: destrutivo ? FontWeight.w600 : FontWeight.w500,
              color: destrutivo ? cor : const Color(0xFF374151),
            )),
        trailing: destrutivo ? null : const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textMuted),
        minTileHeight: 52,
        onTap: onTap,
      );
}
