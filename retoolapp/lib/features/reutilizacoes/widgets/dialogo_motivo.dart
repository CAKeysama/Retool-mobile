import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

/// Pede o motivo da não aprovação (obrigatório), no visual de `pedirTexto`.
///
/// Versão local: o `pedirTexto` da fundação descarta o controlador em `whenComplete`,
/// antes do fim da animação de saída do diálogo (uso após dispose). Aqui o próprio
/// diálogo é dono do controlador.
Future<String?> pedirMotivoNaoAprovacao(BuildContext context) => showDialog<String>(
      context: context,
      builder: (_) => const _DialogoMotivo(),
    );

class _DialogoMotivo extends StatefulWidget {
  const _DialogoMotivo();

  @override
  State<_DialogoMotivo> createState() => _DialogoMotivoState();
}

class _DialogoMotivoState extends State<_DialogoMotivo> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vazio = _ctrl.text.trim().isEmpty;
    return AlertDialog(
      title: const Text('Não aprovar reutilização', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Informe o motivo da não aprovação:', style: TextStyle(color: AppColors.textBody, height: 1.45)),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Motivo',
            hint: 'Ex.: dispositivo incompatível com a peça',
            controller: _ctrl,
            maxLines: 4,
            maxLength: 500,
            obrigatorio: true,
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
        ]),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        AppButton(label: 'Cancelar', compact: true, onPressed: () => Navigator.pop(context)),
        AppButton(
          label: 'Não Aprovar',
          compact: true,
          variant: AppButtonVariant.danger,
          onPressed: vazio ? null : () => Navigator.pop(context, _ctrl.text.trim()),
        ),
      ],
    );
  }
}
