import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/dispositivo.dart';
import '../../../presentation/widgets/dispositivo_thumb.dart';
import 'filtro_dispositivos.dart';

/// Linha da lista de dispositivos (item do `FocusableList` do desktop): miniatura,
/// nome + código, badges de categoria/família/produto, peso e palavras-chave.
class DispositivoCard extends StatelessWidget {
  final Dispositivo dispositivo;
  final String? categoria;
  final String? familia;
  final String? produto;
  final int reutilizacoes;
  final bool selecionado;
  final bool modoSelecao;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Palavras-chave exibidas antes do "+N" (mantém o cartão compacto no celular).
  static const maxPalavras = 3;

  const DispositivoCard({
    super.key,
    required this.dispositivo,
    required this.reutilizacoes,
    required this.onTap,
    this.categoria,
    this.familia,
    this.produto,
    this.selecionado = false,
    this.modoSelecao = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final d = dispositivo;
    final nome = (d.nome?.trim().isNotEmpty ?? false) ? d.nome!.trim() : 'Nome não informado';
    final codigo = d.codigo?.trim() ?? '';
    final peso = d.peso?.trim() ?? '';
    final palavras = d.palavrasChave.where((p) => p.trim().isNotEmpty).toList();
    final raio = BorderRadius.circular(AppRadius.md);

    final badges = <Widget>[
      if (categoria?.isNotEmpty ?? false) AppBadge(categoria!, cor: corDoBadge(categoria!)),
      if (familia?.isNotEmpty ?? false) AppBadge(familia!, cor: corDoBadge(familia!)),
      if (produto?.isNotEmpty ?? false) AppBadge(produto!, cor: BadgeCor.blue),
      if (peso.isNotEmpty)
        Text(
          formatarPeso(peso),
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500),
        ),
      for (final p in palavras.take(maxPalavras)) AppBadge(p, cor: BadgeCor.pink),
      if (palavras.length > maxPalavras) AppBadge('+${palavras.length - maxPalavras}'),
    ];

    final semantica = [
      nome,
      if (codigo.isNotEmpty) 'código $codigo',
      if (!d.ativo) 'inativo',
      '$reutilizacoes ${reutilizacoes == 1 ? 'reutilização' : 'reutilizações'}',
      if (modoSelecao) selecionado ? 'selecionado' : 'não selecionado',
    ].join(', ');

    return Semantics(
      button: true,
      selected: modoSelecao ? selecionado : null,
      label: semantica,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: raio,
          boxShadow: selecionado
              ? const [BoxShadow(color: Color(0x0DE40D2C), blurRadius: 12, offset: Offset(0, 4))]
              : null,
        ),
        child: Material(
          color: selecionado ? const Color(0x0DE40D2C) : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: raio,
            side: BorderSide(color: selecionado ? AppColors.primary : AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Miniatura(url: d.imagemCapa, selecionado: selecionado, modoSelecao: modoSelecao),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nome,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.5,
                            height: 1.25,
                            color: d.nome?.trim().isNotEmpty ?? false ? AppColors.textDark : AppColors.textMuted,
                          ),
                        ),
                        if (codigo.isNotEmpty || !d.ativo) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (codigo.isNotEmpty)
                                Flexible(
                                  child: Text(
                                    codigo,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                                  ),
                                ),
                              if (!d.ativo) ...[
                                if (codigo.isNotEmpty) const SizedBox(width: 8),
                                const Pill(label: 'Inativo', fundo: AppColors.gray03, texto: AppColors.gray00),
                              ],
                            ],
                          ),
                        ],
                        if (badges.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: badges,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ContadorReutilizacoes(reutilizacoes),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Miniatura extends StatelessWidget {
  final String? url;
  final bool selecionado;
  final bool modoSelecao;
  const _Miniatura({required this.url, required this.selecionado, required this.modoSelecao});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        children: [
          ImagemRemota(url: url, size: 52),
          if (modoSelecao)
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: selecionado ? const Color(0xD9E40D2C) : const Color(0x66FFFFFF),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: selecionado ? AppColors.primary : AppColors.gray02, width: 1.5),
                ),
                alignment: Alignment.center,
                child: selecionado ? const Icon(LucideIcons.check, color: Colors.white, size: 24) : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _ContadorReutilizacoes extends StatelessWidget {
  final int total;
  const _ContadorReutilizacoes(this.total);

  @override
  Widget build(BuildContext context) {
    final cor = total > 0 ? AppColors.primary : AppColors.textMuted;
    return Tooltip(
      message: '$total ${total == 1 ? 'reutilização' : 'reutilizações'}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: total > 0 ? AppColors.primarySoft : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.wrench, size: 13, color: cor),
            const SizedBox(width: 4),
            Text(
              '$total',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: cor),
            ),
          ],
        ),
      ),
    );
  }
}
