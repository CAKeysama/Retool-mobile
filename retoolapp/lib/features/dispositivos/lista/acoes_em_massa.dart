import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import 'filtro_dispositivos.dart';

/// Ações em massa sobre dispositivos selecionados (`BulkActionModal` do desktop).
enum AcaoEmMassa {
  desativar(titulo: 'Desativar itens', verbo: 'Desativar', processando: 'Processando...', concluido: 'desativados'),
  ativar(titulo: 'Ativar itens', verbo: 'Ativar', processando: 'Processando...', concluido: 'ativados'),
  excluir(titulo: 'Excluir itens', verbo: 'Excluir', processando: 'Excluindo...', concluido: 'excluídos');

  final String titulo;
  final String verbo;
  final String processando;
  final String concluido;
  const AcaoEmMassa({required this.titulo, required this.verbo, required this.processando, required this.concluido});

  /// Texto do diálogo de confirmação (copiado do desktop).
  String mensagem(int n) {
    final itens = rotuloItens(n);
    return switch (this) {
      AcaoEmMassa.desativar =>
        'Você está prestes a desativar $itens. Eles não serão excluídos, mas ficarão inativos no sistema.',
      AcaoEmMassa.ativar => 'Você está prestes a reativar $itens. Eles voltarão a ficar ativos no sistema.',
      AcaoEmMassa.excluir => 'Você está prestes a excluir permanentemente $itens. Esta ação não pode ser desfeita.',
    };
  }

  /// Toast de resumo ao final.
  String resumo(int sucesso, int erros) {
    final base = sucesso == 1 ? '1 dispositivo $_singular com sucesso' : '$sucesso dispositivos $concluido com sucesso';
    return erros > 0 ? '$base. $erros com erro.' : base;
  }

  String get _singular => concluido.substring(0, concluido.length - 1);
}

/// Progresso de uma operação em massa.
class ProgressoEmMassa {
  final int feitos;
  final int total;
  const ProgressoEmMassa(this.feitos, this.total);

  double get fracao => total == 0 ? 1 : feitos / total;
  bool get concluido => feitos >= total;
}

/// Executa [fn] em lotes (como o `useBulkProgress` do desktop), notificando o
/// progresso item a item. Retorna (sucessos, erros) — uma falha não interrompe o lote.
Future<({int sucesso, int erros})> executarEmLotes(
  List<String> ids,
  Future<void> Function(String id) fn, {
  required void Function(ProgressoEmMassa p) onProgresso,
  int tamanhoLote = 5,
}) async {
  var feitos = 0, erros = 0;
  onProgresso(ProgressoEmMassa(0, ids.length));
  for (var i = 0; i < ids.length; i += tamanhoLote) {
    final lote = ids.sublist(i, (i + tamanhoLote).clamp(0, ids.length));
    await Future.wait(
      lote.map((id) async {
        try {
          await fn(id);
        } catch (e) {
          erros++;
          debugPrint('Falha na ação em massa ($id): $e');
        }
        feitos++;
        onProgresso(ProgressoEmMassa(feitos, ids.length));
      }),
    );
  }
  return (sucesso: ids.length - erros, erros: erros);
}

/// Diálogo de confirmação com o ícone de alerta do desktop.
Future<bool> confirmarAcaoEmMassa(BuildContext context, AcaoEmMassa acao, int n) async {
  final perigo = acao == AcaoEmMassa.excluir;
  final cor = perigo ? AppColors.danger : (acao == AcaoEmMassa.ativar ? AppColors.success : AppColors.various04);
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(acao.titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(LucideIcons.triangleAlert, size: 22, color: cor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(acao.mensagem(n), style: const TextStyle(color: AppColors.textDark, height: 1.5)),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        AppButton(label: 'Cancelar', compact: true, onPressed: () => Navigator.pop(ctx, false)),
        AppButton(
          label: '${acao.verbo} $n',
          compact: true,
          variant: perigo
              ? AppButtonVariant.danger
              : (acao == AcaoEmMassa.ativar ? AppButtonVariant.success : AppButtonVariant.secondary),
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Sobreposição de progresso ("Processando itens..." → "Concluído!").
class DialogoProgressoEmMassa extends StatelessWidget {
  final ValueNotifier<ProgressoEmMassa> progresso;
  const DialogoProgressoEmMassa({super.key, required this.progresso});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ValueListenableBuilder<ProgressoEmMassa>(
            valueListenable: progresso,
            builder: (_, p, _) {
              final pct = (p.fracao * 100).round();
              return Semantics(
                liveRegion: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      p.concluido ? 'Concluído!' : 'Processando itens...',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${p.feitos} de ${rotuloItens(p.total)}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: p.fracao),
                        duration: const Duration(milliseconds: 250),
                        builder: (_, v, _) => LinearProgressIndicator(
                          value: v,
                          minHeight: 8,
                          backgroundColor: AppColors.border,
                          color: p.concluido ? AppColors.success : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$pct%',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textBody),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text('Não feche esta janela', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Executa a ação com a barra de progresso modal; fecha ao final (após mostrar 100%).
Future<({int sucesso, int erros})> executarComProgresso(
  BuildContext context,
  List<String> ids,
  Future<void> Function(String id) fn,
) async {
  final progresso = ValueNotifier(ProgressoEmMassa(0, ids.length));
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => DialogoProgressoEmMassa(progresso: progresso),
  );
  try {
    final r = await executarEmLotes(ids, fn, onProgresso: (p) => progresso.value = p);
    progresso.value = ProgressoEmMassa(ids.length, ids.length);
    // Pequena pausa para o usuário ver 100%.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return r;
  } finally {
    // O notificador não é descartado aqui: o diálogo ainda o escuta durante a animação de saída.
    if (navigator.mounted) navigator.pop();
  }
}
