import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';

/// Abre a imagem em tela cheia com zoom por pinça e toque duplo.
Future<void> abrirVisualizadorImagem(BuildContext context, {required String url, required String titulo}) =>
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => VisualizadorImagemScreen(url: url, titulo: titulo),
      ),
    );

class VisualizadorImagemScreen extends StatefulWidget {
  final String url;
  final String titulo;
  const VisualizadorImagemScreen({super.key, required this.url, required this.titulo});

  @override
  State<VisualizadorImagemScreen> createState() => _VisualizadorImagemScreenState();
}

class _VisualizadorImagemScreenState extends State<VisualizadorImagemScreen> {
  final _transformacao = TransformationController();
  TapDownDetails? _toque;

  @override
  void dispose() {
    _transformacao.dispose();
    super.dispose();
  }

  void _alternarZoom() {
    final ampliado = _transformacao.value.getMaxScaleOnAxis() > 1.01;
    if (ampliado) {
      _transformacao.value = Matrix4.identity();
      return;
    }
    final p = _toque?.localPosition ?? Offset.zero;
    const escala = 2.5;
    _transformacao.value = Matrix4.identity()
      ..translateByDouble(-p.dx * (escala - 1), -p.dy * (escala - 1), 0, 1)
      ..scaleByDouble(escala, escala, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.titulo,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        leading: IconButton(
          tooltip: 'Fechar',
          icon: const Icon(LucideIcons.x, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: GestureDetector(
        onDoubleTapDown: (d) => _toque = d,
        onDoubleTap: _alternarZoom,
        child: InteractiveViewer(
          transformationController: _transformacao,
          minScale: 1,
          maxScale: 6,
          child: SizedBox.expand(
            child: CachedNetworkImage(
              imageUrl: widget.url,
              fit: BoxFit.contain,
              fadeInDuration: const Duration(milliseconds: 150),
              placeholder: (_, _) => const Center(child: CircularProgressIndicator(color: Colors.white)),
              errorWidget: (_, _, _) => const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.imageOff, color: AppColors.textMuted, size: 40),
                    SizedBox(height: AppSpacing.sm),
                    Text('Não foi possível carregar a imagem.', style: TextStyle(color: AppColors.textMuted)),
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
