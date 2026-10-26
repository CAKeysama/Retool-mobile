import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';

/// Miniatura de imagem (peça/dispositivo) com cache em disco e decodificação
/// no tamanho exibido — listas longas rolam sem picos de memória.
class ImagemRemota extends StatelessWidget {
  final String? url;
  final double size;
  final double? height;
  final double radius;
  final BoxFit fit;
  final IconData iconeVazio;

  const ImagemRemota({
    super.key,
    required this.url,
    this.size = 56,
    this.height,
    this.radius = AppRadius.sm,
    this.fit = BoxFit.cover,
    this.iconeVazio = LucideIcons.box,
  });

  @override
  Widget build(BuildContext context) {
    final h = height ?? size;
    final vazio = Container(
      width: size,
      height: h,
      color: AppColors.surfaceAlt,
      alignment: Alignment.center,
      child: Icon(iconeVazio, size: (size < h ? size : h) * 0.4, color: AppColors.textMuted),
    );
    final u = url;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: (u == null || u.isEmpty)
          ? vazio
          : CachedNetworkImage(
              imageUrl: u,
              width: size,
              height: h,
              fit: fit,
              memCacheWidth: size.isFinite ? (size * dpr).round() : null,
              fadeInDuration: const Duration(milliseconds: 150),
              placeholder: (_, _) => vazio,
              errorWidget: (_, _, _) => vazio,
            ),
    );
  }
}
