import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/busca.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/entities/reutilizacao.dart';
import '../../presentation/state/retool_controller.dart';

/// Acima disso a exclusão roda em modo silencioso (um único aviso no fim), como no desktop.
const limiteAvisosIndividuais = 20;

/// Tamanho do lote processado em paralelo (`useBulkProgress(batchSize = 5)` do desktop).
const tamanhoLoteExclusao = 5;

/// Abre "Ações em Massa" (equivalente ao `BulkActionModal` do desktop, sem "Desativar").
Future<void> mostrarAcoesEmMassa(BuildContext context, ValueNotifier<Set<String>> selecao) => showAppSheet<void>(
      context,
      titulo: 'Ações em Massa',
      subtitulo: 'Selecione itens e aplique uma ação',
      rolavel: false,
      builder: (_) => AcoesEmMassaSheet(selecao: selecao),
    );

class AcoesEmMassaSheet extends StatefulWidget {
  final ValueNotifier<Set<String>> selecao;
  const AcoesEmMassaSheet({super.key, required this.selecao});

  @override
  State<AcoesEmMassaSheet> createState() => _AcoesEmMassaSheetState();
}

class _AcoesEmMassaSheetState extends State<AcoesEmMassaSheet> {
  final _busca = TextEditingController();
  bool _carregando = false;
  ({int feitos, int total})? _progresso;

  List<Reutilizacao>? _fonteCache;
  String? _buscaCache;
  List<Reutilizacao> _filtrados = const [];

  @override
  void initState() {
    super.initState();
    widget.selecao.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.selecao.removeListener(_rebuild);
    _busca.dispose();
    super.dispose();
  }

  List<Reutilizacao> _filtrar(ReToolController retool) {
    final fonte = retool.reutilizacoes;
    final q = normalizarBusca(_busca.text).trim();
    if (identical(fonte, _fonteCache) && q == _buscaCache) return _filtrados;
    _fonteCache = fonte;
    _buscaCache = q;
    _filtrados = q.isEmpty
        ? fonte
        : fonte.where((u) {
            final disp = retool.dispositivo(u.dispositivoId);
            return [u.descricaoAlteracao, u.responsavel, u.codigoPeca, u.numeroOs, disp?.nome]
                .any((c) => normalizarBusca(c).contains(q));
          }).toList();
    return _filtrados;
  }

  void _alternar(String id) {
    final novo = {...widget.selecao.value};
    if (!novo.remove(id)) novo.add(id);
    widget.selecao.value = novo;
  }

  void _alternarTodos(List<Reutilizacao> itens) {
    final ids = itens.map((u) => u.id);
    final todos = itens.isNotEmpty && ids.every(widget.selecao.value.contains);
    final novo = {...widget.selecao.value};
    if (todos) {
      novo.removeAll(ids);
    } else {
      novo.addAll(ids);
    }
    widget.selecao.value = novo;
  }

