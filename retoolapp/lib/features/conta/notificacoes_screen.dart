import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/router/rotas.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/entities/notificacao.dart';
import '../../domain/entities/reutilizacao.dart';
import '../../domain/entities/solicitacao_cargo.dart';
import '../../domain/entities/user.dart';
import '../../presentation/state/auth_controller.dart';
import '../../presentation/state/retool_controller.dart';

typedef StatusVisual = ({String label, Color cor, Color fundo});

const StatusVisual _aprovada = (label: 'Aprovada', cor: Color(0xFF15803D), fundo: Color(0xFFDCFCE7));
const StatusVisual _recusada = (label: 'Recusada', cor: Color(0xFFB91C1C), fundo: Color(0xFFFEE2E2));
const StatusVisual _rejeitada = (label: 'Rejeitada', cor: Color(0xFFB91C1C), fundo: Color(0xFFFEE2E2));
const StatusVisual _pendente = (label: 'Pendente', cor: Color(0xFFB45309), fundo: Color(0xFFFEF3C7));
const StatusVisual _removida = (label: 'Removida', cor: Color(0xFF6B7280), fundo: Color(0xFFF3F4F6));

/// Status "vivo" da notificação, derivado da entidade referenciada (igual ao desktop).
StatusVisual statusDaNotificacao(
  Notificacao n, {
  required Map<String, Reutilizacao> reutilizacoes,
  required Map<String, SituacaoUsuario> situacaoUsuarios,
  required Map<String, SolicitacaoCargoStatus> statusSolicitacoes,
}) {
  switch (n.tipo) {
    case NotificacaoTipo.reutilizacaoNova:
    case NotificacaoTipo.reutilizacaoDecidida:
      final reu = reutilizacoes[n.entidadeId];
      if (reu == null) return _removida;
      final cor = corDoStatusReutilizacao(reu.status);
      return (label: reu.status.rotuloCurto, cor: cor.texto, fundo: cor.fundo);
    case NotificacaoTipo.contaNova:
      final situacao = situacaoUsuarios[n.entidadeId];
      if (situacao == null || situacao == SituacaoUsuario.rejeitado) return _recusada;
      return situacao == SituacaoUsuario.pendente ? _pendente : _aprovada;
    case NotificacaoTipo.cargoSolicitado:
      final status = statusSolicitacoes[n.entidadeId];
      if (status == SolicitacaoCargoStatus.pendente) return _pendente;
      return status == SolicitacaoCargoStatus.aprovada ? _aprovada : _rejeitada;
    case NotificacaoTipo.contaDecidida:
    case NotificacaoTipo.cargoDecidido:
      // A decisão vem registrada na própria notificação.
      if (n.decisao == 'aprovada') return _aprovada;
      return n.tipo == NotificacaoTipo.cargoDecidido ? _rejeitada : _recusada;
  }
}

/// Notificações em tela cheia (`NotificationsMenu` do desktop).
class NotificacoesScreen extends StatefulWidget {
  const NotificacoesScreen({super.key});

  @override
  State<NotificacoesScreen> createState() => _NotificacoesScreenState();
}

class _NotificacoesScreenState extends State<NotificacoesScreen> {
  bool _somenteNaoLidas = false;

  /// Destino ao abrir a notificação (mesmas regras do desktop).
  String? _destino(Notificacao n, AuthController auth) {
    switch (n.tipo) {
      case NotificacaoTipo.reutilizacaoNova:
      case NotificacaoTipo.reutilizacaoDecidida:
        if ((n.entidadeId ?? '').isNotEmpty) return Rotas.reutilizacao(n.entidadeId!);
        if ((n.dispositivoId ?? '').isNotEmpty) return Rotas.dispositivo(n.dispositivoId!);
        return Rotas.reutilizacoes;
      case NotificacaoTipo.contaNova:
        if (!auth.canGerenciarUsuarios) return null;
        return _comDestaque(Rotas.administracaoAba('cadastros'), n.entidadeId);
      case NotificacaoTipo.cargoSolicitado:
        if (!auth.canGerenciarUsuarios) return null;
        return _comDestaque(Rotas.administracaoAba('cargos'), n.entidadeId);
      case NotificacaoTipo.contaDecidida:
      case NotificacaoTipo.cargoDecidido:
        return null;
    }
  }

  String _comDestaque(String rota, String? id) =>
      (id == null || id.isEmpty) ? rota : '$rota&destaque=${Uri.encodeQueryComponent(id)}';

  Future<void> _abrir(Notificacao n) async {
    final auth = context.read<AuthController>();
    if (!n.lida) {
      try {
        await auth.marcarNotificacaoLida(n.id, true);
      } catch (_) {}
    }
    final destino = _destino(n, auth);
    if (destino != null && mounted) context.go(destino);
  }

  Future<void> _marcarLida(Notificacao n) async {
    final auth = context.read<AuthController>();
    try {
      await auth.marcarNotificacaoLida(n.id, true);
    } catch (_) {}
  }

