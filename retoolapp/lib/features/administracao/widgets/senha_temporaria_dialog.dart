import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import 'admin_comum.dart';

/// Exibe a senha temporária UMA única vez (conta criada ou senha redefinida).
/// A senha vive só neste diálogo: nunca vai para estado persistente, URL ou auditoria.
Future<void> mostrarSenhaTemporaria(
  BuildContext context, {
  required String titulo,
  required String email,
  required String senha,
}) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SenhaTemporariaDialog(titulo: titulo, email: email, senha: senha),
    );

class _SenhaTemporariaDialog extends StatefulWidget {
  final String titulo;
  final String email;
  final String senha;
  const _SenhaTemporariaDialog({required this.titulo, required this.email, required this.senha});

  @override
  State<_SenhaTemporariaDialog> createState() => _SenhaTemporariaDialogState();
}

class _SenhaTemporariaDialogState extends State<_SenhaTemporariaDialog> {
  bool _copiado = false;

  Future<void> _copiar() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.senha));
      if (mounted) setState(() => _copiado = true);
    } catch (_) {
      if (mounted) setState(() => _copiado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const verde = Color(0xFF15803D);
    const verdeTexto = Color(0xFF166534);
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: const Color(0xFFF0FDF4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: Color(0xFF86EFAC)),
        ),
        title: Row(children: [
          const Icon(LucideIcons.keyRound, size: 18, color: verde),
          const SizedBox(width: 8),
          Expanded(
            child: Text(widget.titulo,
                style: const TextStyle(color: verde, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ]),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Repasse a senha temporária abaixo a '),
                TextSpan(text: widget.email, style: const TextStyle(fontWeight: FontWeight.w700)),
                const TextSpan(text: ' por um canal seguro. Ela '),
                const TextSpan(text: 'não será exibida novamente', style: TextStyle(fontWeight: FontWeight.w700)),
                const TextSpan(text: ' e deverá ser trocada no primeiro acesso.'),
              ]),
              style: const TextStyle(fontSize: 13.5, color: verdeTexto, height: 1.5),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: const Color(0xFF22C55E)),
              ),
              child: Semantics(
                label: 'Senha temporária',
                child: SelectableText(
                  widget.senha,
                  key: const ValueKey('senha-temporaria'),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 17,
                    letterSpacing: 1,
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ]),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          BotaoAcao(
            label: _copiado ? 'Copiada' : 'Copiar',
            icon: _copiado ? LucideIcons.check : LucideIcons.copy,
            onPressed: _copiar,
          ),
          BotaoAcao(label: 'Concluir', cor: CorAcao.success, onPressed: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}
