import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../reutilizacoes_logica.dart';

/// Navegação em abas no padrão do desktop (`components/Tabs.tsx`): pílulas `.btn`,
/// a ativa em vermelho; contador entre parênteses nas filas.
class AbasPilula extends StatelessWidget {
  final List<AbaReutilizacoes> abas;
  final AbaReutilizacoes ativa;
  final Map<AbaReutilizacoes, int> contagens;
  final ValueChanged<AbaReutilizacoes> onSelecionar;

  const AbasPilula({
    super.key,
    required this.abas,
    required this.ativa,
    required this.contagens,
    required this.onSelecionar,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Seções da página',
      container: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
        child: Row(children: [
          for (final (i, aba) in abas.indexed) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            _Pilula(
              key: ValueKey('aba-${aba.name}'),
              rotulo: contagens.containsKey(aba) ? '${aba.rotulo} (${contagens[aba]})' : aba.rotulo,
              selecionada: aba == ativa,
              onTap: () => onSelecionar(aba),
            ),
          ],
        ]),
      ),
    );
  }
}

class _Pilula extends StatelessWidget {
  final String rotulo;
  final bool selecionada;
  final VoidCallback onTap;
  const _Pilula({super.key, required this.rotulo, required this.selecionada, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selecionada,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: ShapeDecoration(
          color: selecionada ? AppColors.primary : Colors.transparent,
          shape: StadiumBorder(side: BorderSide(color: selecionada ? AppColors.primary : AppColors.border)),
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    rotulo,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selecionada ? FontWeight.w700 : FontWeight.w600,
                      color: selecionada ? Colors.white : AppColors.textBody,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
