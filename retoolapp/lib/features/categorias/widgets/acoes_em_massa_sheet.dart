import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/busca.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/classificacao.dart';
import '../../../presentation/state/auth_controller.dart';
import '../../../presentation/state/retool_controller.dart';
import '../classificacoes_regras.dart';

/// Ações em massa de um painel (equivalente ao `BulkActionModal` do desktop).
Future<void> abrirAcoesEmMassa(BuildContext context, TipoClassificacao tipo, Map<String, int> vinculos) =>
    showAppSheet<void>(
      context,
      titulo: 'Ações em Massa',
      subtitulo: '${tipo.tituloPainel} · Selecione itens e aplique uma ação',
      rolavel: false,
      builder: (_) => AcoesEmMassa(tipo: tipo, vinculos: vinculos),
    );

enum AcaoEmMassa { desativar, ativar, excluir }

class AcoesEmMassa extends StatefulWidget {
  final TipoClassificacao tipo;
  final Map<String, int> vinculos;
  const AcoesEmMassa({super.key, required this.tipo, required this.vinculos});

  @override
  State<AcoesEmMassa> createState() => _AcoesEmMassaState();
}

class _AcoesEmMassaState extends State<AcoesEmMassa> {
  final _busca = TextEditingController();
  final Set<String> _selecionados = {};
  String _q = '';
  Timer? _debounce;

  /// Progresso real da execução (null = parado).
  ({int feitos, int total})? _progresso;

  @override
  void dispose() {
    _debounce?.cancel();
    _busca.dispose();
    super.dispose();
  }

  void _aoBuscar(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _q = normalizarBusca(v).trim());
    });
  }

  String _itens(int n) => '$n ${n == 1 ? 'item' : 'itens'}';

  Future<void> _executar(AcaoEmMassa acao, List<Classificacao> todos) async {
    final retool = context.read<ReToolController>();
    final tipo = widget.tipo;
    final porId = {for (final c in todos) c.id: c};
    final alvos = [
      for (final id in _selecionados)
        if (porId[id] case final c?)
          if (acao == AcaoEmMassa.excluir || (acao == AcaoEmMassa.desativar ? c.ativo : !c.ativo)) c,
    ];
    if (alvos.isEmpty) {
      retool.announce(
        acao == AcaoEmMassa.desativar
            ? 'Os itens selecionados já estão inativos.'
            : 'Os itens selecionados já estão ativos.',
      );
      return;
    }

    final n = alvos.length;
    final vinculados = alvos.fold<int>(0, (s, c) => s + (widget.vinculos[c.id] ?? 0));
    final ok = await confirmar(
      context,
      titulo: switch (acao) {
        AcaoEmMassa.desativar => 'Desativar itens',
        AcaoEmMassa.ativar => 'Ativar itens',
        AcaoEmMassa.excluir => 'Excluir itens',
      },
      mensagem: switch (acao) {
        AcaoEmMassa.desativar =>
          'Você está prestes a desativar ${_itens(n)}. Eles não serão excluídos, mas ficarão inativos no sistema.',
        AcaoEmMassa.ativar =>
          'Você está prestes a reativar ${_itens(n)}. Eles voltarão a ficar disponíveis no cadastro de dispositivos.',
        AcaoEmMassa.excluir =>
          'Você está prestes a excluir permanentemente ${_itens(n)}. Esta ação não pode ser desfeita.'
              '${vinculados > 0 ? '\n\nAtenção: $vinculados dispositivo(s) usam os itens selecionados e ficarão sem ${tipo.rotuloMin} válid${tipo.feminino ? 'a' : 'o'}.' : ''}',
      },
      confirmarLabel: switch (acao) {
        AcaoEmMassa.desativar => 'Desativar $n',
        AcaoEmMassa.ativar => 'Ativar $n',
        AcaoEmMassa.excluir => 'Excluir $n',
      },
      perigoso: acao != AcaoEmMassa.ativar,
    );
    if (!ok || !mounted) return;

    final navigator = Navigator.of(context);
    setState(() => _progresso = (feitos: 0, total: n));
    var feitos = 0, erros = 0;
    // Lotes de 5 em paralelo, como o `useBulkProgress` do desktop; toasts individuais silenciados.
    for (var i = 0; i < n; i += 5) {
      final lote = alvos.skip(i).take(5);
      await Future.wait(
        lote.map((c) async {
          try {
            switch (acao) {
              case AcaoEmMassa.desativar:
                await retool.updateClassificacao(tipo, c.id, {'ativo': false}, silent: true);
              case AcaoEmMassa.ativar:
                await retool.updateClassificacao(tipo, c.id, {'ativo': true}, silent: true);
              case AcaoEmMassa.excluir:
                await retool.deleteClassificacao(tipo, c.id, silent: true);
            }
          } catch (_) {
            erros++;
          }
          feitos++;
          if (mounted) setState(() => _progresso = (feitos: feitos, total: n));
        }),
      );
    }
    // Pequena pausa para o usuário ver 100%.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final sucesso = n - erros;
    final verbo = switch (acao) {
      AcaoEmMassa.desativar => tipo.participio('desativad', sucesso),
      AcaoEmMassa.ativar => tipo.participio('ativad', sucesso),
      AcaoEmMassa.excluir => tipo.participio('excluíd', sucesso),
    };
    retool.announce(
      erros == 0
          ? '${tipo.contagem(sucesso)} $verbo com sucesso'
          : '${tipo.contagem(sucesso)} $verbo; $erros com erro. Tente novamente.',
    );
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final retool = context.watch<ReToolController>();
    final auth = context.watch<AuthController>();
    final todos = retool.classificacoes(widget.tipo);
    final visiveis = _q.isEmpty
        ? todos
        : [
            for (final c in todos)
              if (normalizarBusca(c.nome).contains(_q)) c,
          ];
    final todosMarcados = visiveis.isNotEmpty && visiveis.every((c) => _selecionados.contains(c.id));
    final algum = _selecionados.isNotEmpty;
    final progresso = _progresso;

    final conteudo = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
          child: AppSearchField(controller: _busca, hint: 'Buscar item...', onChanged: _aoBuscar),
        ),
        InkWell(
          onTap: () => setState(() {
            final ids = visiveis.map((c) => c.id);
            todosMarcados ? _selecionados.removeAll(ids) : _selecionados.addAll(ids);
          }),
          child: Container(
            color: todosMarcados ? const Color(0x0AE40D2C) : const Color(0xFFFAFAFA),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
            child: Row(
              children: [
                Icon(
                  todosMarcados ? LucideIcons.squareCheck : LucideIcons.square,
                  size: 18,
                  color: todosMarcados ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 10),
                Text(
                  'Selecionar todos (${visiveis.length})',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
                ),
              ],
            ),
          ),
        ),
        const Divider(),
        Flexible(
          child: visiveis.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    'Nenhum item encontrado',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  itemCount: visiveis.length,
                  itemBuilder: (_, i) {
                    final c = visiveis[i];
                    return _ItemSelecionavel(
                      item: c,
                      vinculos: widget.vinculos[c.id] ?? 0,
                      selecionado: _selecionados.contains(c.id),
                      onTap: () => setState(() {
                        if (!_selecionados.remove(c.id)) _selecionados.add(c.id);
                      }),
                    );
                  },
                ),
        ),
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFAFAFA),
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 12, AppSpacing.md, AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                algum
                    ? TextSpan(
                        children: [
                          TextSpan(
                            text: '${_selecionados.length}',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark),
                          ),
                          TextSpan(text: ' selecionado${_selecionados.length > 1 ? 's' : ''}'),
                        ],
                      )
                    : const TextSpan(text: 'Nenhum selecionado'),
                style: const TextStyle(fontSize: 13.5, color: AppColors.textSubtle, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (auth.canEditar) ...[
                    Expanded(
                      child: AppButton(
                        label: 'Desativar',
                        compact: true,
                        onPressed: algum ? () => _executar(AcaoEmMassa.desativar, todos) : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton(
                        label: 'Ativar',
                        compact: true,
                        onPressed: algum ? () => _executar(AcaoEmMassa.ativar, todos) : null,
                      ),
                    ),
                  ],
                  if (auth.canExcluir) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton.danger(
                        label: 'Excluir',
                        icon: LucideIcons.trash2,
                        compact: true,
                        onPressed: algum ? () => _executar(AcaoEmMassa.excluir, todos) : null,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );

    return PopScope(
      canPop: progresso == null,
      child: Stack(
        children: [
          conteudo,
          if (progresso != null) Positioned.fill(child: _OverlayProgresso(progresso.feitos, progresso.total)),
        ],
      ),
    );
  }
}

