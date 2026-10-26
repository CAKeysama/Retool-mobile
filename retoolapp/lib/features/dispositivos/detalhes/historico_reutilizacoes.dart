import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/reutilizacao.dart';

final _peso3 = NumberFormat('#,##0.000', 'pt_BR');

DateTime? _dataReferencia(Reutilizacao r) {
  final bruta = r.data.isNotEmpty ? r.data : (r.dataCriacao ?? '');
  return bruta.isEmpty ? null : DateTime.tryParse(bruta);
}

/// Histórico da mais recente para a mais antiga pela data da reutilização
/// (`data || dataCriacao`, mesmo critério do desktop). Ordenação estável.
List<Reutilizacao> ordenarHistoricoReutilizacoes(Iterable<Reutilizacao> lista) {
  final ordenada = lista.toList();
  mergeSort<Reutilizacao>(
    ordenada,
    compare: (a, b) {
      final da = _dataReferencia(a), db = _dataReferencia(b);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    },
  );
  return ordenada;
}

/// Data exibida no histórico (`data` ou, na falta, `dataCriacao`); vazio = "N/A".
String dataDaReutilizacao(Reutilizacao r) {
  final bruta = r.data.isNotEmpty ? r.data : (r.dataCriacao ?? '');
  if (bruta.isEmpty) return 'N/A';
  final f = formatarData(bruta);
  return f == '—' ? 'N/A' : f;
}

String formatarPesoPeca(double kg) => '${_peso3.format(kg)} kg';

/// Cabeçalho da seção "Histórico de Reutilizações" com as ações de cadastro.
class CabecalhoHistorico extends StatelessWidget {
  final List<Widget> acoes;
  const CabecalhoHistorico({super.key, this.acoes = const []});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        header: true,
        child: const Text(
          'Histórico de Reutilizações',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'Todas as reutilizações registradas para este dispositivo.',
        style: TextStyle(fontSize: 13.5, color: AppColors.textSubtle),
      ),
      if (acoes.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.md),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: acoes),
      ],
    ],
  );
}

