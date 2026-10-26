import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/router/rotas.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/entities/classificacao.dart';
import '../../domain/entities/dispositivo.dart';
import '../../presentation/shell/app_shell.dart';
import '../../presentation/state/auth_controller.dart';
import '../../presentation/state/retool_controller.dart';
import 'importacao/importacao_sheet.dart';
import 'lista/acoes_em_massa.dart';
import 'lista/dispositivo_card.dart';
import 'lista/duplicados_sheet.dart';
import 'lista/filtro_dispositivos.dart';
import 'lista/filtros_sheet.dart';

/// Lista de dispositivos (`Dispositivos.tsx` + `useDispositivosController` do desktop):
/// busca com debounce, filtros, rolagem incremental, seleção em massa (toque longo),
/// importação de planilha e verificação de duplicados.
class DispositivosScreen extends StatefulWidget {
  final String? buscaInicial;
  const DispositivosScreen({super.key, this.buscaInicial});

  @override
  State<DispositivosScreen> createState() => _DispositivosScreenState();
}

class _DispositivosScreenState extends State<DispositivosScreen> {
  /// Itens acrescentados a cada "página" da rolagem infinita.
  static const _pagina = 40;

  late final TextEditingController _busca = TextEditingController(text: widget.buscaInicial ?? '');
  late FiltrosDispositivos _filtros = FiltrosDispositivos(query: widget.buscaInicial ?? '');
  final ScrollController _scroll = ScrollController();
  Timer? _debounce;
  int _limite = _pagina;

  bool _modoSelecao = false;
  final Set<String> _selecionados = {};

