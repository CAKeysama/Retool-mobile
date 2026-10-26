import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/file_attachment.dart';
import '../../../domain/services/file_validators.dart';
import '../../../presentation/widgets/dispositivo_thumb.dart';
import 'visualizador_imagem.dart';

typedef AbridorDeUrl = Future<bool> Function(String url);

Future<bool> _abrirNoAppExterno(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Abre documentos (PDF) no app externo. Substituível nos testes.
AbridorDeUrl abrirUrlExterna = _abrirNoAppExterno;

/// Abre um anexo e avisa se não houver app para abri-lo.
Future<void> abrirAnexo(String url) async {
  try {
    final ok = await abrirUrlExterna(url);
    if (!ok) Toasts.mostrar('Não foi possível abrir o arquivo.', erro: true);
  } catch (_) {
    Toasts.mostrar('Não foi possível abrir o arquivo.', erro: true);
  }
}

/// Rótulo vermelho em caixa alta das mídias ("IMAGEM PEÇA", "DOCUMENTOS TÉCNICOS...").
class RotuloMidia extends StatelessWidget {
  final String texto;
  const RotuloMidia(this.texto, {super.key});

  @override
  Widget build(BuildContext context) => Text(
    texto,
    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 0.2),
  );
}

/// Cartão de uma imagem (peça ou dispositivo) que abre a visualização em tela cheia.
class CartaoImagem extends StatelessWidget {
  final String rotulo;
  final String url;
  final String descricaoAcessivel;
  const CartaoImagem({super.key, required this.rotulo, required this.url, required this.descricaoAcessivel});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Column(
      children: [
        RotuloMidia(rotulo),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, c) => Semantics(
            button: true,
            label: 'Ampliar $descricaoAcessivel',
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              onTap: () => abrirVisualizadorImagem(context, url: url, titulo: rotulo),
              child: Stack(
                children: [
                  ImagemRemota(
                    url: url,
                    size: c.maxWidth,
                    height: 150,
                    fit: BoxFit.contain,
                    iconeVazio: LucideIcons.image,
                  ),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(LucideIcons.zoomIn, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Galeria das duas imagens do dispositivo (mostra só as que existem, como no desktop).
class GaleriaImagensDispositivo extends StatelessWidget {
  final String? imagemPeca;
  final String? imagemDispositivo;
  const GaleriaImagensDispositivo({super.key, this.imagemPeca, this.imagemDispositivo});

  @override
  Widget build(BuildContext context) {
    final cartoes = <Widget>[
      if (imagemPeca?.isNotEmpty ?? false)
        CartaoImagem(rotulo: 'IMAGEM PEÇA', url: imagemPeca!, descricaoAcessivel: 'imagem da peça'),
      if (imagemDispositivo?.isNotEmpty ?? false)
        CartaoImagem(
          rotulo: 'Imagem dispositivo',
          url: imagemDispositivo!,
          descricaoAcessivel: 'imagem do dispositivo',
        ),
    ];
    if (cartoes.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < cartoes.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.md),
          Expanded(child: cartoes[i]),
        ],
      ],
    );
  }
}

/// Linha de um documento PDF anexado (nome, tamanho • data e botão de abrir).
class LinhaAnexoPdf extends StatelessWidget {
  final FileAttachment anexo;
  final String rotuloAbrir;

  /// Ação extra à direita (ex.: remover no formulário).
  final Widget? trailing;
  const LinhaAnexoPdf({super.key, required this.anexo, this.rotuloAbrir = 'Abrir', this.trailing});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
    decoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Row(
      children: [
        const Icon(LucideIcons.fileText, size: 20, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                anexo.originalName.isEmpty ? anexo.fileName : anexo.originalName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark, fontSize: 14),
              ),
              Text(
                '${formatFileSize(anexo.size)} • ${formatarData(anexo.uploadedAt)}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.textSubtle),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        AppButton(
          label: rotuloAbrir,
          icon: LucideIcons.externalLink,
          compact: true,
          onPressed: anexo.downloadURL.isEmpty ? null : () => abrirAnexo(anexo.downloadURL),
        ),
        if (trailing != null) ...[const SizedBox(width: 4), trailing!],
      ],
    ),
  );
}

/// Seção "Arquivos e Mídias Anexadas" da ficha (imagens + PDFs).
class SecaoMidiasDispositivo extends StatelessWidget {
  final String? imagemPeca;
  final String? imagemDispositivo;
  final List<FileAttachment> anexos;
  const SecaoMidiasDispositivo({super.key, this.imagemPeca, this.imagemDispositivo, this.anexos = const []});

  bool get _temImagem => (imagemPeca?.isNotEmpty ?? false) || (imagemDispositivo?.isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    if (!_temImagem && anexos.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: AppSpacing.lg),
        const SectionLabel('Arquivos e Mídias Anexadas'),
        if (_temImagem) GaleriaImagensDispositivo(imagemPeca: imagemPeca, imagemDispositivo: imagemDispositivo),
        if (anexos.isNotEmpty) ...[
          if (_temImagem) const SizedBox(height: AppSpacing.md),
          const RotuloMidia('DOCUMENTOS TÉCNICOS & MANUAIS (PDF)'),
          const SizedBox(height: AppSpacing.sm),
          for (final a in anexos)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: LinhaAnexoPdf(anexo: a),
            ),
        ],
      ],
    );
  }
}
