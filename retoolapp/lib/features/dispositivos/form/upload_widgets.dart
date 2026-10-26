import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/file_attachment.dart';
import '../../../presentation/widgets/dispositivo_thumb.dart';
import '../detalhes/galeria_midias.dart';
import '../detalhes/visualizador_imagem.dart';
import 'seletor_arquivos.dart';

/// Envio em andamento de um arquivo (progresso 0–100).
class EnvioEmAndamento {
  final String nome;
  final int progresso;
  const EnvioEmAndamento(this.nome, this.progresso);
}

/// Pergunta se a foto vem da câmera ou da galeria.
Future<OrigemImagem?> perguntarOrigemImagem(BuildContext context) => showAppSheet<OrigemImagem>(
  context,
  titulo: 'Adicionar imagem',
  builder: (ctx) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ListTile(
        leading: const Icon(LucideIcons.camera, color: AppColors.primary),
        title: const Text('Tirar foto'),
        onTap: () => Navigator.of(ctx).pop(OrigemImagem.camera),
      ),
      ListTile(
        leading: const Icon(LucideIcons.images, color: AppColors.primary),
        title: const Text('Escolher da galeria'),
        onTap: () => Navigator.of(ctx).pop(OrigemImagem.galeria),
      ),
    ],
  ),
);

class _BarraProgresso extends StatelessWidget {
  final String texto;
  final int progresso;
  const _BarraProgresso({required this.texto, required this.progresso});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
      const SizedBox(height: AppSpacing.sm),
      Text(
        '$texto $progresso%',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
      ),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: progresso / 100,
          minHeight: 6,
          backgroundColor: AppColors.border,
          semanticsLabel: texto,
          semanticsValue: '$progresso%',
        ),
      ),
    ],
  );
}

class _MensagemErro extends StatelessWidget {
  final String mensagem;
  const _MensagemErro(this.mensagem);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(LucideIcons.circleAlert, size: 14, color: AppColors.danger),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(mensagem, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
        ),
      ],
    ),
  );
}

/// Área tracejada para tocar e enviar um arquivo (dropzone do desktop).
class _AreaEnvio extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String subtitulo;
  final VoidCallback? onTap;
  final Widget? conteudo;
  const _AreaEnvio({required this.icone, required this.titulo, required this.subtitulo, this.onTap, this.conteudo});

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0x05000000),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      side: const BorderSide(color: AppColors.border, width: 2),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 140),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Center(
            child:
                conteudo ??
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icone, size: 28, color: AppColors.textMuted),
                    const SizedBox(height: 6),
                    Text(
                      titulo,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitulo,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                    ),
                  ],
                ),
          ),
        ),
      ),
    ),
  );
}

/// Campo de imagem única (peça ou dispositivo): prévia + remover, ou área de envio com progresso.
class CampoImagemUpload extends StatelessWidget {
  final String rotulo;
  final String? url;
  final EnvioEmAndamento? envio;
  final String? erro;
  final VoidCallback onEscolher;
  final VoidCallback onRemover;

  const CampoImagemUpload({
    super.key,
    required this.rotulo,
    required this.url,
    required this.onEscolher,
    required this.onRemover,
    this.envio,
    this.erro,
  });

  @override
  Widget build(BuildContext context) {
    final temImagem = url != null && url!.isNotEmpty && envio == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(rotulo),
        if (temImagem)
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            padding: const EdgeInsets.all(8),
            child: Stack(
              children: [
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, c) => InkWell(
                      onTap: () => abrirVisualizadorImagem(context, url: url!, titulo: rotulo),
                      child: ImagemRemota(url: url, size: c.maxWidth, height: c.maxHeight, fit: BoxFit.contain),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Material(
                    color: const Color(0xE6FFFFFF),
                    shape: const StadiumBorder(side: BorderSide(color: AppColors.danger)),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: onRemover,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.trash2, size: 13, color: AppColors.danger),
                            SizedBox(width: 4),
                            Text(
                              'Remover',
                              style: TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          _AreaEnvio(
            icone: LucideIcons.image,
            titulo: 'Toque para tirar foto ou escolher imagem',
            subtitulo: 'Suporta JPG, PNG ou WEBP (máx 10MB)',
            onTap: envio == null ? onEscolher : null,
            conteudo: envio == null ? null : _BarraProgresso(texto: 'Enviando arquivo...', progresso: envio!.progresso),
          ),
        if (erro != null) _MensagemErro(erro!),
      ],
    );
  }
}

/// Documentos técnicos (PDF): área de envio, progresso por arquivo e lista dos anexados.
class CampoAnexosPdf extends StatelessWidget {
  final List<FileAttachment> anexos;
  final List<EnvioEmAndamento> envios;
  final String? erro;
  final VoidCallback onEscolher;
  final ValueChanged<FileAttachment> onRemover;

  const CampoAnexosPdf({
    super.key,
    required this.anexos,
    required this.envios,
    required this.onEscolher,
    required this.onRemover,
    this.erro,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const FieldLabel('Documentos Técnicos e Manuais (PDF)'),
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text(
            'Anexe ordens de serviço, manuais e desenhos técnicos',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
        _AreaEnvio(
          icone: LucideIcons.cloudUpload,
          titulo: 'Toque para escolher documentos',
          subtitulo: 'Suporta documentos PDF (máx 25MB)',
          onTap: onEscolher,
        ),
        if (erro != null) _MensagemErro(erro!),
        for (final e in envios)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.fileText, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          e.nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                        ),
                      ),
                      Text('${e.progresso}%', style: const TextStyle(fontSize: 12, color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: e.progresso / 100,
                      minHeight: 6,
                      backgroundColor: AppColors.border,
                      semanticsLabel: 'Enviando ${e.nome}',
                      semanticsValue: '${e.progresso}%',
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (anexos.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Documentos anexados (${anexos.length}):',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
          ),
          for (final a in anexos)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: LinhaAnexoPdf(
                anexo: a,
                rotuloAbrir: 'Visualizar',
                trailing: IconButton(
                  tooltip: 'Excluir anexo',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.danger),
                  onPressed: () => onRemover(a),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