/// Rodapé com total de reutilizações e hard saving acumulado.
class RodapeHistorico extends StatelessWidget {
  final int total;
  final double hardSaving;
  const RodapeHistorico({super.key, required this.total, required this.hardSaving});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.squarePen, size: 16, color: AppColors.textBody),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'Total de reutilizações: ',
                  style: const TextStyle(color: AppColors.textBody, fontWeight: FontWeight.w500),
                  children: [
                    TextSpan(
                      text: '$total',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            text: 'Hard Saving acumulado: ',
            style: const TextStyle(color: AppColors.textBody, fontWeight: FontWeight.w500, fontSize: 15),
            children: [
              TextSpan(
                text: formatarMoeda(hardSaving),
                style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Cartão expansível de uma reutilização (equivale à linha expansível da tabela do desktop).
class CartaoReutilizacao extends StatelessWidget {
  final Reutilizacao reutilizacao;
  final int numero;
  final bool maisRecente;
  final bool aberto;
  final VoidCallback onAlternar;
  final String? nomeProduto;
  final VoidCallback? onExcluir;

  const CartaoReutilizacao({
    super.key,
    required this.reutilizacao,
    required this.numero,
    required this.maisRecente,
    required this.aberto,
    required this.onAlternar,
    this.nomeProduto,
    this.onExcluir,
  });

  @override
  Widget build(BuildContext context) {
    final r = reutilizacao;
    final raio = BorderRadius.circular(AppRadius.md);
    final fundo = maisRecente
        ? const Color(0x08E40D2C)
        : aberto
        ? const Color(0xFFFAFAFA)
        : AppColors.surface;
    final responsavel = r.responsavel.isNotEmpty ? r.responsavel : (r.solicitanteNome ?? 'N/A');

    final cabecalho = Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: maisRecente ? AppColors.primary : const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$numero',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: maisRecente ? Colors.white : AppColors.textSubtle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: dataDaReutilizacao(r),
                          style: TextStyle(
                            fontSize: 13.5,
                            color: maisRecente ? AppColors.primary : AppColors.textDark,
                            fontWeight: maisRecente ? FontWeight.w600 : FontWeight.w400,
                          ),
                          children: [
                            if (maisRecente)
                              const TextSpan(
                                text: ' · mais recente',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w400),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(child: StatusReutilizacaoBadge(r.status)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  r.codigoPeca.isEmpty ? 'N/A' : r.codigoPeca,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark, fontSize: 14.5),
                ),
                if (r.descricaoPeca.isNotEmpty)
                  Text(
                    r.descricaoPeca,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSubtle),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(LucideIcons.user, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        responsavel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textBody),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      formatarMoeda(r.hardSaving),
                      style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              AnimatedRotation(
                turns: aberto ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(LucideIcons.chevronDown, size: 18, color: AppColors.textMuted),
                ),
              ),
              if (onExcluir != null)
                IconButton(
                  tooltip: 'Excluir reutilização',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.danger),
                  onPressed: onExcluir,
                ),
            ],
          ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(borderRadius: raio, boxShadow: AppShadows.sm),
      child: Material(
        color: fundo,
        shape: RoundedRectangleBorder(
          borderRadius: raio,
          side: BorderSide(color: maisRecente ? const Color(0x55E40D2C) : AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: maisRecente
              ? const BoxDecoration(
                  border: Border(left: BorderSide(color: AppColors.primary, width: 4)),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                button: true,
                expanded: aberto,
                hint: aberto ? 'Recolher detalhes' : 'Ver os detalhes completos',
                child: InkWell(onTap: onAlternar, child: cabecalho),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: aberto
                    ? _DetalhesReutilizacao(r: r, nomeProduto: nomeProduto)
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetalhesReutilizacao extends StatelessWidget {
  final Reutilizacao r;
  final String? nomeProduto;
  const _DetalhesReutilizacao({required this.r, this.nomeProduto});

  @override
  Widget build(BuildContext context) {
    final analise = r.aprovadorNome == null || r.aprovadorNome!.isEmpty
        ? null
        : '${r.aprovadorNome}${(r.dataAprovacao?.isNotEmpty ?? false) ? ' em ${formatarData(r.dataAprovacao)}' : ''}';
    final reprovada = r.status == ReutilizacaoStatus.naoAprovada && (r.motivoRejeicao?.isNotEmpty ?? false);
    final produto = nomeProduto ?? (r.produtoId.isNotEmpty ? r.produtoId : null);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final meia = (c.maxWidth - 16) / 2;
          Widget item(String rotulo, String valor, {bool inteiro = false, bool perigo = false}) => SizedBox(
            width: inteiro ? c.maxWidth : meia,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rotulo.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: perigo ? AppColors.danger : AppColors.textMuted,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: perigo ? AppColors.danger : const Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          );
          return Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              SizedBox(
                width: c.maxWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STATUS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    StatusReutilizacaoBadge(r.status, completo: true),
                  ],
                ),
              ),
              item(
                'Descrição da alteração realizada',
                r.descricaoAlteracao.isEmpty ? 'N/A' : r.descricaoAlteracao,
                inteiro: true,
              ),
              item('Descrição da peça', r.descricaoPeca.isEmpty ? 'N/A' : r.descricaoPeca, inteiro: true),
              item('Produto', produto ?? 'N/A'),
              item('Peso da peça', formatarPesoPeca(r.pesoPeca)),
              item('Hard Saving', formatarMoeda(r.hardSaving)),
              item('Nº OS', r.numeroOs.isEmpty ? '—' : r.numeroOs),
              item('Responsável', r.responsavel.isEmpty ? 'N/A' : r.responsavel),
              if (r.solicitanteNome?.isNotEmpty ?? false) item('Solicitante', r.solicitanteNome!),
              if (analise != null) item('Análise', analise, inteiro: true),
              if (reprovada) item('Motivo da não aprovação', r.motivoRejeicao!, inteiro: true, perigo: true),
            ],
          );
        },
      ),
    );
  }
}
