import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/router/rotas.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/entities/dispositivo.dart';
import '../../domain/entities/reutilizacao.dart';
import '../../presentation/state/auth_controller.dart';
import '../../presentation/state/retool_controller.dart';
import '../reutilizacoes/solicitar/solicitar_reutilizacao_sheet.dart';
import 'detalhes/ficha_tecnica.dart';
import 'detalhes/historico_reutilizacoes.dart';
import 'detalhes/navegacao.dart';

/// Detalhes do dispositivo (equivalente a `DispositivoDetails.tsx`): ficha técnica,
/// mídias, resumo de reutilizações e histórico expansível.
class DispositivoDetalhesScreen extends StatefulWidget {
  final String id;
  const DispositivoDetalhesScreen({super.key, required this.id});

  @override
  State<DispositivoDetalhesScreen> createState() => _DispositivoDetalhesScreenState();
}

class _DispositivoDetalhesScreenState extends State<DispositivoDetalhesScreen> {
  String? _expandidoId;
  bool _excluindo = false;

  // Memoização do histórico: reordena só quando a lista do controller muda.
  List<Reutilizacao>? _origemHistorico;
  List<Reutilizacao> _historico = const [];
  double _hardSavingTotal = 0;

  void _atualizarHistorico(List<Reutilizacao> origem) {
    if (identical(origem, _origemHistorico)) return;
    _origemHistorico = origem;
    _historico = ordenarHistoricoReutilizacoes(origem);
    _hardSavingTotal = origem.fold(0.0, (s, r) => s + r.hardSaving);
  }

  Future<void> _excluir(Dispositivo d) async {
    final nome = d.nome ?? d.codigo ?? 'este dispositivo';
    final ok = await confirmar(
      context,
      titulo: 'Excluir dispositivo',
      mensagem:
          'Deseja excluir "$nome"? As reutilizações e os arquivos associados também serão removidos. '
          'Esta ação não pode ser desfeita.',
      confirmarLabel: 'Excluir',
      perigoso: true,
    );
    if (!ok || !mounted) return;
    final retool = context.read<ReToolController>();
    setState(() => _excluindo = true);
    try {
      await retool.deleteDispositivo(d.id);
      if (mounted) voltarDaTelaDeDispositivo(context);
    } catch (_) {
      if (mounted) setState(() => _excluindo = false);
      Toasts.mostrar('Erro ao excluir o dispositivo.', erro: true);
    }
  }

  Future<void> _excluirReutilizacao(Reutilizacao r) async {
    final ok = await confirmar(
      context,
      titulo: 'Excluir reutilização',
      mensagem: 'Apagar esta reutilização?',
      confirmarLabel: 'Excluir',
      perigoso: true,
    );
    if (!ok || !mounted) return;
    await context.read<ReToolController>().deleteReutilizacao(r.id);
  }

  @override
  Widget build(BuildContext context) {
    final retool = context.watch<ReToolController>();
    final auth = context.watch<AuthController>();
    final disp = retool.dispositivo(widget.id);

    if (!retool.dispositivosCarregados || (_excluindo && disp == null)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dispositivo')),
        body: const LoadingView(mensagem: 'Carregando dispositivo...'),
      );
    }
    if (disp == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dispositivo')),
        body: EmptyState(
          icon: LucideIcons.searchX,
          titulo: 'Dispositivo não encontrado',
          descricao: 'Ele pode ter sido removido ou o link está incorreto.',
          acao: AppButton.primary(
            label: 'Voltar',
            icon: LucideIcons.arrowLeft,
            onPressed: () => voltarDaTelaDeDispositivo(context),
          ),
        ),
      );
    }

    _atualizarHistorico(retool.reutilizacoesDo(disp.id));
    final historico = _historico;
    final categoria = retool.categoria(disp.categoriaId)?.nome;
    final familia = retool.familia(disp.familiaId)?.nome;
    final produto = retool.produto(disp.produtoId)?.nome;
    final ultima = historico.firstOrNull;
    final primeira = historico.lastOrNull;

    final acoesHistorico = <Widget>[
      if (auth.canCadastrar)
        AppButton.primary(
          label: 'Nova Reutilização',
          icon: LucideIcons.plus,
          onPressed: () => mostrarSolicitarReutilizacao(context, dispositivoId: disp.id, registroDireto: true),
        ),
      if (auth.canSolicitar)
        BotaoSolicitarReutilizacao(onPressed: () => mostrarSolicitarReutilizacao(context, dispositivoId: disp.id)),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(disp.nome?.isNotEmpty == true ? disp.nome! : 'Sem Nome', overflow: TextOverflow.ellipsis),
        actions: [
          if (auth.canEditar)
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(LucideIcons.squarePen, size: 20),
              onPressed: () => context.push(Rotas.editarDispositivo(disp.id)),
            ),
          if (auth.canExcluir)
            IconButton(
              tooltip: 'Excluir dispositivo',
              icon: const Icon(LucideIcons.trash2, size: 20, color: AppColors.danger),
              onPressed: _excluindo ? null : () => _excluir(disp),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            sliver: SliverList.list(
              children: [
                _Cabecalho(dispositivo: disp),
                const SizedBox(height: AppSpacing.md),
                FichaTecnicaCard(dispositivo: disp, categoria: categoria, familia: familia, produto: produto),
                const SizedBox(height: AppSpacing.md),
                ResumoDispositivoCard(
                  totalReutilizacoes: historico.length,
                  hardSavingTotal: _hardSavingTotal,
                  primeira: primeira == null ? null : dataDaReutilizacao(primeira),
                  ultima: ultima == null ? null : dataDaReutilizacao(ultima),
                  categoria: categoria,
                  familia: familia,
                  dataCriacao: disp.dataCriacao,
                ),
                const SizedBox(height: AppSpacing.lg),
                CabecalhoHistorico(acoes: acoesHistorico),
                const SizedBox(height: AppSpacing.md),
                if (historico.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Text(
                      'Nenhuma reutilização registrada ainda.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                    ),
                  ),
              ],
            ),
          ),
          if (historico.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverList.separated(
                itemCount: historico.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final r = historico[i];
                  return CartaoReutilizacao(
                    key: ValueKey(r.id),
                    reutilizacao: r,
                    numero: historico.length - i,
                    maisRecente: i == 0,
                    aberto: _expandidoId == r.id,
                    nomeProduto: retool.produto(r.produtoId)?.nome,
                    onAlternar: () => setState(() => _expandidoId = _expandidoId == r.id ? null : r.id),
                    onExcluir: auth.canExcluir ? () => _excluirReutilizacao(r) : null,
                  );
                },
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
              sliver: SliverToBoxAdapter(
                child: RodapeHistorico(total: historico.length, hardSaving: _hardSavingTotal),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
        ],
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  final Dispositivo dispositivo;
  const _Cabecalho({required this.dispositivo});

  @override
  Widget build(BuildContext context) {
    final d = dispositivo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            d.nome?.isNotEmpty == true ? d.nome! : 'Sem Nome',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Flexible(
              child: Text(
                d.codigo?.isNotEmpty == true ? d.codigo! : 'S/C',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            StatusDispositivoPill(ativo: d.ativo),
          ],
        ),
      ],
    );
  }
}