  // Memo do resultado filtrado: recalcula só quando dados ou filtros mudam.
  List<Dispositivo>? _memoDisp;
  List<Classificacao>? _memoCat, _memoFam, _memoProd;
  FiltrosDispositivos? _memoFiltros;
  List<Dispositivo> _filtrados = const [];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_aoRolar);
  }

  @override
  void didUpdateWidget(DispositivosScreen old) {
    super.didUpdateWidget(old);
    // Busca vinda da Home (`/dispositivos?q=...`) com a aba já aberta.
    final q = widget.buscaInicial;
    if (q != null && q != old.buscaInicial) {
      _debounce?.cancel();
      _busca.text = q;
      _aplicar(_filtros.copyWith(query: q));
      _sairSelecao();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _busca.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _aoRolar() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    if (p.pixels >= p.maxScrollExtent - 600 && _limite < _filtrados.length) {
      setState(() => _limite += _pagina);
    }
  }

  void _aplicar(FiltrosDispositivos f) {
    if (f == _filtros) return;
    setState(() {
      _filtros = f;
      _limite = _pagina;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _aoDigitar(String valor) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) _aplicar(_filtros.copyWith(query: valor));
    });
  }

  List<Dispositivo> _resultado(ReToolController r) {
    if (!identical(_memoDisp, r.dispositivos) ||
        !identical(_memoCat, r.categorias) ||
        !identical(_memoFam, r.familias) ||
        !identical(_memoProd, r.produtos) ||
        _memoFiltros != _filtros) {
      _memoDisp = r.dispositivos;
      _memoCat = r.categorias;
      _memoFam = r.familias;
      _memoProd = r.produtos;
      _memoFiltros = _filtros;
      _filtrados = filtrarDispositivos(r, _filtros);
    }
    return _filtrados;
  }

  // ---------------------------------------------------------------- seleção

  bool _podeSelecionar(AuthController auth) => auth.canEditar || auth.canExcluir;

  void _entrarSelecao([String? id]) {
    setState(() {
      _modoSelecao = true;
      if (id != null) _selecionados.add(id);
    });
  }

  void _alternar(String id) {
    setState(() {
      if (!_selecionados.remove(id)) _selecionados.add(id);
      if (_selecionados.isEmpty) _modoSelecao = false;
    });
  }

  void _sairSelecao() {
    if (!_modoSelecao && _selecionados.isEmpty) return;
    setState(() {
      _modoSelecao = false;
      _selecionados.clear();
    });
  }

  void _alternarTodos(List<Dispositivo> visiveis) {
    final ids = visiveis.map((d) => d.id);
    setState(() {
      final todos = ids.isNotEmpty && ids.every(_selecionados.contains);
      if (todos) {
        _selecionados.removeAll(ids);
      } else {
        _selecionados.addAll(ids);
      }
    });
  }

  Future<void> _executar(AcaoEmMassa acao) async {
    final retool = context.read<ReToolController>();
    final selecionados = _selecionados.map(retool.dispositivo).whereType<Dispositivo>();
    final ids = switch (acao) {
      AcaoEmMassa.desativar => selecionados.where((d) => d.ativo),
      AcaoEmMassa.ativar => selecionados.where((d) => !d.ativo),
      AcaoEmMassa.excluir => selecionados,
    }.map((d) => d.id).toList();
    if (ids.isEmpty) return;
    if (!await confirmarAcaoEmMassa(context, acao, ids.length) || !mounted) return;

    final r = await executarComProgresso(
      context,
      ids,
      (id) => switch (acao) {
        AcaoEmMassa.desativar => retool.updateDispositivo(id, {'ativo': false}, silent: true),
        AcaoEmMassa.ativar => retool.updateDispositivo(id, {'ativo': true}, silent: true),
        AcaoEmMassa.excluir => retool.deleteDispositivo(id, silent: true),
      },
    );
    retool.announce(acao.resumo(r.sucesso, r.erros));
    if (mounted) _sairSelecao();
  }

  // ---------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final retool = context.watch<ReToolController>();
    final auth = context.watch<AuthController>();
    final lista = _resultado(retool);
    final podeSelecionar = _podeSelecionar(auth);
    final emSelecao = _modoSelecao && podeSelecionar;

    return PopScope(
      canPop: !emSelecao,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _sairSelecao();
      },
      child: Scaffold(
        appBar: emSelecao ? _appBarSelecao(lista) : _appBarPadrao(auth),
        floatingActionButton: auth.canCadastrar && !emSelecao
            ? FloatingActionButton(
                heroTag: 'fab-novo-dispositivo',
                tooltip: 'Cadastrar novo dispositivo',
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
                onPressed: () => context.push(Rotas.novoDispositivo),
                child: const Icon(LucideIcons.plus, size: 24),
              )
            : null,
        bottomNavigationBar: emSelecao ? _barraAcoes(retool, auth) : null,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _cabecalho(retool, lista.length),
            Expanded(child: _corpo(retool, auth, lista, podeSelecionar, emSelecao)),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _appBarPadrao(AuthController auth) {
    final podeImportar = auth.canCadastrar || auth.canEditar;
    final podeSelecionar = _podeSelecionar(auth);
    final acoes = <PopupMenuEntry<String>>[
      if (podeSelecionar)
        const PopupMenuItem(value: 'selecionar', child: _ItemMenu(LucideIcons.listChecks, 'Selecionar vários')),
      if (podeImportar)
        const PopupMenuItem(value: 'importar', child: _ItemMenu(LucideIcons.upload, 'Importar planilha')),
      if (auth.isAdmin)
        const PopupMenuItem(value: 'duplicados', child: _ItemMenu(LucideIcons.copyX, 'Verificar duplicados')),
    ];
    return appBarPadrao(
      context,
      acoes: [
        if (acoes.isNotEmpty)
          PopupMenuButton<String>(
            tooltip: 'Mais ações',
            icon: const Icon(LucideIcons.ellipsisVertical, size: 22, color: AppColors.textDark),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            color: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            onSelected: (v) {
              switch (v) {
                case 'selecionar':
                  _entrarSelecao();
                case 'importar':
                  mostrarImportacaoPlanilha(context);
                case 'duplicados':
                  mostrarDuplicados(context);
              }
            },
            itemBuilder: (_) => acoes,
          ),
      ],
    );
  }

  PreferredSizeWidget _appBarSelecao(List<Dispositivo> visiveis) {
    final n = _selecionados.length;
    final todos = visiveis.isNotEmpty && visiveis.every((d) => _selecionados.contains(d.id));
    return AppBar(
      backgroundColor: const Color(0xFFFFF5F6),
      leading: IconButton(
        tooltip: 'Cancelar seleção',
        icon: const Icon(LucideIcons.x, size: 22),
        onPressed: _sairSelecao,
      ),
      title: Text(
        n == 0 ? 'Nenhum selecionado' : (n == 1 ? '1 selecionado' : '$n selecionados'),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
      ),
      actions: [
        TextButton.icon(
          onPressed: visiveis.isEmpty ? null : () => _alternarTodos(visiveis),
          icon: Icon(todos ? LucideIcons.squareCheck : LucideIcons.square, size: 18),
          label: Text(todos ? 'Desmarcar' : 'Todos (${visiveis.length})'),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }

  Widget _barraAcoes(ReToolController retool, AuthController auth) {
    final sel = _selecionados.map(retool.dispositivo).whereType<Dispositivo>().toList();
    final ativos = sel.where((d) => d.ativo).length;
    final inativos = sel.length - ativos;
    final botoes = <Widget>[
      // "Desativar" age sobre os ativos selecionados; "Ativar" aparece quando há inativos.
      if (auth.canEditar && (ativos > 0 || sel.isEmpty))
        _BotaoDesativar(habilitado: ativos > 0, onPressed: () => _executar(AcaoEmMassa.desativar)),
      if (auth.canEditar && inativos > 0)
        AppButton(
          label: 'Ativar',
          icon: LucideIcons.power,
          compact: true,
          expand: true,
          variant: AppButtonVariant.success,
          onPressed: () => _executar(AcaoEmMassa.ativar),
        ),
      if (auth.canExcluir)
        AppButton.danger(
          label: 'Excluir',
          icon: LucideIcons.trash2,
          compact: true,
          expand: true,
          onPressed: sel.isEmpty ? null : () => _executar(AcaoEmMassa.excluir),
        ),
    ];
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 10, AppSpacing.md, 10),
          // Altura fixa: os botões expandidos não podem esticar a barra pela tela toda.
          child: SizedBox(
            height: 40,
            child: Row(
              children: [
                for (final (i, b) in botoes.indexed) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.sm),
                  Expanded(child: b),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cabecalho(ReToolController retool, int total) {
    final categoria = retool.categoria(_filtros.categoriaId);
    final chips = <Widget>[
      if (_filtros.categoriaId != null)
        _ChipFiltro(
          label: 'Categoria: ${categoria?.nome ?? 'Não informado'}',
          onRemover: () => _aplicar(_filtros.copyWith(categoriaId: () => null)),
        ),
      if (_filtros.processo != null)
        _ChipFiltro(
          label: 'Processo: ${_filtros.processo}',
          onRemover: () => _aplicar(_filtros.copyWith(processo: () => null)),
        ),
      if (_filtros.status != FiltroStatus.todos)
        _ChipFiltro(
          label: _filtros.status.rotulo,
          onRemover: () => _aplicar(_filtros.copyWith(status: FiltroStatus.todos)),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: const Text(
              'Dispositivos',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textDark, height: 1.15),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            retool.dispositivosCarregados ? rotuloEncontrados(total) : 'Carregando dispositivos...',
            style: const TextStyle(fontSize: 14, color: AppColors.textBody),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppSearchField(
                  controller: _busca,
                  hint: 'Buscar por nome ou código...',
                  onChanged: _aoDigitar,
                  onSubmitted: (v) {
                    _debounce?.cancel();
                    _aplicar(_filtros.copyWith(query: v));
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _BotaoFiltros(
                ativos: _filtros.ativos,
                onPressed: () => mostrarFiltrosDispositivos(context, atual: _filtros, onChanged: _aplicar),
              ),
            ],
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: chips),
          ],
        ],
      ),
    );
  }

  Widget _corpo(
    ReToolController retool,
    AuthController auth,
    List<Dispositivo> lista,
    bool podeSelecionar,
    bool emSelecao,
  ) {
    if (!retool.dispositivosCarregados) return const SingleChildScrollView(child: SkeletonList());

    if (retool.dispositivos.isEmpty) {
      return EmptyState(
        icon: LucideIcons.box,
        titulo: 'Nenhum dispositivo cadastrado',
        descricao: auth.canCadastrar
            ? 'Cadastre o primeiro dispositivo ou importe uma planilha.'
            : 'Os dispositivos cadastrados aparecerão aqui.',
        acao: auth.canCadastrar
            ? AppButton.primary(
                label: 'Cadastrar dispositivo',
                icon: LucideIcons.plus,
                onPressed: () => context.push(Rotas.novoDispositivo),
              )
            : null,
      );
    }

    if (lista.isEmpty) {
      return EmptyState(
        icon: LucideIcons.searchX,
        titulo: 'Nenhum item encontrado.',
        descricao: 'Ajuste a busca ou os filtros para encontrar o dispositivo.',
        acao: AppButton(
          label: 'Limpar busca e filtros',
          icon: LucideIcons.x,
          onPressed: () {
            _debounce?.cancel();
            _busca.clear();
            _aplicar(const FiltrosDispositivos());
          },
        ),
      );
    }

    final mostrados = lista.length < _limite ? lista.length : _limite;
    final temMais = mostrados < lista.length;
    return Scrollbar(
      controller: _scroll,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, 96),
        itemCount: mostrados + (temMais ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= mostrados) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))),
            );
          }
          final d = lista[i];
          final selecionado = _selecionados.contains(d.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: DispositivoCard(
              key: ValueKey(d.id),
              dispositivo: d,
              categoria: retool.categoria(d.categoriaId)?.nome,
              familia: retool.familia(d.familiaId)?.nome,
              produto: retool.produto(d.produtoId)?.nome,
              reutilizacoes: retool.reutilizacoesDo(d.id).length,
              modoSelecao: emSelecao,
              selecionado: selecionado,
              onTap: emSelecao ? () => _alternar(d.id) : () => context.push(Rotas.dispositivo(d.id)),
              onLongPress: !podeSelecionar
                  ? null
                  : emSelecao
                  ? () => _alternar(d.id)
                  : () => _entrarSelecao(d.id),
            ),
          );
        },
      ),
    );
  }
}

