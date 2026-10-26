import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_dependencies.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/user.dart';
import '../../../presentation/state/auth_controller.dart';
import '../widgets/admin_comum.dart';

/// Fluxo A: cadastros públicos (Convidados) aguardando decisão. A aprovação
/// exige a escolha explícita do cargo; a rejeição aceita um motivo opcional
/// (`AprovacoesCadastroPanel` do desktop).
class AprovacoesCadastroPanel extends StatefulWidget {
  final String? destacarId;
  const AprovacoesCadastroPanel({super.key, this.destacarId});

  @override
  State<AprovacoesCadastroPanel> createState() => _AprovacoesCadastroPanelState();
}

class _AprovacoesCadastroPanelState extends State<AprovacoesCadastroPanel> {
  final Map<String, UserRole> _cargoEscolhido = {};
  final _motivo = TextEditingController();
  final _chaveDestaque = GlobalKey();
  String? _rejeitandoUid;
  String? _processandoUid;
  String? _destaqueRolado;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _decidir(UserProfile u, bool aprovar) async {
    final cargo = _cargoEscolhido[u.uid];
    if (aprovar && cargo == null) {
      Toasts.mostrar('Selecione o cargo de ${u.nome} antes de aprovar.', erro: true);
      return;
    }
    final auth = context.read<AuthController>();
    final traduzir = context.read<AppDependencies>().traduzirErro;
    setState(() => _processandoUid = u.uid);
    try {
      await auth.decidirCadastro(u.uid, aprovar,
          perfil: aprovar ? cargo : null, motivo: aprovar ? null : _motivo.text);
      Toasts.mostrar(aprovar
          ? 'Cadastro de ${u.nome} aprovado com o cargo ${rolesConfig[cargo]!.titulo}.'
          : 'Cadastro de ${u.nome} rejeitado.');
      _cargoEscolhido.remove(u.uid);
      _rejeitandoUid = null;
      _motivo.clear();
    } catch (e) {
      Toasts.mostrar(traduzir(e), erro: true);
    } finally {
      if (mounted) setState(() => _processandoUid = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (auth.estadoUsuarios == EstadoSincronizacao.carregando) {
      return const EstadoCarregando(mensagem: 'Carregando cadastros...');
    }
    if (auth.estadoUsuarios == EstadoSincronizacao.erro) {
      return const EstadoErro(
          mensagem:
              'Não foi possível carregar os cadastros. Verifique sua conexão e se as regras do Firestore foram publicadas.');
    }

    final users = auth.users;
    final nomePorUid = {for (final u in users) u.uid: u.nome};
    final pendentes = users.where((u) => situacaoDoUsuario(u) == SituacaoUsuario.pendente).toList()
      ..sort((a, b) => (a.criadoEm ?? '').compareTo(b.criadoEm ?? ''));
    final decididos = users.where((u) => u.aprovadoEm != null || u.rejeitadoEm != null).toList()
      ..sort((a, b) => (b.aprovadoEm ?? b.rejeitadoEm ?? '').compareTo(a.aprovadoEm ?? a.rejeitadoEm ?? ''));
    final recentes = decididos.take(10).toList();

    if (widget.destacarId != null &&
        widget.destacarId != _destaqueRolado &&
        pendentes.any((u) => u.uid == widget.destacarId)) {
      _destaqueRolado = widget.destacarId;
      rolarAteDestaque(_chaveDestaque);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl),
      children: [
        if (pendentes.isEmpty)
          const FilaVazia('Nenhum cadastro aguardando aprovação.')
        else
          for (final u in pendentes) ...[
            _CartaoPendente(
              key: u.uid == widget.destacarId ? _chaveDestaque : ValueKey('cadastro-${u.uid}'),
              usuario: u,
              destacado: u.uid == widget.destacarId,
              cargo: _cargoEscolhido[u.uid],
              ocupado: _processandoUid == u.uid,
              rejeitando: _rejeitandoUid == u.uid,
              motivo: _motivo,
              onCargo: (r) => setState(() {
                if (r == null) {
                  _cargoEscolhido.remove(u.uid);
                } else {
                  _cargoEscolhido[u.uid] = r;
                }
              }),
              onAprovar: () => _decidir(u, true),
              onAlternarRejeicao: () => setState(() {
                _rejeitandoUid = _rejeitandoUid == u.uid ? null : u.uid;
                _motivo.clear();
              }),
              onConfirmarRejeicao: () => _decidir(u, false),
            ),
            const SizedBox(height: 10),
          ],
        if (recentes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const TituloSecao('Decisões recentes'),
          for (final u in recentes) ...[
            _CartaoDecisao(usuario: u, decididoPor: nomePorUid),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ],
    );
  }
}

class _CartaoPendente extends StatelessWidget {
  final UserProfile usuario;
  final bool destacado;
  final UserRole? cargo;
  final bool ocupado;
  final bool rejeitando;
  final TextEditingController motivo;
  final ValueChanged<UserRole?> onCargo;
  final VoidCallback onAprovar;
  final VoidCallback onAlternarRejeicao;
  final VoidCallback onConfirmarRejeicao;

  const _CartaoPendente({
    super.key,
    required this.usuario,
    required this.destacado,
    required this.cargo,
    required this.ocupado,
    required this.rejeitando,
    required this.motivo,
    required this.onCargo,
    required this.onAprovar,
    required this.onAlternarRejeicao,
    required this.onConfirmarRejeicao,
  });

  @override
  Widget build(BuildContext context) {
    final u = usuario;
    final legado = userRoleFromString(u.perfilSolicitado);
    return CartaoAdmin(
      destacado: destacado,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(u.nome, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
          const RoleBadge(perfil: perfilConvidado),
          const SituacaoBadge(SituacaoUsuario.pendente),
        ]),
        const SizedBox(height: 4),
        TextoSecundario('${u.email} · Cadastro em ${formatarDataHora(u.criadoEm)}'),
        if (legado != null && legado != UserRole.gerencia)
          TextoSecundario('Indicou no cadastro antigo: ${rolesConfig[legado]!.titulo}',
              cor: AppColors.avisoText),
        const SizedBox(height: 12),
        Semantics(
          label: 'Cargo de ${u.nome}',
          child: AppDropdown<UserRole>(
            key: ValueKey('cargo-${u.uid}'),
            hint: 'Selecione o cargo...',
            value: cargo,
            onChanged: ocupado ? null : onCargo,
            items: [
              for (final r in perfisAtribuiveis)
                DropdownMenuItem(value: r, child: Text(rolesConfig[r]!.titulo, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          BotaoAcao(
            label: 'Aprovar',
            icon: LucideIcons.check,
            cor: CorAcao.success,
            tooltip: cargo == null ? 'Selecione o cargo para aprovar' : null,
            loading: ocupado && !rejeitando,
            onPressed: ocupado || cargo == null ? null : onAprovar,
          ),
          BotaoAcao(
            label: 'Rejeitar',
            icon: LucideIcons.x,
            cor: CorAcao.danger,
            onPressed: ocupado ? null : onAlternarRejeicao,
          ),
        ]),
        if (rejeitando) ...[
          const SizedBox(height: 12),
          AppTextField(
            key: ValueKey('motivo-${u.uid}'),
            label: 'Motivo da rejeição (opcional — exibido ao usuário)',
            controller: motivo,
            maxLines: 2,
            maxLength: 500,
            enabled: !ocupado,
          ),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            BotaoAcao(label: 'Cancelar', onPressed: ocupado ? null : onAlternarRejeicao),
            const SizedBox(width: 8),
            Flexible(
              child: BotaoAcao(
                label: ocupado ? 'Rejeitando...' : 'Confirmar rejeição',
                cor: CorAcao.danger,
                onPressed: ocupado ? null : onConfirmarRejeicao,
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

class _CartaoDecisao extends StatelessWidget {
  final UserProfile usuario;
  final Map<String, String> decididoPor;
  const _CartaoDecisao({required this.usuario, required this.decididoPor});

  @override
  Widget build(BuildContext context) {
    final u = usuario;
    final rejeitado = situacaoDoUsuario(u) == SituacaoUsuario.rejeitado;
    final por = decididoPor[(rejeitado ? u.rejeitadoPorUid : u.aprovadoPorUid) ?? ''] ?? '—';
    return CartaoAdmin(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u.nome, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF111827))),
              TextoSecundario(u.email, tamanho: 12),
            ]),
          ),
          const SizedBox(width: 8),
          rejeitado
              ? const SituacaoBadge(SituacaoUsuario.rejeitado)
              : const Pill(label: '● Aprovado', fundo: Color(0xFFDCFCE7), texto: Color(0xFF15803D)),
        ]),
        if (rejeitado && (u.motivoRejeicao ?? '').isNotEmpty) TextoSecundario('Motivo: ${u.motivoRejeicao}', tamanho: 12),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (!rejeitado) RoleBadge(perfil: u.perfil, curto: true),
          TextoSecundario('Por $por · ${formatarDataHora(rejeitado ? u.rejeitadoEm : u.aprovadoEm)}', tamanho: 12),
        ]),
      ]),
    );
  }
}
