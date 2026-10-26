import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/classificacao.dart';
import '../../../presentation/state/retool_controller.dart';
import 'filtro_dispositivos.dart';

/// Painel "Filtros" do desktop (Categoria + Processo Industrial) como bottom sheet,
/// com o filtro extra de situação. As mudanças valem na hora, como no desktop.
Future<void> mostrarFiltrosDispositivos(
  BuildContext context, {
  required FiltrosDispositivos atual,
  required ValueChanged<FiltrosDispositivos> onChanged,
}) => showAppSheet<void>(
  context,
  titulo: 'Filtros',
  builder: (_) => _PainelFiltros(inicial: atual, onChanged: onChanged),
);

class _PainelFiltros extends StatefulWidget {
  final FiltrosDispositivos inicial;
  final ValueChanged<FiltrosDispositivos> onChanged;
  const _PainelFiltros({required this.inicial, required this.onChanged});

  @override
  State<_PainelFiltros> createState() => _PainelFiltrosState();
}

class _PainelFiltrosState extends State<_PainelFiltros> {
  late FiltrosDispositivos _f = widget.inicial;

  // Recria os dropdowns ao limpar (o valor inicial do FormField só é lido na criação).
  int _geracao = 0;

  void _mudar(FiltrosDispositivos f) {
    setState(() => _f = f);
    widget.onChanged(f);
  }

  @override
  Widget build(BuildContext context) {
    final categorias = context.select<ReToolController, List<Classificacao>>((r) => r.categorias);
    // Inativas ficam ocultas, exceto a que já estiver selecionada.
    final opcoesCategoria = [
      for (final c in categorias)
        if (c.ativo || c.id == _f.categoriaId) c,
    ];

    return Column(
      key: ValueKey(_geracao),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppDropdown<String?>(
          key: const Key('filtro-categoria'),
          label: 'Categoria',
          value: _f.categoriaId,
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Todas')),
            for (final c in opcoesCategoria)
              DropdownMenuItem<String?>(
                value: c.id,
                child: Text('${c.nome}${c.ativo ? '' : ' (Inativo)'}', overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => _mudar(_f.copyWith(categoriaId: () => v)),
        ),
        const SizedBox(height: AppSpacing.md),
        AppDropdown<String?>(
          key: const Key('filtro-processo'),
          label: 'Processo Industrial',
          value: _f.processo,
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Todos os Processos')),
            for (final p in processosIndustriais) DropdownMenuItem<String?>(value: p, child: Text(p)),
          ],
          onChanged: (v) => _mudar(_f.copyWith(processo: () => v)),
        ),
        const SizedBox(height: AppSpacing.md),
        const FieldLabel('Situação'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final s in FiltroStatus.values)
              ChoiceChip(
                label: Text(s.rotulo),
                selected: _f.status == s,
                showCheckmark: false,
                labelStyle: TextStyle(
                  color: _f.status == s ? Colors.white : AppColors.textBody,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => _mudar(_f.copyWith(status: s)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Limpar filtros',
                icon: LucideIcons.x,
                expand: true,
                onPressed: _f.ativos == 0
                    ? null
                    : () {
                        _geracao++;
                        _mudar(FiltrosDispositivos(query: _f.query));
                      },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton.primary(
                label: 'Ver resultados',
                expand: true,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
