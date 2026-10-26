import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';
import 'buttons.dart';
import 'inputs.dart';

/// Toasts globais (`announce` do desktop): fundo escuro com ponto verde.
class Toasts {
  Toasts._();
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  static void mostrar(String mensagem, {bool erro = false}) {
    final m = messengerKey.currentState;
    if (m == null) return;
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      duration: const Duration(milliseconds: 3500),
      content: Semantics(
        liveRegion: true,
        child: Row(children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: erro ? AppColors.red02 : AppColors.success01, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(mensagem)),
        ]),
      ),
    ));
  }
}

/// Bottom sheet padrão do app (os modais do desktop viram "bottom sheets" no mobile).
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required String titulo,
  String? subtitulo,
  required Widget Function(BuildContext) builder,
  bool rolavel = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.9),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.sm, AppSpacing.sm),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Semantics(
                    header: true,
                    child: Text(titulo,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  ),
                  if (subtitulo != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitulo, style: const TextStyle(fontSize: 13, color: AppColors.textSubtle)),
                  ],
                ]),
              ),
              IconButton(
                tooltip: 'Fechar',
                icon: const Icon(LucideIcons.x, size: 20),
                onPressed: () => Navigator.of(ctx).maybePop(),
              ),
            ]),
          ),
          const Divider(),
          Flexible(
            child: rolavel
                ? SingleChildScrollView(padding: const EdgeInsets.all(AppSpacing.lg), child: builder(ctx))
                : builder(ctx),
          ),
        ]),
      ),
    ),
  );
}

/// Confirmação (ex.: exclusão). Retorna true quando o usuário confirma.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  String confirmarLabel = 'Confirmar',
  bool perigoso = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      content: Text(mensagem, style: const TextStyle(color: AppColors.textBody, height: 1.45)),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        AppButton(label: 'Cancelar', compact: true, onPressed: () => Navigator.pop(ctx, false)),
        AppButton(
          label: confirmarLabel,
          compact: true,
          variant: perigoso ? AppButtonVariant.danger : AppButtonVariant.primary,
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Pede um texto (ex.: motivo da rejeição). `obrigatorio` bloqueia a confirmação vazia.
Future<String?> pedirTexto(
  BuildContext context, {
  required String titulo,
  String? mensagem,
  String label = 'Motivo',
  String? hint,
  String confirmarLabel = 'Confirmar',
  bool obrigatorio = true,
  bool perigoso = false,
  int maxLength = 500,
}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _DialogoTexto(
        titulo: titulo,
        mensagem: mensagem,
        label: label,
        hint: hint,
        confirmarLabel: confirmarLabel,
        obrigatorio: obrigatorio,
        perigoso: perigoso,
        maxLength: maxLength,
      ),
    );

/// O diálogo é dono do controller: ele só é descartado depois da animação de saída.
class _DialogoTexto extends StatefulWidget {
  final String titulo;
  final String? mensagem;
  final String label;
  final String? hint;
  final String confirmarLabel;
  final bool obrigatorio;
  final bool perigoso;
  final int maxLength;

  const _DialogoTexto({
    required this.titulo,
    required this.mensagem,
    required this.label,
    required this.hint,
    required this.confirmarLabel,
    required this.obrigatorio,
    required this.perigoso,
    required this.maxLength,
  });

  @override
  State<_DialogoTexto> createState() => _DialogoTextoState();
}

class _DialogoTextoState extends State<_DialogoTexto> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vazio = _controller.text.trim().isEmpty;
    return AlertDialog(
      title: Text(widget.titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (widget.mensagem != null) ...[
            Text(widget.mensagem!, style: const TextStyle(color: AppColors.textBody, height: 1.45)),
            const SizedBox(height: AppSpacing.md),
          ],
          AppTextField(
            label: widget.label,
            hint: widget.hint,
            controller: _controller,
            maxLines: 4,
            maxLength: widget.maxLength,
            obrigatorio: widget.obrigatorio,
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
        ]),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        AppButton(label: 'Cancelar', compact: true, onPressed: () => Navigator.pop(context)),
        AppButton(
          label: widget.confirmarLabel,
          compact: true,
          variant: widget.perigoso ? AppButtonVariant.danger : AppButtonVariant.primary,
          onPressed: widget.obrigatorio && vazio ? null : () => Navigator.pop(context, _controller.text.trim()),
        ),
      ],
    );
  }
}
