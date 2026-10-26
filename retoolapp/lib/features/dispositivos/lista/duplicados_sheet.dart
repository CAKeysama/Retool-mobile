import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/dispositivo.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../presentation/state/retool_controller.dart';

/// Verificação de dispositivos repetidos (Código + Dispositivo) — `DuplicadosModal` do desktop.
/// Lista primeiro; só apaga depois da confirmação "Revisei a lista". Documentos com
/// vínculos (reutilizações, imagens, anexos, observações) nunca são apagados.
Future<void> mostrarDuplicados(BuildContext context) => showAppSheet<void>(
  context,
  titulo: 'Dispositivos duplicados',
  subtitulo: 'Mesma combinação Código + Dispositivo',
  builder: (_) => const DuplicadosConteudo(),
);

/// Grupos exibidos antes do "E mais N combinações".
const _maxGruposVisiveis = 50;

String _csvCampo(Object? v) => '"${(v ?? '').toString().replaceAll('"', '""')}"';

/// CSV da revisão (mesmas colunas do desktop, separador `;`, com BOM).
String gerarCsvDuplicados(PlanoLimpezaDuplicados plano) {
  final linhas = [
    ['acao', 'codigo', 'dispositivo', 'id', 'dataCriacao', 'motivo'].join(';'),
  ];
  String linha(String acao, Dispositivo d, String motivo) =>
      [acao, d.codigo, d.nome, d.id, d.dataCriacao, motivo].map(_csvCampo).join(';');
  for (final g in plano.grupos) {
    linhas.add(linha('manter', g.manter, 'documento mantido'));
    for (final d in g.remover) {
      linhas.add(linha('remover', d, 'repetido sem vínculos'));
    }
    for (final d in g.revisar) {
      linhas.add(linha('revisar', d, 'repetido com vínculos (não será apagado)'));
    }
  }
  return '﻿${linhas.join('\n')}';
}

class DuplicadosConteudo extends StatefulWidget {
  const DuplicadosConteudo({super.key});

  @override
  State<DuplicadosConteudo> createState() => _DuplicadosConteudoState();
}

class _DuplicadosConteudoState extends State<DuplicadosConteudo> {
  bool _confirmado = false;
  bool _processando = false;
  ResultadoExclusaoLote? _resultado;

  List<Dispositivo>? _baseDisp;
  Object? _baseReu;
  PlanoLimpezaDuplicados? _plano;

  PlanoLimpezaDuplicados _planoDe(ReToolController retool) {
    // Recalcula só quando os dados mudam (o plano percorre toda a coleção).
    if (_plano == null || !identical(_baseDisp, retool.dispositivos) || !identical(_baseReu, retool.reutilizacoes)) {
      _baseDisp = retool.dispositivos;
      _baseReu = retool.reutilizacoes;
      _plano = planejarLimpezaDuplicados(retool.dispositivos, retool.reutilizacoes.map((r) => r.dispositivoId).toSet());
    }
    return _plano!;
  }

