import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

/// Palavras-chave como tags: Enter ou vírgula adicionam, "x" remove (igual ao desktop).
class CampoPalavrasChave extends StatefulWidget {
  final List<String> tags;
  final ValueChanged<List<String>> onChanged;
  const CampoPalavrasChave({super.key, required this.tags, required this.onChanged});

  @override
  State<CampoPalavrasChave> createState() => _CampoPalavrasChaveState();
}

class _CampoPalavrasChaveState extends State<CampoPalavrasChave> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _adicionar(String bruto) {
    final novas = <String>[...widget.tags];
    for (final parte in bruto.split(',')) {
      final v = parte.trim();
      if (v.isNotEmpty && !novas.contains(v)) novas.add(v);
    }
    _ctrl.clear();
    setState(() {});
    if (novas.length != widget.tags.length) widget.onChanged(novas);
  }

  void _aoDigitar(String v) {
    if (v.contains(',')) {
      _adicionar(v);
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const FieldLabel('PALAVRAS CHAVE'),
        TextField(
          key: const Key('campo_palavras_chave'),
          controller: _ctrl,
          textInputAction: TextInputAction.done,
          onChanged: _aoDigitar,
          // Mantém o teclado aberto para digitar várias tags seguidas.
          onEditingComplete: () {},
          onSubmitted: _adicionar,
          style: const TextStyle(fontSize: 15, color: AppColors.textDark),
          decoration: InputDecoration(
            hintText: 'Digite uma palavra-chave e aperte Enter ou vírgula...',
            suffixIcon: _ctrl.text.trim().isEmpty
                ? null
                : IconButton(
                    tooltip: 'Adicionar palavra-chave',
                    icon: const Icon(LucideIcons.plus, size: 18, color: AppColors.primary),
                    onPressed: () => _adicionar(_ctrl.text),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (widget.tags.isEmpty)
          const Text(
            'Nenhuma palavra-chave adicionada ainda.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontStyle: FontStyle.italic),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in widget.tags)
                Container(
                  padding: const EdgeInsets.only(left: 10),
                  decoration: BoxDecoration(color: AppColors.pinkBg, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Text(
                          t,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.pinkText),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remover $t',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        icon: const Icon(LucideIcons.x, size: 14, color: AppColors.pinkText),
                        onPressed: () => widget.onChanged(widget.tags.where((x) => x != t).toList()),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
