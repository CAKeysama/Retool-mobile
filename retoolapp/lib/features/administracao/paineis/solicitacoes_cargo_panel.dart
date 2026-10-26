import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_dependencies.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/solicitacao_cargo.dart';
import '../../../domain/entities/user.dart';
import '../../../presentation/state/auth_controller.dart';
import '../widgets/admin_comum.dart';

/// Fluxo B: pedidos de alteração de cargo feitos pelos próprios usuários.
/// O cargo só muda na aprovação; a rejeição mantém o cargo atual
/// (`SolicitacoesCargoPanel` do desktop).
class SolicitacoesCargoPanel extends StatefulWidget {
  final String? destacarId;
  const SolicitacoesCargoPanel({super.key, this.destacarId});

  @override
  State<SolicitacoesCargoPanel> createState() => _SolicitacoesCargoPanelState();
}

class _SolicitacoesCargoPanelState extends State<SolicitacoesCargoPanel> {
  final _motivo = TextEditingController();
  final _chaveDestaque = GlobalKey();
  ({String id, bool aprovar})? _decidindo;
  String? _processandoId;
  SolicitacaoCargoStatus? _filtroStatus;
  String? _destaqueRolado;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _confirmar(SolicitacaoCargo s, bool aprovar) async {
    final auth = context.read<AuthController>();
    final traduzir = context.read<AppDependencies>().traduzirErro;
    setState(() => _processandoId = s.id);
    try {
      await auth.decidirSolicitacaoCargo(s.id, aprovar, motivo: _motivo.text);
      Toasts.mostrar(aprovar
          ? 'Cargo de ${s.usuarioNome} alterado para ${rolesConfig[s.perfilSolicitado]!.titulo}.'
          : 'Solicitação de ${s.usuarioNome} rejeitada; o cargo atual foi mantido.');
      _decidindo = null;
      _motivo.clear();
    } catch (e) {
      Toasts.mostrar(traduzir(e), erro: true);
    } finally {
      if (mounted) setState(() => _processandoId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (auth.estadoSolicitacoesCargo == EstadoSincronizacao.carregando) {
      return const EstadoCarregando(mensagem: 'Carregando solicitações de cargo...');
    }
    if (auth.estadoSolicitacoesCargo == EstadoSincronizacao.erro) {
      return const EstadoErro(
          mensagem:
              'Não foi possível carregar as solicitações de cargo. Verifique sua conexão e se as regras do Firestore foram publicadas.');
    }

    final perfilAtualPorUid = {for (final u in auth.users) u.uid: u.perfil};
    final todas = auth.solicitacoesCargo;
    final pendentes = todas.where((s) => s.status == SolicitacaoCargoStatus.pendente).toList()
      ..sort((a, b) => a.dataSolicitacao.compareTo(b.dataSolicitacao));
    final historico = todas
        .where((s) => s.status != SolicitacaoCargoStatus.pendente && (_filtroStatus == null || s.status == _filtroStatus))
        .toList()
      ..sort((a, b) => (b.dataDecisao ?? b.dataSolicitacao).compareTo(a.dataDecisao ?? a.dataSolicitacao));
    final meuUid = auth.userProfile?.uid;

    if (widget.destacarId != null &&
        widget.destacarId != _destaqueRolado &&
        pendentes.any((s) => s.id == widget.destacarId)) {
      _destaqueRolado = widget.destacarId;
      rolarAteDestaque(_chaveDestaque);
    }

    return CustomScrollView(slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
        sliver: SliverList.list(children: [
          TituloSecao('Pendentes (${pendentes.length})'),
          if (pendentes.isEmpty)
            const FilaVazia('Nenhuma solicitação de alteração de cargo pendente.')
          else
            for (final s in pendentes) ...[
              _CartaoSolicitacao(
                key: s.id == widget.destacarId ? _chaveDestaque : ValueKey('solicitacao-${s.id}'),
                solicitacao: s,
                destacado: s.id == widget.destacarId,
                propria: s.usuarioUid == meuUid,
                perfilAgora: perfilAtualPorUid[s.usuarioUid],
                ocupado: _processandoId == s.id,
                decidindo: _decidindo?.id == s.id ? _decidindo!.aprovar : null,
                motivo: _motivo,
                onIniciar: (aprovar) => setState(() {
                  _decidindo = (id: s.id, aprovar: aprovar);
                  _motivo.clear();
                }),
                onCancelar: () => setState(() => _decidindo = null),
                onConfirmar: (aprovar) => _confirmar(s, aprovar),
              ),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: AppSpacing.lg),
          TituloSecao(
            'Histórico de decisões',
            trailing: SizedBox(
              width: 170,
              child: Semantics(
                label: 'Filtrar histórico por status',
                child: AppDropdown<SolicitacaoCargoStatus?>(
                  key: const ValueKey('filtro-historico-cargo'),
                  value: _filtroStatus,
                  onChanged: (v) => setState(() => _filtroStatus = v),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Todas as decisões', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: SolicitacaoCargoStatus.aprovada, child: Text('Aprovadas')),
                    DropdownMenuItem(value: SolicitacaoCargoStatus.rejeitada, child: Text('Rejeitadas')),
                  ],
                ),
              ),
            ),
          ),
          if (historico.isEmpty) const FilaVazia('Nenhuma decisão registrada.'),
        ]),
      ),
      if (historico.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
          sliver: SliverList.separated(
            itemCount: historico.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => _CartaoHistorico(solicitacao: historico[i]),
          ),
        ),
    ]);
  }
}