class _ItemSelecionavel extends StatelessWidget {
  final Classificacao item;
  final int vinculos;
  final bool selecionado;
  final VoidCallback onTap;
  const _ItemSelecionavel({required this.item, required this.vinculos, required this.selecionado, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final nome = item.nome.isEmpty ? 'Sem nome' : item.nome;
    return Semantics(
      checked: selecionado,
      label: nome,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md - 3, vertical: 11),
          decoration: BoxDecoration(
            color: selecionado ? const Color(0x0DE40D2C) : null,
            border: Border(left: BorderSide(color: selecionado ? AppColors.primary : Colors.transparent, width: 3)),
          ),
          child: Row(
            children: [
              Icon(
                selecionado ? LucideIcons.squareCheck : LucideIcons.square,
                size: 18,
                color: selecionado ? AppColors.primary : const Color(0xFFD1D5DB),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: selecionado ? AppColors.primary : AppColors.textDark,
                  ),
                ),
              ),
              if (vinculos > 0) ...[
                const SizedBox(width: 6),
                Text('$vinculos disp.', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
              if (!item.ativo) ...[
                const SizedBox(width: 6),
                const Pill(label: 'Inativo', fundo: AppColors.gray03, texto: AppColors.gray00),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Overlay "Processando itens..." com barra de progresso real.
class _OverlayProgresso extends StatelessWidget {
  final int feitos;
  final int total;
  const _OverlayProgresso(this.feitos, this.total);

  @override
  Widget build(BuildContext context) {
    final fracao = total == 0 ? 1.0 : feitos / total;
    final concluido = feitos >= total;
    return ColoredBox(
      color: const Color(0xF5FFFFFF),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Semantics(
              liveRegion: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    concluido ? 'Concluído!' : 'Processando itens...',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$feitos de $total ${total == 1 ? 'item' : 'itens'}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: fracao,
                      minHeight: 8,
                      backgroundColor: AppColors.border,
                      color: concluido ? AppColors.success : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${(fracao * 100).round()}%',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textBody),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text('Não feche esta janela', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
