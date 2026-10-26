import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Cartão de contagem da Home (`HomeCard` do desktop): fundo vermelho translúcido,
/// ícone em círculo branco, número grande e rótulo em vermelho.
class HomeCard extends StatefulWidget {
  final int count;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  /// Lado do cartão (o desktop usa 140; no celular encolhe para caber na largura).
  final double tamanho;

  const HomeCard({
    super.key,
    required this.count,
    required this.label,
    required this.icon,
    required this.onTap,
    this.tamanho = 140,
  });

  @override
  State<HomeCard> createState() => _HomeCardState();
}

class _HomeCardState extends State<HomeCard> {
  bool _pressionado = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tamanho;
    final padding = t >= 130 ? AppSpacing.lg : (t >= 112 ? AppSpacing.md : 12.0);
    final raio = BorderRadius.circular(AppRadius.lg);
    return Semantics(
      button: true,
      label: '${widget.count} ${widget.label}',
      excludeSemantics: true,
      child: AnimatedSlide(
        // "translateY(-2px)" do hover do desktop vira um leve afundar ao tocar.
        offset: Offset(0, _pressionado ? 0.015 : 0),
        duration: const Duration(milliseconds: 150),
        child: Material(
          color: AppColors.primarySoft,
          borderRadius: raio,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (v) => setState(() => _pressionado = v),
            splashColor: const Color(0x1FE40D2C),
            highlightColor: const Color(0x0FE40D2C),
            child: SizedBox(
              width: t,
              height: t,
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Icon(widget.icon, size: 18, color: AppColors.primary),
                    ),
                    // Encolhe em vez de estourar quando o cartão fica pequeno (telas estreitas).
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${widget.count}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                  height: 1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                widget.label,
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 12.8,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
