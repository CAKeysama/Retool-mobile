import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/dispositivo.dart';
import '../../../presentation/state/retool_controller.dart';

/// Busca principal da Home em pílula com autocomplete (sugestões flutuantes abaixo
/// do campo, como a `listbox` do desktop). Mesma busca multidimensional da lista.
class BuscaOmnibox extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<Dispositivo> onSelecionar;
  final ValueChanged<String> onBuscar;

  const BuscaOmnibox({super.key, required this.controller, required this.onSelecionar, required this.onBuscar});

  @override
  State<BuscaOmnibox> createState() => _BuscaOmniboxState();
}

class _BuscaOmniboxState extends State<BuscaOmnibox> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  final _focus = FocusNode(debugLabel: 'busca-home');
  Timer? _debounce;
  late String _query = widget.controller.text;

  // Memo das sugestões (recalcula só se a busca ou os dados mudarem).
  List<Dispositivo>? _memoBase;
  String? _memoQuery;
  List<Dispositivo> _sugestoes = const [];

  @override
  void initState() {
    super.initState();
    _focus.addListener(_sincronizarPortal);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.removeListener(_sincronizarPortal);
    _focus.dispose();
    super.dispose();
  }

  void _sincronizarPortal() {
    if (!mounted) return;
    final mostrar = _focus.hasFocus && _query.trim().isNotEmpty;
    if (mostrar && !_portal.isShowing) {
      _portal.show();
    } else if (!mostrar && _portal.isShowing) {
      _portal.hide();
    }
  }

  void _aoDigitar(String valor) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _query = valor);
      _sincronizarPortal();
    });
  }

  void _fechar() {
    _focus.unfocus();
    if (_portal.isShowing) _portal.hide();
  }

  List<Dispositivo> _calcular(ReToolController retool) {
    final q = _query.trim();
    if (q.isEmpty) return const [];
    if (!identical(_memoBase, retool.dispositivos) || _memoQuery != q) {
      _memoBase = retool.dispositivos;
      _memoQuery = q;
      _sugestoes = retool.buscarDispositivos(q);
    }
    return _sugestoes;
  }

  @override
  Widget build(BuildContext context) {
    final sugestoes = _calcular(context.watch<ReToolController>());
    return LayoutBuilder(
      builder: (context, c) {
        final largura = c.maxWidth;
        return OverlayPortal(
          controller: _portal,
          overlayChildBuilder: (ctx) => _Sugestoes(
            link: _link,
            largura: largura,
            sugestoes: sugestoes,
            onTap: (d) {
              _fechar();
              widget.onSelecionar(d);
            },
          ),
          child: CompositedTransformTarget(
            link: _link,
            child: TextFieldTapRegion(
              onTapOutside: (_) => _fechar(),
              child: Semantics(
                label: 'Buscar dispositivos',
                textField: true,
                child: AppSearchField(
                  controller: widget.controller,
                  focusNode: _focus,
                  grande: true,
                  hint: 'Buscar dispositivos por nome, código, descrição...',
                  onChanged: _aoDigitar,
                  onSubmitted: (v) {
                    _debounce?.cancel();
                    _fechar();
                    widget.onBuscar(v);
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Sugestoes extends StatelessWidget {
  final LayerLink link;
  final double largura;
  final List<Dispositivo> sugestoes;
  final ValueChanged<Dispositivo> onTap;

  const _Sugestoes({required this.link, required this.largura, required this.sugestoes, required this.onTap});

  static const _alturaItem = 48.0;

  @override
  Widget build(BuildContext context) {
    if (sugestoes.isEmpty) return const SizedBox.shrink();
    final mq = MediaQuery.of(context);
    // Até 300 px (como no desktop), sem invadir o teclado.
    final maxAltura = math.max(_alturaItem * 2.5, math.min(300.0, (mq.size.height - mq.viewInsets.bottom) * 0.4));
    return CompositedTransformFollower(
      link: link,
      showWhenUnlinked: false,
      targetAnchor: Alignment.bottomLeft,
      offset: const Offset(0, 8),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: largura,
          child: TextFieldTapRegion(
            child: Container(
              constraints: BoxConstraints(maxHeight: maxAltura),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: AppShadows.lg,
              ),
              child: Material(
                type: MaterialType.transparency,
                child: Semantics(
                  label: 'Sugestões de dispositivos',
                  explicitChildNodes: true,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    shrinkWrap: true,
                    itemExtent: _alturaItem,
                    itemCount: sugestoes.length,
                    itemBuilder: (_, i) => _ItemSugestao(dispositivo: sugestoes[i], onTap: onTap),
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

class _ItemSugestao extends StatelessWidget {
  final Dispositivo dispositivo;
  final ValueChanged<Dispositivo> onTap;
  const _ItemSugestao({required this.dispositivo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final d = dispositivo;
    final nome = (d.nome?.trim().isNotEmpty ?? false) ? d.nome!.trim() : 'Nome não informado';
    final codigo = d.codigo?.trim() ?? '';
    return InkWell(
      onTap: () => onTap(d),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            const Icon(LucideIcons.search, size: 14, color: AppColors.textMuted),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                nome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textDark, fontSize: 15),
              ),
            ),
            if (codigo.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  codigo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