  Future<void> _marcarTodas() async {
    try {
      await context.read<AuthController>().marcarTodasComoLidas();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final reutilizacoes = context.select<ReToolController, List<Reutilizacao>>((r) => r.reutilizacoes);
    final todas = auth.notifications;
    final naoLidas = auth.notificacoesNaoLidas;
    final lista = _somenteNaoLidas ? todas.where((n) => !n.lida).toList() : todas;

    final reuPorId = {for (final r in reutilizacoes) r.id: r};
    final situacaoUsuarios = {for (final u in auth.users) u.uid: situacaoDoUsuario(u)};
    final statusSolicitacoes = {for (final s in auth.solicitacoesCargo) s.id: s.status};

    /// Notificações que ainda dependem de uma decisão de quem as recebeu.
    bool exigeAcao(Notificacao n) => switch (n.tipo) {
          NotificacaoTipo.contaNova =>
            auth.canGerenciarUsuarios && situacaoUsuarios[n.entidadeId] == SituacaoUsuario.pendente,
          NotificacaoTipo.cargoSolicitado =>
            auth.canGerenciarUsuarios && statusSolicitacoes[n.entidadeId] == SolicitacaoCargoStatus.pendente,
          NotificacaoTipo.reutilizacaoNova => auth.canAprovar &&
              n.exigeAcao &&
              reuPorId[n.entidadeId]?.status == ReutilizacaoStatus.emAnaliseProjetista,
          _ => false,
        };
    final aguardando = todas.where(exigeAcao).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Notificações')),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(
                label: Text('Todas (${todas.length})'),
                selected: !_somenteNaoLidas,
                showCheckmark: false,
                labelStyle: TextStyle(
                    color: !_somenteNaoLidas ? Colors.white : AppColors.textBody, fontWeight: FontWeight.w600),
                onSelected: (_) => setState(() => _somenteNaoLidas = false),
              ),
              ChoiceChip(
                label: Text('Não lidas ($naoLidas)'),
                selected: _somenteNaoLidas,
                showCheckmark: false,
                labelStyle: TextStyle(
                    color: _somenteNaoLidas ? Colors.white : AppColors.textBody, fontWeight: FontWeight.w600),
                onSelected: (_) => setState(() => _somenteNaoLidas = true),
              ),
              if (aguardando > 0)
                Pill(
                  label: '$aguardando aguardando ação',
                  fundo: const Color(0xFFFEF3C7),
                  texto: const Color(0xFFB45309),
                ),
            ],
          ),
        ),
        if (naoLidas > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _marcarTodas,
                icon: const Icon(LucideIcons.checkCheck, size: 16),
                label: const Text('Marcar todas como lidas', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        const Divider(),
        Expanded(
          child: lista.isEmpty
              ? EmptyState(
                  icon: LucideIcons.bellOff,
                  titulo: _somenteNaoLidas ? 'Nenhuma notificação não lida.' : 'Sem notificações.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.xl),
                  itemCount: lista.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 2),
                  itemBuilder: (_, i) {
                    final n = lista[i];
                    return _ItemNotificacao(
                      key: ValueKey('notificacao-${n.id}'),
                      notificacao: n,
                      status: statusDaNotificacao(n,
                          reutilizacoes: reuPorId,
                          situacaoUsuarios: situacaoUsuarios,
                          statusSolicitacoes: statusSolicitacoes),
                      exigeAcao: exigeAcao(n),
                      onAbrir: () => _abrir(n),
                      onMarcarLida: () => _marcarLida(n),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class _ItemNotificacao extends StatelessWidget {
  final Notificacao notificacao;
  final StatusVisual status;
  final bool exigeAcao;
  final VoidCallback onAbrir;
  final VoidCallback onMarcarLida;

  const _ItemNotificacao({
    super.key,
    required this.notificacao,
    required this.status,
    required this.exigeAcao,
    required this.onAbrir,
    required this.onMarcarLida,
  });

  @override
  Widget build(BuildContext context) {
    final n = notificacao;
    return Semantics(
      button: true,
      label: n.lida ? null : 'Não lida',
      child: Material(
        color: n.lida ? Colors.transparent : const Color(0xFFF8F7FF),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onAbrir,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 4, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: n.lida ? const Color(0xFFD1D5DB) : AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Text(n.titulo,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: n.lida ? FontWeight.w600 : FontWeight.w700,
                              color: const Color(0xFF111827))),
                    ),
                    const SizedBox(width: 6),
                    Pill(label: status.label, fundo: status.fundo, texto: status.cor),
                  ]),
                  const SizedBox(height: 2),
                  Text(n.descricao, style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.4)),
                  const SizedBox(height: 4),
                  Tooltip(
                    message: formatarDataHora(n.dataHora),
                    child: Text(formatarRelativo(n.dataHora),
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                  ),
                  if (exigeAcao) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      const Pill(
                        label: 'Requer ação',
                        icon: LucideIcons.triangleAlert,
                        fundo: Color(0xFFFEF3C7),
                        texto: Color(0xFFB45309),
                      ),
                      AppButton.primary(
                        label: 'Analisar',
                        trailingIcon: LucideIcons.arrowRight,
                        compact: true,
                        onPressed: onAbrir,
                      ),
                    ]),
                  ],
                ]),
              ),
              if (!n.lida)
                IconButton(
                  tooltip: 'Marcar como lida',
                  icon: const Icon(LucideIcons.checkCheck, size: 18, color: AppColors.textMuted),
                  onPressed: onMarcarLida,
                )
              else
                const SizedBox(width: 12),
            ]),
          ),
        ),
      ),
    );
  }
}
