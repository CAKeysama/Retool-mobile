import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/router/rotas.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/entities/reutilizacao.dart';
import '../../domain/entities/user.dart';
import '../../presentation/shell/app_shell.dart';
import '../../presentation/state/auth_controller.dart';
import '../../presentation/state/retool_controller.dart';
import 'acoes_em_massa_sheet.dart';
import 'filtros_historico_sheet.dart';
import 'fluxo_aceite_sheet.dart';
import 'reutilizacoes_logica.dart';
import 'widgets/abas_pilula.dart';
import 'widgets/cartao_reutilizacao.dart';
import 'widgets/dialogo_motivo.dart';

/// Aba "Reutilizações": filas do fluxo de aceite e histórico geral
/// (equivalente a `pages/Reutilizacoes.tsx` do desktop).
class ReutilizacoesScreen extends StatefulWidget {
  /// Solicitação a destacar (vinda de uma notificação).
  final String? destaqueId;
  const ReutilizacoesScreen({super.key, this.destaqueId});

  @override
  State<ReutilizacoesScreen> createState() => _ReutilizacoesScreenState();
}

class _ReutilizacoesScreenState extends State<ReutilizacoesScreen> {
  final _listas = ListasReutilizacoes();
  final _buscaCtrl = TextEditingController();
  final _selecao = ValueNotifier<Set<String>>(const {});
  final _chaveDestaque = GlobalKey(debugLabel: 'reutilizacao-destacada');
  final Map<AbaReutilizacoes, ScrollController> _rolagens = {
    for (final a in AbaReutilizacoes.values) a: ScrollController(),
  };
  final Set<String> _emAndamento = {};

