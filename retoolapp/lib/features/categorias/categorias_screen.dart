import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/classificacao.dart';
import '../../domain/entities/dispositivo.dart';
import '../../presentation/shell/app_shell.dart';
import '../../presentation/state/retool_controller.dart';
import 'classificacoes_regras.dart';
import 'widgets/painel_classificacao.dart';

/// Gestão de Classificações (`Categorias.tsx`): Categorias, Famílias de Produto e
/// Produtos. No celular, os três painéis do desktop viram abas.
class CategoriasScreen extends StatefulWidget {
  const CategoriasScreen({super.key});

  @override
  State<CategoriasScreen> createState() => _CategoriasScreenState();
}

class _CategoriasScreenState extends State<CategoriasScreen> with SingleTickerProviderStateMixin {
  late final TabController _abas = TabController(length: TipoClassificacao.values.length, vsync: this)
    ..addListener(_aoTrocarAba);

  /// Painéis já abertos: montados sob demanda e mantidos (busca/filtro preservados).
  final Set<int> _visitadas = {0};

  void _aoTrocarAba() {
    if (!mounted) return;
    setState(() => _visitadas.add(_abas.index));
  }

  void _deslizar(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v.abs() < 300) return;
    final alvo = (_abas.index + (v < 0 ? 1 : -1)).clamp(0, _abas.length - 1);
    if (alvo != _abas.index) _abas.animateTo(alvo);
  }

  @override
  void dispose() {
    _abas.dispose();
    super.dispose();
  }

  // Contagem de dispositivos por classificação: recalculada só quando chega um
  // novo snapshot de dispositivos (a lista do controller muda de identidade).
  List<Dispositivo>? _snapshot;
  Map<TipoClassificacao, Map<String, int>> _vinculos = const {};

  Map<TipoClassificacao, Map<String, int>> _vinculosDe(List<Dispositivo> dispositivos) {
    if (!identical(dispositivos, _snapshot)) {
      _snapshot = dispositivos;
      _vinculos = {for (final t in TipoClassificacao.values) t: contarDispositivosPorClassificacao(dispositivos, t)};
    }
    return _vinculos;
  }

  @override
  Widget build(BuildContext context) {
    final retool = context.watch<ReToolController>();
    final vinculos = _vinculosDe(retool.dispositivos);
    final tecladoAberto = MediaQuery.viewInsetsOf(context).bottom > 0;

    final tipos = TipoClassificacao.values;
    final atual = _abas.index;

    return Scaffold(
      appBar: appBarPadrao(
        context,
        titulo: const Text('Classificações'),
        bottom: TabBar(
          controller: _abas,
          labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          tabs: [
            for (final t in TipoClassificacao.values)
              Tab(child: Text(t.rotuloPlural, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!tecladoAberto)
            const Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.md, 12, AppSpacing.md, 0),
              child: Text(
                'Gerencie e visualize todas as estruturas de classificação usadas no sistema.',
                style: TextStyle(fontSize: 13.5, color: AppColors.textBody),
              ),
            ),
          // Pilha de painéis (sem PageView): só o painel ativo fica "onstage".
          Expanded(
            child: GestureDetector(
              onHorizontalDragEnd: _deslizar,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  for (var i = 0; i < tipos.length; i++)
                    if (_visitadas.contains(i))
                      Offstage(
                        offstage: i != atual,
                        child: TickerMode(
                          enabled: i == atual,
                          child: PainelClassificacao(
                            key: ValueKey(tipos[i]),
                            tipo: tipos[i],
                            vinculos: vinculos[tipos[i]]!,
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