class _Transicao extends StatelessWidget {
  final String de;
  final String para;
  final bool curto;
  const _Transicao({required this.de, required this.para, this.curto = false});

  @override
  Widget build(BuildContext context) => Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        RoleBadge(perfil: de, curto: curto),
        Icon(LucideIcons.arrowRight, size: curto ? 12 : 14, color: AppColors.textSubtle, semanticLabel: 'para'),
        RoleBadge(perfil: para, curto: curto),
      ]);
}

class _CartaoSolicitacao extends StatelessWidget {
  final SolicitacaoCargo solicitacao;
  final bool destacado;
  final bool propria;
  final String? perfilAgora;
  final bool ocupado;

  /// `null` sem decisão em andamento; senão, se é aprovação.
  final bool? decidindo;
  final TextEditingController motivo;
  final ValueChanged<bool> onIniciar;
  final VoidCallback onCancelar;
  final ValueChanged<bool> onConfirmar;

  const _CartaoSolicitacao({
    super.key,
    required this.solicitacao,
    required this.destacado,
    required this.propria,
    required this.perfilAgora,
    required this.ocupado,
    required this.decidindo,
    required this.motivo,
    required this.onIniciar,
    required this.onCancelar,
    required this.onConfirmar,
  });

  @override
  Widget build(BuildContext context) {
    final s = solicitacao;
    final para = rolesConfig[s.perfilSolicitado]!.titulo;
    final bloqueado = ocupado || propria;
    return CartaoAdmin(
      destacado: destacado,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(s.usuarioNome, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
          const SolicitacaoStatusBadge(SolicitacaoCargoStatus.pendente),
        ]),
        const SizedBox(height: 4),
        TextoSecundario('${s.usuarioEmail} · Solicitado em ${formatarDataHora(s.dataSolicitacao)}'),
        const SizedBox(height: 8),
        _Transicao(de: s.perfilAtual.name, para: s.perfilSolicitado.name),
        if (perfilAgora != null && perfilAgora != s.perfilAtual.name) ...[
          const SizedBox(height: 6),
          TextoSecundario('O cargo atual do usuário mudou desde o pedido: ${configDoPerfil(perfilAgora).titulo}.',
              cor: AppColors.avisoText, tamanho: 12),
        ],
        if ((s.justificativa ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Justificativa: ', style: TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: s.justificativa),
            ]),
            style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.45),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          BotaoAcao(
            label: 'Aprovar',
            icon: LucideIcons.check,
            cor: CorAcao.success,
            tooltip: propria ? 'O próprio solicitante não decide a sua solicitação' : null,
            onPressed: bloqueado ? null : () => onIniciar(true),
          ),
          BotaoAcao(
            label: 'Rejeitar',
            icon: LucideIcons.x,
            cor: CorAcao.danger,
            onPressed: bloqueado ? null : () => onIniciar(false),
          ),
        ]),
        if (decidindo != null) ...[
          const SizedBox(height: 12),
          Text.rich(
            decidindo!
                ? TextSpan(children: [
                    const TextSpan(text: 'Confirmar a alteração do cargo de '),
                    TextSpan(text: s.usuarioNome, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const TextSpan(text: ' para '),
                    TextSpan(text: para, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const TextSpan(text: '?'),
                  ])
                : TextSpan(children: [
                    const TextSpan(text: 'Rejeitar a solicitação de '),
                    TextSpan(text: s.usuarioNome, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const TextSpan(text: '? O cargo atual será mantido.'),
                  ]),
            style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.45),
          ),
          const SizedBox(height: 8),
          AppTextField(
            key: ValueKey('motivo-cargo-${s.id}'),
            label: 'Observação (opcional — enviada ao usuário)',
            controller: motivo,
            maxLines: 2,
            maxLength: 500,
            enabled: !ocupado,
          ),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            BotaoAcao(label: 'Cancelar', onPressed: ocupado ? null : onCancelar),
            const SizedBox(width: 8),
            Flexible(
              child: BotaoAcao(
                label: ocupado
                    ? 'Salvando...'
                    : decidindo!
                        ? 'Confirmar aprovação'
                        : 'Confirmar rejeição',
                cor: decidindo! ? CorAcao.success : CorAcao.danger,
                onPressed: ocupado ? null : () => onConfirmar(decidindo!),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

class _CartaoHistorico extends StatelessWidget {
  final SolicitacaoCargo solicitacao;
  const _CartaoHistorico({required this.solicitacao});

  @override
  Widget build(BuildContext context) {
    final s = solicitacao;
    return CartaoAdmin(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.usuarioNome, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF111827))),
              TextoSecundario(s.usuarioEmail, tamanho: 12),
            ]),
          ),
          const SizedBox(width: 8),
          SolicitacaoStatusBadge(s.status),
        ]),
        const SizedBox(height: 6),
        _Transicao(de: s.perfilAtual.name, para: s.perfilSolicitado.name, curto: true),
        if ((s.motivoDecisao ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          TextoSecundario(s.motivoDecisao!, tamanho: 12),
        ],
        const SizedBox(height: 6),
        TextoSecundario(
          'Solicitado em ${formatarDataHora(s.dataSolicitacao)} · Decidido por ${s.decididoPorNome ?? '—'} em ${formatarDataHora(s.dataDecisao)}',
          tamanho: 12,
        ),
      ]),
    );
  }
}