  AbaReutilizacoes? _abaEscolhida;
  String? _destacarId;
  String? _destaquePendente;
  String? _expandidoId;
  FiltrosHistorico _filtros = const FiltrosHistorico();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _destaquePendente = widget.destaqueId;
  }

  @override
  void didUpdateWidget(covariant ReutilizacoesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.destaqueId != null && widget.destaqueId != oldWidget.destaqueId) {
      _destaquePendente = widget.destaqueId;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _buscaCtrl.dispose();
    _selecao.dispose();
    for (final c in _rolagens.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------------ destaque

  /// Abre a aba certa, rola até o cartão e o destaca (como o `useEffect` do desktop).
  void _aplicarDestaque(String id, PerfilUsuario perfil) {
    _destaquePendente = null;
    final alvo = _listas.todas.where((r) => r.id == id).firstOrNull;
    _destacarId = id;
    if (alvo == null) return;
    final aba = abaParaDestaque(perfil, alvo.status);
    _abaEscolhida = aba;
    if (aba == AbaReutilizacoes.historico) {
      _expandidoId = id;
      if (!_listas.historico(_filtros).any((r) => r.id == id)) {
        // Filtros ocultariam o registro: limpa para mostrá-lo.
        _filtros = const FiltrosHistorico();
        _buscaCtrl.clear();
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _rolarAteDestaque(aba, id, 0));
  }

  void _rolarAteDestaque(AbaReutilizacoes aba, String id, int tentativa) {
    if (!mounted || tentativa > 6) return;
    final alvo = _chaveDestaque.currentContext;
    if (alvo != null) {
      Scrollable.ensureVisible(alvo, alignment: 0.1, duration: const Duration(milliseconds: 300));
      return;
    }
    final ctrl = _rolagens[aba]!;
    final lista = aba == AbaReutilizacoes.historico ? _listas.historico(_filtros) : _listas.fila(aba);
    final indice = lista.indexWhere((r) => r.id == id);
    if (indice < 0 || !ctrl.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _rolarAteDestaque(aba, id, tentativa + 1));
      return;
    }
    // Estimativa pela extensão média já medida; refina até o cartão ser construído.
    final pos = ctrl.position;
    final total = pos.maxScrollExtent + pos.viewportDimension;
    final estimado = total * indice / math.max(lista.length, 1);
    ctrl.jumpTo(estimado.clamp(0, pos.maxScrollExtent));
    WidgetsBinding.instance.addPostFrameCallback((_) => _rolarAteDestaque(aba, id, tentativa + 1));
  }

  // ------------------------------------------------------------------ ações

  Future<void> _executar(Reutilizacao r, AcaoFluxo acao) async {
    String? motivo;
    if (acao.exigeMotivo) {
      motivo = await pedirMotivoNaoAprovacao(context);
      if (motivo == null || motivo.trim().isEmpty || !mounted) return;
    }
    final retool = context.read<ReToolController>();
    setState(() => _emAndamento.add(r.id));
    try {
      await retool.transicionarReutilizacao(r.id, acao.para, motivo: motivo);
    } catch (e) {
      Toasts.mostrar('Não foi possível atualizar o status. Tente novamente.', erro: true);
    } finally {
      if (mounted) setState(() => _emAndamento.remove(r.id));
    }
  }

  Future<void> _excluir(Reutilizacao r) async {
    final ok = await confirmar(
      context,
      titulo: 'Excluir reutilização',
      mensagem: 'Você está prestes a excluir permanentemente "${r.descricaoAlteracao.isEmpty ? 'Sem descrição' : r.descricaoAlteracao}". '
          'Esta ação não pode ser desfeita.',
      confirmarLabel: 'Excluir',
      perigoso: true,
    );
    if (!ok || !mounted) return;
    try {
      await context.read<ReToolController>().deleteReutilizacao(r.id);
      _selecao.value = {..._selecao.value}..remove(r.id);
    } catch (e) {
      Toasts.mostrar('Não foi possível excluir a reutilização. Tente novamente.', erro: true);
    }
  }

  void _abrirDispositivo(String id) => context.push(Rotas.dispositivo(id));

  void _aoBuscar(String texto) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _filtros = _filtros.copyWith(texto: texto));
    });
  }

  Future<void> _abrirFiltros() async {
    final novos = await mostrarFiltrosHistorico(
      context,
      atuais: _filtros,
      dispositivosIds: _listas.dispositivosReferenciados,
    );
    if (novos != null && mounted) setState(() => _filtros = novos.copyWith(texto: _filtros.texto));
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final retool = context.watch<ReToolController>();
    final auth = context.watch<AuthController>();
    final perfil = auth.currentRole;
    _listas.atualizar(retool.reutilizacoes, retool.dispositivos, retool.dispositivo);

    if (_destaquePendente != null && retool.reutilizacoesCarregadas) {
      _aplicarDestaque(_destaquePendente!, perfil);
    }

    final abas = abasDoPerfil(perfil);
    final aba = (_abaEscolhida != null && abas.contains(_abaEscolhida)) ? _abaEscolhida! : abas.first;

    return Scaffold(
      appBar: appBarPadrao(
        context,
        titulo: const Text('Reutilizações'),
        acoes: [
          IconButton(
            tooltip: 'Como funciona o fluxo',
            icon: const Icon(LucideIcons.info, size: 22, color: AppColors.textDark),
            onPressed: () => mostrarFluxoAceite(context),
          ),
        ],
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AbasPilula(
          abas: abas,
          ativa: aba,
          contagens: {
            AbaReutilizacoes.filaProjetista: _listas.filaProjetista.length,
            AbaReutilizacoes.filaEngenharia: _listas.filaEngenharia.length,
          },
          onSelecionar: (a) => setState(() => _abaEscolhida = a),
        ),
        Expanded(
          child: !retool.reutilizacoesCarregadas
              ? const SkeletonList()
              : aba.ehFila
                  ? _fila(aba, perfil, retool)
                  : _historico(perfil, auth.canExcluir, retool),
        ),
      ]),
    );
  }

  Widget _cartao(
    Reutilizacao r,
    ReToolController retool, {
    required bool fila,
    required PerfilUsuario perfil,
    bool podeExcluir = false,
  }) {
    final destacado = r.id == _destacarId;
    Widget construir(Set<String>? selecao) => CartaoReutilizacao(
          key: ValueKey('reu-${r.id}'),
          reutilizacao: r,
          dispositivo: retool.dispositivo(r.dispositivoId),
          produtoNome: retool.produto(r.produtoId)?.nome,
          destacado: destacado,
          estiloFila: fila,
          expandido: _expandidoId == r.id,
          onAlternar: () => setState(() => _expandidoId = _expandidoId == r.id ? null : r.id),
          onAbrirDispositivo: r.dispositivoId.isEmpty ? null : () => _abrirDispositivo(r.dispositivoId),
          // Transições somente nas abas de fila (como no desktop).
          acoes: fila ? acoesDeFluxo(perfil, r.status) : const [],
          ocupado: _emAndamento.contains(r.id),
          onAcao: (a) => _executar(r, a),
          selecionado: selecao?.contains(r.id),
          onSelecionar: selecao == null
              ? null
              : (v) {
                  final novo = {..._selecao.value};
                  v ? novo.add(r.id) : novo.remove(r.id);
                  _selecao.value = novo;
                },
          onExcluir: podeExcluir ? () => _excluir(r) : null,
        );
    final cartao = podeExcluir
        ? ValueListenableBuilder<Set<String>>(valueListenable: _selecao, builder: (_, s, _) => construir(s))
        : construir(null);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: destacado ? KeyedSubtree(key: _chaveDestaque, child: cartao) : cartao,
    );
  }

  Widget _fila(AbaReutilizacoes aba, PerfilUsuario perfil, ReToolController retool) {
    final itens = _listas.fila(aba);
    if (itens.isEmpty) {
      return const EmptyState(icon: LucideIcons.inbox, titulo: 'Sem pendências no momento.');
    }
    final pendentes = _listas.pendentes(aba, perfil);
    final temBanner = pendentes > 0;
    return ListView.builder(
      key: PageStorageKey('lista-${aba.name}'),
      controller: _rolagens[aba],
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.lg),
      itemCount: itens.length + (temBanner ? 1 : 0),
      itemBuilder: (_, i) {
        if (temBanner && i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _BannerPendencias(aba: aba, quantidade: pendentes),
          );
        }
        final r = itens[i - (temBanner ? 1 : 0)];
        return _cartao(r, retool, fila: true, perfil: perfil);
      },
    );
  }

  Widget _historico(PerfilUsuario perfil, bool podeExcluir, ReToolController retool) {
    final itens = _listas.historico(_filtros);
    final ativos = filtrosAtivosDescritos(_filtros, retool);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Toolbar da tabela (contagem + Ações em Massa).
      Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 8, AppSpacing.md, 8),
        decoration: const BoxDecoration(
          color: Color(0xFFFAFAFA),
          border: Border(top: BorderSide(color: AppColors.border), bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(children: [
          Expanded(
            child: ValueListenableBuilder<Set<String>>(
              valueListenable: _selecao,
              builder: (_, sel, _) => Text.rich(
                TextSpan(children: [
                  TextSpan(text: '${itens.length} ${itens.length == 1 ? 'registro' : 'registros'}'),
                  if (sel.isNotEmpty) ...[
                    const TextSpan(text: ' · '),
                    TextSpan(
                        text: '${sel.length} selecionado(s)', style: const TextStyle(color: AppColors.primary)),
                  ],
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
              ),
            ),
          ),
          if (podeExcluir)
            AppButton(
              label: 'Ações em Massa',
              icon: LucideIcons.listChecks,
              compact: true,
              onPressed: () => mostrarAcoesEmMassa(context, _selecao),
            ),
        ]),
      ),
      // Filtros vinculados ao histórico.
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 12, AppSpacing.md, 4),
        child: Row(children: [
          Expanded(
            child: AppSearchField(
              controller: _buscaCtrl,
              hint: 'Buscar por descrição, peça, solicitante ou OS...',
              onChanged: _aoBuscar,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Badge(
            isLabelVisible: _filtros.ativos > 0,
            backgroundColor: AppColors.primary,
            label: Text('${_filtros.ativos}'),
            child: AppIconButton(
              key: const ValueKey('abrir-filtros'),
              icon: LucideIcons.slidersHorizontal,
              tooltip: _filtros.ativos > 0 ? 'Filtros (${_filtros.ativos} ativos)' : 'Filtros',
              size: 46,
              onPressed: _abrirFiltros,
            ),
          ),
        ]),
      ),
      if (ativos.isNotEmpty)
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 6, AppSpacing.md, 2),
            children: [
              for (final f in ativos) ...[
                InputChip(
                  label: Text(f.rotulo, style: const TextStyle(fontSize: 12.5)),
                  visualDensity: VisualDensity.compact,
                  deleteIcon: const Icon(LucideIcons.x, size: 14),
                  deleteButtonTooltipMessage: 'Remover filtro',
                  onDeleted: () => setState(() => _filtros = f.semEste),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
      Expanded(
        child: itens.isEmpty
            ? EmptyState(
                icon: LucideIcons.searchX,
                titulo: _listas.todas.isEmpty
                    ? 'Nenhuma reutilização registrada.'
                    : 'Nenhum registro encontrado para os filtros atuais.',
                acao: _filtros.vazio
                    ? null
                    : AppButton(
                        label: 'Limpar filtros',
                        compact: true,
                        onPressed: () => setState(() {
                          _filtros = const FiltrosHistorico();
                          _buscaCtrl.clear();
                        }),
                      ),
              )
            : ListView.builder(
                key: const PageStorageKey('lista-historico'),
                controller: _rolagens[AbaReutilizacoes.historico],
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, 8, AppSpacing.md, AppSpacing.lg),
                itemCount: itens.length,
                itemBuilder: (_, i) =>
                    _cartao(itens[i], retool, fila: false, perfil: perfil, podeExcluir: podeExcluir),
              ),
      ),
    ]);
  }
}

/// Aviso de pendências para quem tem ação a executar na fila.
class _BannerPendencias extends StatelessWidget {
  final AbaReutilizacoes aba;
  final int quantidade;
  const _BannerPendencias({required this.aba, required this.quantidade});

  @override
  Widget build(BuildContext context) {
    final itens = quantidade == 1 ? '1 solicitação aguarda' : '$quantidade solicitações aguardam';
    final oQue = aba == AbaReutilizacoes.filaProjetista ? 'sua análise' : 'sua ação';
    return InfoBox(
      tipo: InfoBoxTipo.aviso,
      titulo: 'Pendências',
      mensagem: '$itens $oQue nesta fila.',
    );
  }
}