  Future<void> _remover(PlanoLimpezaDuplicados plano) async {
    setState(() => _processando = true);
    try {
      final ids = plano.grupos.expand((g) => g.remover.map((d) => d.id)).toList();
      final r = await context.read<ReToolController>().limparDispositivosDuplicados(ids);
      if (!mounted) return;
      setState(() {
        _resultado = r;
        _confirmado = false;
      });
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _baixar(PlanoLimpezaDuplicados plano) async {
    final retool = context.read<ReToolController>();
    try {
      final hoje = DateTime.now().toIso8601String().substring(0, 10);
      final salvo = await FilePicker.saveFile(
        fileName: 'retool-duplicados-$hoje.csv',
        bytes: Uint8List.fromList(utf8.encode(gerarCsvDuplicados(plano))),
        mimeType: 'text/csv',
      );
      if (salvo != null) retool.announce('Lista de duplicados salva.');
    } catch (e) {
      debugPrint('Falha ao salvar CSV de duplicados: $e');
      retool.announce('Não foi possível salvar a lista.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final plano = _planoDe(context.watch<ReToolController>());
    final totalRemover = plano.totalRemover;
    String fmt(int n) => formatarNumero(n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${fmt(plano.totalDocumentos)} documentos · ${fmt(plano.combinacoesDistintas)} combinações Código + Dispositivo '
          'distintas · ${fmt(plano.grupos.length)} combinações repetidas',
          style: const TextStyle(fontSize: 13.5, color: AppColors.textBody, height: 1.45),
        ),
        if (_resultado != null) ...[
          const SizedBox(height: AppSpacing.md),
          InfoBox(
            tipo: _resultado!.erros > 0 ? InfoBoxTipo.erro : InfoBoxTipo.sucesso,
            mensagem:
                '${fmt(_resultado!.excluidos)} removidos'
                '${_resultado!.erros > 0 ? ', ${fmt(_resultado!.erros)} com erro' : ''}.',
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (plano.grupos.isEmpty)
          const Row(
            children: [
              Icon(LucideIcons.circleCheck, size: 20, color: AppColors.success),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nenhuma combinação repetida.',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark),
                ),
              ),
            ],
          )
        else ...[
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 13.5, color: AppColors.textDark, height: 1.45),
              children: [
                TextSpan(
                  text: fmt(totalRemover),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: ' repetidos sem vínculos podem ser removidos.'),
                if (plano.totalRevisar > 0) ...[
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: fmt(plano.totalRevisar),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' repetidos têm reutilizações, imagens, anexos ou observações e '),
                  const TextSpan(
                    text: 'não',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' serão apagados (revise manualmente).'),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              children: [
                for (final (i, g) in plano.grupos.take(_maxGruposVisiveis).indexed) ...[
                  if (i > 0) const Divider(),
                  _LinhaGrupo(grupo: g),
                ],
                if (plano.grupos.length > _maxGruposVisiveis) ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'E mais ${fmt(plano.grupos.length - _maxGruposVisiveis)} combinações — baixe a lista completa.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: AppColors.textBody),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: 'Baixar lista (.csv)',
              icon: LucideIcons.download,
              compact: true,
              onPressed: _processando ? null : () => _baixar(plano),
            ),
          ),
          if (totalRemover > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            CheckboxListTile(
              value: _confirmado,
              onChanged: _processando ? null : (v) => setState(() => _confirmado = v ?? false),
              title: const Text('Revisei a lista', style: TextStyle(fontSize: 14, color: AppColors.textDark)),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            AppButton.danger(
              label: _processando ? 'Removendo...' : 'Remover ${fmt(totalRemover)} duplicados',
              icon: LucideIcons.trash2,
              expand: true,
              loading: _processando,
              onPressed: _confirmado && !_processando ? () => _remover(plano) : null,
            ),
          ],
        ],
      ],
    );
  }
}

class _LinhaGrupo extends StatelessWidget {
  final GrupoDuplicado grupo;
  const _LinhaGrupo({required this.grupo});

  @override
  Widget build(BuildContext context) {
    final g = grupo;
    const estiloNum = TextStyle(fontSize: 12, color: AppColors.textSubtle);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ouNaoInformado(g.nome),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textDark),
          ),
          const SizedBox(height: 2),
          Text(
            'Código: ${ouNaoInformado(g.codigo)}',
            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text('Documentos: ${1 + g.remover.length + g.revisar.length}', style: estiloNum),
              Text(
                'Remover: ${g.remover.length}',
                style: estiloNum.copyWith(color: g.remover.isNotEmpty ? AppColors.primary : null),
              ),
              Text(
                'Revisar: ${g.revisar.length}',
                style: estiloNum.copyWith(color: g.revisar.isNotEmpty ? AppColors.avisoText : null),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
