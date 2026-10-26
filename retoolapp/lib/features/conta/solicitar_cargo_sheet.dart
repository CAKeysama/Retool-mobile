import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_dependencies.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/entities/solicitacao_cargo.dart';
import '../../domain/entities/user.dart';
import '../../presentation/state/auth_controller.dart';
import '../administracao/widgets/admin_comum.dart';

/// Abre o pedido de alteração do próprio cargo (`SolicitarAlteracaoCargoModal`).
Future<void> abrirSolicitacaoCargo(BuildContext context) => showAppSheet<void>(
      context,
      titulo: 'Alteração de cargo',
      builder: (_) => const SolicitarCargoSheet(),
    );

/// Fluxo B (usuário): o cargo não muda aqui — a solicitação vai para a
/// Administração, que aprova ou rejeita.
class SolicitarCargoSheet extends StatefulWidget {
  const SolicitarCargoSheet({super.key});

  @override
  State<SolicitarCargoSheet> createState() => _SolicitarCargoSheetState();
}

class _SolicitarCargoSheetState extends State<SolicitarCargoSheet> {
  final _justificativa = TextEditingController();
  UserRole? _perfil;
  bool _enviando = false;
  ({TipoAviso tipo, String texto})? _aviso;
  int _versao = 0;

  @override
  void dispose() {
    _justificativa.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final perfil = _perfil;
    if (perfil == null) return;
    final auth = context.read<AuthController>();
    final traduzir = context.read<AppDependencies>().traduzirErro;
    setState(() {
      _enviando = true;
      _aviso = null;
    });
    try {
      await auth.solicitarAlteracaoCargo(perfil, justificativa: _justificativa.text);
      if (!mounted) return;
      setState(() {
        _aviso = (
          tipo: TipoAviso.sucesso,
          texto:
              'Solicitação enviada. A Administração foi notificada e decidirá sobre o cargo ${rolesConfig[perfil]!.titulo}.'
        );
        _perfil = null;
        _justificativa.clear();
        _versao++;
      });
    } catch (e) {
      if (mounted) setState(() => _aviso = (tipo: TipoAviso.erro, texto: traduzir(e)));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final usuario = auth.userProfile;
    if (usuario == null) return const SizedBox.shrink();

    final minhas = auth.solicitacoesCargo.where((s) => s.usuarioUid == usuario.uid).toList()
      ..sort((a, b) => b.dataSolicitacao.compareTo(a.dataSolicitacao));
    final pendente = minhas.where((s) => s.status == SolicitacaoCargoStatus.pendente).firstOrNull;
    final decididas = minhas.where((s) => s.status != SolicitacaoCargoStatus.pendente).take(5).toList();
    final opcoes = perfisAtribuiveis.where((r) => r.name != usuario.perfil).toList();
    final estado = auth.estadoSolicitacoesCargo;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        const Text('Cargo atual:', style: TextStyle(fontSize: 14, color: Color(0xFF374151))),
        RoleBadge(perfil: usuario.perfil),
      ]),
      const SizedBox(height: AppSpacing.md),
      if (_aviso != null) ...[
        AvisoAdmin(tipo: _aviso!.tipo, texto: _aviso!.texto, onFechar: () => setState(() => _aviso = null)),
        const SizedBox(height: AppSpacing.md),
      ],
      if (estado == EstadoSincronizacao.carregando) const EstadoCarregando(mensagem: 'Consultando suas solicitações...'),
      if (estado == EstadoSincronizacao.erro)
        const EstadoErro(mensagem: 'Não foi possível consultar suas solicitações de cargo.'),
      if (estado == EstadoSincronizacao.pronto)
        if (pendente != null)
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                const SolicitacaoStatusBadge(SolicitacaoCargoStatus.pendente),
                TextoSecundario('enviada em ${formatarDataHora(pendente.dataSolicitacao)}', tamanho: 13),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                RoleBadge(perfil: pendente.perfilAtual.name),
                const Icon(LucideIcons.arrowRight, size: 14, color: AppColors.textSubtle),
                RoleBadge(perfil: pendente.perfilSolicitado.name),
              ]),
              const SizedBox(height: 10),
              const Text(
                'Sua solicitação está aguardando a decisão da Administração. Uma nova solicitação só pode ser feita depois dessa análise.',
                style: TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.5),
              ),
            ]),
          )
        else ...[
          AppDropdown<UserRole>(
            key: ValueKey('cargo-solicitado-$_versao'),
            label: 'Cargo solicitado',
            obrigatorio: true,
            hint: 'Selecione...',
            value: _perfil,
            onChanged: _enviando ? null : (r) => setState(() => _perfil = r),
            items: [
              for (final r in opcoes)
                DropdownMenuItem(value: r, child: Text(rolesConfig[r]!.titulo, overflow: TextOverflow.ellipsis)),
            ],
          ),
          if (_perfil != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TextoSecundario(rolesConfig[_perfil]!.descricao, cor: AppColors.textMuted, tamanho: 12),
            ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Justificativa (opcional)',
            hint: 'Explique por que precisa do novo cargo.',
            controller: _justificativa,
            maxLines: 3,
            maxLength: justificativaMax,
            enabled: !_enviando,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            AppButton(label: 'Fechar', compact: true, onPressed: () => Navigator.of(context).maybePop()),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: AppButton.primary(
                label: _enviando ? 'Enviando...' : 'Enviar solicitação',
                icon: LucideIcons.send,
                compact: true,
                loading: _enviando,
                onPressed: _perfil == null ? null : _enviar,
              ),
            ),
          ]),
        ],
      if (estado == EstadoSincronizacao.pronto && decididas.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.lg),
        const Text('Solicitações anteriores',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
        const SizedBox(height: 6),
        for (final s in decididas)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(spacing: 6, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SolicitacaoStatusBadge(s.status),
              TextoSecundario(
                '${rolesConfig[s.perfilSolicitado]!.titulo} · ${formatarDataHora(s.dataDecisao ?? s.dataSolicitacao)}',
                cor: const Color(0xFF4B5563),
              ),
              if ((s.motivoDecisao ?? '').isNotEmpty) TextoSecundario('— ${s.motivoDecisao}'),
            ]),
          ),
      ],
    ]);
  }
}