class _ItemMenu extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ItemMenu(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: AppColors.textBody),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14.5, color: AppColors.textDark),
        ),
      ),
    ],
  );
}

/// Botão "Filtros" do desktop (ícone de funil + contador de filtros ativos).
class _BotaoFiltros extends StatelessWidget {
  final int ativos;
  final VoidCallback onPressed;
  const _BotaoFiltros({required this.ativos, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final ativo = ativos > 0;
    return Semantics(
      button: true,
      label: ativo ? 'Filtros ($ativos ativos)' : 'Filtros',
      excludeSemantics: true,
      child: Material(
        color: ativo ? AppColors.primarySoft : AppColors.surface,
        shape: StadiumBorder(side: BorderSide(color: ativo ? AppColors.primary : AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.filter, size: 16, color: ativo ? AppColors.primary : AppColors.textBody),
                  const SizedBox(width: 6),
                  Text(
                    'Filtros',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: ativo ? AppColors.primary : AppColors.textBody,
                    ),
                  ),
                  if (ativo) ...[const SizedBox(width: 6), CountBadge(ativos)],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipFiltro extends StatelessWidget {
  final String label;
  final VoidCallback onRemover;
  const _ChipFiltro({required this.label, required this.onRemover});

  @override
  Widget build(BuildContext context) => InputChip(
    label: Text(label, overflow: TextOverflow.ellipsis),
    labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary),
    backgroundColor: AppColors.primarySoft,
    side: BorderSide.none,
    visualDensity: VisualDensity.compact,
    deleteIcon: const Icon(LucideIcons.x, size: 14, color: AppColors.primary),
    deleteButtonTooltipMessage: 'Remover filtro',
    onDeleted: onRemover,
  );
}

/// Botão "Desativar" no tom âmbar do desktop (`--various04`).
class _BotaoDesativar extends StatelessWidget {
  final bool habilitado;
  final VoidCallback onPressed;
  const _BotaoDesativar({required this.habilitado, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    const cor = AppColors.various04;
    return Opacity(
      opacity: habilitado ? 1 : 0.5,
      child: Material(
        color: AppColors.surface,
        shape: const StadiumBorder(side: BorderSide(color: cor)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: habilitado ? onPressed : null,
          child: const SizedBox(
            height: 36,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.powerOff, size: 16, color: cor),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Desativar',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: cor, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