  Future<void> _excluir() async {
    final n = widget.selecao.value.length;
    final ok = await confirmar(
      context,
      titulo: 'Excluir itens',
      mensagem: 'Você está prestes a excluir permanentemente $n item${n > 1 ? 's' : ''}. '
          'Esta ação não pode ser desfeita.',
      confirmarLabel: 'Excluir $n',
      perigoso: true,
    );
    if (!ok || !mounted) return;
    final retool = context.read<ReToolController>();
    final ids = widget.selecao.value.toList();
    final silencioso = ids.length > limiteAvisosIndividuais;
    setState(() {
      _carregando = true;
      _progresso = (feitos: 0, total: ids.length);
    });
    var feitos = 0;
    try {
      for (var i = 0; i < ids.length; i += tamanhoLoteExclusao) {
        final lote = ids.skip(i).take(tamanhoLoteExclusao);
        await Future.wait(lote.map((id) async {
          await retool.deleteReutilizacao(id, silent: silencioso);
          feitos++;
          if (mounted) setState(() => _progresso = (feitos: feitos, total: ids.length));
        }));
      }
      if (mounted) setState(() => _progresso = (feitos: ids.length, total: ids.length));
      // Pequena pausa para o usuário ver 100%.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (silencioso) retool.announce('${ids.length} reutilizações excluídas com sucesso');
    } finally {
      widget.selecao.value = {};
      if (mounted) {
        setState(() => _carregando = false);
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final retool = context.watch<ReToolController>();
    final itens = _filtrar(retool);
    final selecionados = widget.selecao.value;
    final todos = itens.isNotEmpty && itens.every((u) => selecionados.contains(u.id));
    final algum = selecionados.isNotEmpty;

    final conteudo = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 12),
        child: AppSearchField(controller: _busca, hint: 'Buscar item...', onChanged: (_) => setState(() {})),
      ),
      const Divider(),
      Material(
        color: todos ? const Color(0x0AE40D2C) : const Color(0xFFFAFAFA),
        child: InkWell(
          onTap: _carregando ? null : () => _alternarTodos(itens),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 12),
            child: Row(children: [
              Icon(todos ? LucideIcons.squareCheck : LucideIcons.square,
                  size: 18, color: todos ? AppColors.primary : AppColors.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Selecionar todos (${itens.length})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              ),
            ]),
          ),
        ),
      ),
      const Divider(),
      Flexible(
        child: itens.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Text('Nenhum item encontrado',
                    textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: itens.length,
                itemBuilder: (_, i) {
                  final u = itens[i];
                  final sel = selecionados.contains(u.id);
                  final disp = retool.dispositivo(u.dispositivoId);
                  final os = 'OS: ${u.numeroOs.isEmpty ? 'S/OS' : u.numeroOs}';
                  return _ItemSelecao(
                    key: ValueKey('massa-${u.id}'),
                    label: u.descricaoAlteracao.isEmpty ? 'Sem descrição' : u.descricaoAlteracao,
                    sublabel: (disp?.nome?.isNotEmpty ?? false) ? '${disp!.nome} · $os' : os,
                    selecionado: sel,
                    onTap: _carregando ? null : () => _alternar(u.id),
                  );
                },
              ),
      ),
      Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFAFAFA),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 12, AppSpacing.lg, 12),
        child: SafeArea(
          top: false,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text.rich(
                algum
                    ? TextSpan(children: [
                        TextSpan(
                            text: '${selecionados.length}',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
                        TextSpan(text: ' selecionado${selecionados.length > 1 ? 's' : ''}'),
                      ])
                    : const TextSpan(text: 'Nenhum selecionado'),
                style: const TextStyle(fontSize: 13.5, color: AppColors.textSubtle, fontWeight: FontWeight.w500),
              ),
              Row(mainAxisSize: MainAxisSize.min, children: [
                AppButton(
                  label: 'Cancelar',
                  compact: true,
                  onPressed: _carregando ? null : () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 8),
                AppButton.danger(
                  label: 'Excluir',
                  icon: LucideIcons.trash2,
                  compact: true,
                  onPressed: algum && !_carregando ? _excluir : null,
                ),
              ]),
            ],
          ),
        ),
      ),
    ]);

    return PopScope(
      canPop: !_carregando,
      child: Stack(children: [
        conteudo,
        if (_carregando) Positioned.fill(child: _OverlayProgresso(progresso: _progresso, total: selecionados.length)),
      ]),
    );
  }
}

class _ItemSelecao extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool selecionado;
  final VoidCallback? onTap;
  const _ItemSelecao({super.key, required this.label, required this.sublabel, required this.selecionado, this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        checked: selecionado,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(21, 10, AppSpacing.lg, 10),
            decoration: BoxDecoration(
              color: selecionado ? const Color(0x0DE40D2C) : Colors.transparent,
              border: Border(
                left: BorderSide(color: selecionado ? AppColors.primary : Colors.transparent, width: 3),
              ),
            ),
            child: Row(children: [
              Icon(selecionado ? LucideIcons.squareCheck : LucideIcons.square,
                  size: 18, color: selecionado ? AppColors.primary : const Color(0xFFD1D5DB)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: selecionado ? AppColors.primary : AppColors.textDark,
                      )),
                  Text(sublabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                ]),
              ),
            ]),
          ),
        ),
      );
}

/// Sobreposição de carregamento com barra de progresso real (`useBulkProgress`).
class _OverlayProgresso extends StatelessWidget {
  final ({int feitos, int total})? progresso;
  final int total;
  const _OverlayProgresso({required this.progresso, required this.total});

  @override
  Widget build(BuildContext context) {
    final p = progresso;
    return ColoredBox(
      color: const Color(0xF5FFFFFF),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (p != null) ...[
              Text(p.feitos < p.total ? 'Processando itens...' : 'Concluído!',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textDark)),
              const SizedBox(height: 6),
              Text('${p.feitos} de ${p.total} ${p.total == 1 ? 'item' : 'itens'}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
              const SizedBox(height: AppSpacing.md),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: p.total == 0 ? 1 : p.feitos / p.total),
                    duration: const Duration(milliseconds: 250),
                    builder: (_, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 8,
                      backgroundColor: AppColors.border,
                      color: p.feitos == p.total ? AppColors.success : AppColors.primary,
                      semanticsLabel: 'Progresso da exclusão',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text('${p.total == 0 ? 100 : (p.feitos * 100 / p.total).round()}%',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textBody, fontWeight: FontWeight.w600)),
            ] else ...[
              const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3)),
              const SizedBox(height: AppSpacing.md),
              Text('Processando $total ${total == 1 ? 'item' : 'itens'}...',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textDark)),
            ],
            const SizedBox(height: AppSpacing.md),
            const Text('Não feche esta janela', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ]),
        ),
      ),
    );
  }
}
