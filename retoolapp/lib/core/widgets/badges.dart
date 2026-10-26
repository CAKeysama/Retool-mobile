import 'package:flutter/material.dart';

import '../../domain/entities/reutilizacao.dart';
import '../../domain/entities/solicitacao_cargo.dart';
import '../../domain/entities/user.dart';
import '../theme/app_theme.dart';

/// Chip compacto no padrão dos badges do sistema (`Pill` do desktop).
class Pill extends StatelessWidget {
  final String label;
  final Color fundo;
  final Color texto;
  final IconData? icon;
  final String? tooltip;

  const Pill({super.key, required this.label, required this.fundo, required this.texto, this.icon, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: texto), const SizedBox(width: 4)],
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: texto)),
        ),
      ]),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
  }
}

/// Badges coloridos de listagem (`.badge-pink/.badge-teal/.badge-yellow/.badge-blue`).
enum BadgeCor { neutro, pink, teal, yellow, blue }

class AppBadge extends StatelessWidget {
  final String label;
  final BadgeCor cor;
  const AppBadge(this.label, {super.key, this.cor = BadgeCor.neutro});

  @override
  Widget build(BuildContext context) {
    final (fundo, texto) = switch (cor) {
      BadgeCor.neutro => (AppColors.hover, AppColors.textDark),
      BadgeCor.pink => (AppColors.pinkBg, AppColors.pinkText),
      BadgeCor.teal => (AppColors.tealBg, AppColors.tealText),
      BadgeCor.yellow => (AppColors.yellowBg, AppColors.yellowText),
      BadgeCor.blue => (AppColors.blueBg, AppColors.blueText),
    };
    return Pill(label: label, fundo: fundo, texto: texto);
  }
}

class RoleBadge extends StatelessWidget {
  final String perfil;
  final bool curto;
  const RoleBadge({super.key, required this.perfil, this.curto = false});

  @override
  Widget build(BuildContext context) {
    final c = configDoPerfil(perfil);
    return Pill(label: curto ? c.tituloCurto : c.titulo, fundo: c.badgeBg, texto: c.badgeText);
  }
}

const Map<SituacaoUsuario, ({String label, Color fundo, Color texto})> situacaoVisual = {
  SituacaoUsuario.ativo: (label: 'Ativo', fundo: Color(0xFFDCFCE7), texto: Color(0xFF15803D)),
  SituacaoUsuario.pendente: (label: 'Aguardando aprovação', fundo: Color(0xFFFEF3C7), texto: Color(0xFFB45309)),
  SituacaoUsuario.bloqueado: (label: 'Bloqueado', fundo: Color(0xFFFEE2E2), texto: Color(0xFFB91C1C)),
  SituacaoUsuario.rejeitado: (label: 'Cadastro rejeitado', fundo: Color(0xFFF3F4F6), texto: Color(0xFF4B5563)),
};

class SituacaoBadge extends StatelessWidget {
  final SituacaoUsuario situacao;
  const SituacaoBadge(this.situacao, {super.key});

  @override
  Widget build(BuildContext context) {
    final v = situacaoVisual[situacao]!;
    return Pill(label: '● ${v.label}', fundo: v.fundo, texto: v.texto);
  }
}

class SolicitacaoStatusBadge extends StatelessWidget {
  final SolicitacaoCargoStatus status;
  const SolicitacaoStatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final (fundo, texto) = switch (status) {
      SolicitacaoCargoStatus.pendente => (const Color(0xFFFEF3C7), const Color(0xFFB45309)),
      SolicitacaoCargoStatus.aprovada => (const Color(0xFFDCFCE7), const Color(0xFF15803D)),
      SolicitacaoCargoStatus.rejeitada => (const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
    };
    return Pill(label: status.rotulo, fundo: fundo, texto: texto);
  }
}

class StatusReutilizacaoBadge extends StatelessWidget {
  final ReutilizacaoStatus status;

  /// Rótulo completo em vez do compacto.
  final bool completo;
  const StatusReutilizacaoBadge(this.status, {super.key, this.completo = false});

  @override
  Widget build(BuildContext context) {
    final c = corDoStatusReutilizacao(status);
    return Pill(
      label: completo ? status.valor : status.rotuloCurto,
      fundo: c.fundo,
      texto: c.texto,
      tooltip: completo ? null : status.valor,
    );
  }
}

/// Contador vermelho (pendências / notificações não lidas).
class CountBadge extends StatelessWidget {
  final int count;
  final bool invertido;
  const CountBadge(this.count, {super.key, this.invertido = false});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: invertido ? Colors.white : AppColors.primary,
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        semanticsLabel: '$count pendências',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: invertido ? AppColors.primary : Colors.white,
        ),
      ),
    );
  }
}
