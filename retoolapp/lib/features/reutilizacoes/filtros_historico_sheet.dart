import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/entities/reutilizacao.dart';
import '../../presentation/state/retool_controller.dart';
import 'reutilizacoes_logica.dart';

/// Filtros do Histórico Geral em bottom sheet (os selects do desktop no celular).
/// Retorna os filtros escolhidos, ou `null` se o usuário fechar sem aplicar.
Future<FiltrosHistorico?> mostrarFiltrosHistorico(
  BuildContext context, {
  required FiltrosHistorico atuais,
  required List<String> dispositivosIds,
}) =>
    showAppSheet<FiltrosHistorico>(
      context,
      titulo: 'Filtrar histórico',
      builder: (_) => FiltrosHistoricoSheet(atuais: atuais, dispositivosIds: dispositivosIds),
    );

class FiltrosHistoricoSheet extends StatefulWidget {
  final FiltrosHistorico atuais;
  final List<String> dispositivosIds;
  const FiltrosHistoricoSheet({super.key, required this.atuais, required this.dispositivosIds});

  @override
  State<FiltrosHistoricoSheet> createState() => _FiltrosHistoricoSheetState();
}

class _FiltrosHistoricoSheetState extends State<FiltrosHistoricoSheet> {
  late FiltrosHistorico _f = widget.atuais;

  // Recria os selects ao limpar (AppDropdown usa valor inicial).
  int _versao = 0;

  @override
  Widget build(BuildContext context) {
    final retool = context.read<ReToolController>();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      AppDropdown<ReutilizacaoStatus?>(
        key: ValueKey('filtro-status-$_versao'),
        label: 'Status',
        hint: 'Todos os Status',
        value: _f.status,
        items: [
          const DropdownMenuItem(value: null, child: Text('Todos os Status')),
          for (final s in ReutilizacaoStatus.values)
            DropdownMenuItem(value: s, child: Text(s.valor, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) => setState(() => _f = _f.copyWith(status: () => v)),
      ),
      const SizedBox(height: AppSpacing.md),
      AppDropdown<String?>(
        key: ValueKey('filtro-dispositivo-$_versao'),
        label: 'Dispositivo',
        hint: 'Todos os Dispositivos',
        value: widget.dispositivosIds.contains(_f.dispositivoId) ? _f.dispositivoId : null,
        items: [
          const DropdownMenuItem(value: null, child: Text('Todos os Dispositivos')),
          for (final id in widget.dispositivosIds)
            DropdownMenuItem(
              value: id,
              child: Text(
                '${_ou(retool.dispositivo(id)?.nome, 'Dispositivo Sem Nome')} (${_ou(retool.dispositivo(id)?.codigo, 'S/C')})',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (v) => setState(() => _f = _f.copyWith(dispositivoId: () => v)),
      ),
      const SizedBox(height: AppSpacing.md),
      AppDropdown<String?>(
        key: ValueKey('filtro-produto-$_versao'),
        label: 'Produto',
        hint: 'Todos os Produtos',
        value: retool.produtos.any((p) => p.id == _f.produtoId) ? _f.produtoId : null,
        items: [
          const DropdownMenuItem(value: null, child: Text('Todos os Produtos')),
          for (final p in retool.produtos)
            DropdownMenuItem(value: p.id, child: Text(p.nome, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) => setState(() => _f = _f.copyWith(produtoId: () => v)),
      ),
      const SizedBox(height: AppSpacing.md),
      AppDropdown<PeriodoFiltro>(
        key: ValueKey('filtro-periodo-$_versao'),
        label: 'Período',
        value: _f.periodo,
        items: [for (final p in PeriodoFiltro.values) DropdownMenuItem(value: p, child: Text(p.rotulo))],
        onChanged: (v) => setState(() => _f = _f.copyWith(periodo: v ?? PeriodoFiltro.todos)),
      ),
      const SizedBox(height: AppSpacing.lg),
      Row(children: [
        Expanded(
          child: AppButton(
            label: 'Limpar filtros',
            icon: LucideIcons.x,
            expand: true,
            onPressed: _f.ativos == 0
                ? null
                : () => setState(() {
                      _f = _f.semFiltros();
                      _versao++;
                    }),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: AppButton.primary(
            label: 'Aplicar filtros',
            expand: true,
            onPressed: () => Navigator.of(context).pop(_f),
          ),
        ),
      ]),
    ]);
  }
}

String _ou(String? v, String padrao) => (v == null || v.trim().isEmpty) ? padrao : v;

/// Rótulos curtos dos filtros ativos (chips removíveis acima da lista).
List<({String rotulo, FiltrosHistorico semEste})> filtrosAtivosDescritos(
  FiltrosHistorico f,
  ReToolController retool,
) =>
    [
      if (f.status != null) (rotulo: f.status!.rotuloCurto, semEste: f.copyWith(status: () => null)),
      if (f.dispositivoId != null)
        (
          rotulo: _ou(retool.dispositivo(f.dispositivoId)?.nome, 'Dispositivo'),
          semEste: f.copyWith(dispositivoId: () => null),
        ),
      if (f.produtoId != null)
        (rotulo: _ou(retool.produto(f.produtoId)?.nome, 'Produto'), semEste: f.copyWith(produtoId: () => null)),
      if (f.periodo != PeriodoFiltro.todos) (rotulo: f.periodo.rotulo, semEste: f.copyWith(periodo: PeriodoFiltro.todos)),
    ];
