import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/dispositivo.dart';
import '../../../domain/entities/reutilizacao.dart';
import '../reutilizacoes_logica.dart';

final _peso = NumberFormat('#,##0.000', 'pt_BR');

/// Chip de status do desktop (`chipDeStatus`): relógio nas etapas do Projetista.
class ChipStatusReutilizacao extends StatelessWidget {
  final ReutilizacaoStatus status;
  const ChipStatusReutilizacao(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final cor = corDoStatusReutilizacao(status);
    return Pill(
      label: status.rotuloCurto,
      fundo: cor.fundo,
      texto: cor.texto,
      tooltip: status.valor,
      icon: filaProjetistaStatus.contains(status) ? LucideIcons.clock : null,
    );
  }
}

/// Data exibida na listagem (`data`, senão `dataCriacao`; "N/A" sem data), como no desktop.
String dataDaReutilizacao(Reutilizacao r) {
  final bruto = r.data.isNotEmpty ? r.data : (r.dataCriacao ?? '');
  if (bruto.isEmpty) return 'N/A';
  final f = formatarData(bruto);
  return f == '—' ? 'N/A' : f;
}

String _ouNA(String? v) => (v == null || v.trim().isEmpty) ? 'N/A' : v;

/// Cartão de solicitação/registro de reutilização (a tabela do desktop vira cartões
/// expansíveis no celular). Toque no cartão expande; toque no dispositivo abre o detalhe.
class CartaoReutilizacao extends StatelessWidget {
  final Reutilizacao reutilizacao;
  final Dispositivo? dispositivo;
  final String? produtoNome;
  final bool destacado;
  final bool expandido;
  final VoidCallback onAlternar;
  final VoidCallback? onAbrirDispositivo;

  /// Botões do fluxo (somente nas abas de fila, como no desktop).
  final List<AcaoFluxo> acoes;
  final bool ocupado;
  final ValueChanged<AcaoFluxo>? onAcao;

  /// `null` = sem caixa de seleção (somente quem exclui seleciona, como no desktop).
  final bool? selecionado;
  final ValueChanged<bool>? onSelecionar;
  final VoidCallback? onExcluir;

  /// Fila: destaque com anel vermelho; histórico: fundo vermelho translúcido.
  final bool estiloFila;

  const CartaoReutilizacao({
    super.key,
    required this.reutilizacao,
    required this.dispositivo,
    required this.onAlternar,
    this.produtoNome,
    this.destacado = false,
    this.expandido = false,
    this.onAbrirDispositivo,
    this.acoes = const [],
    this.ocupado = false,
    this.onAcao,
    this.selecionado,
    this.onSelecionar,
    this.onExcluir,
    this.estiloFila = true,
  });

  @override
  Widget build(BuildContext context) {
    final r = reutilizacao;
    final raio = BorderRadius.circular(AppRadius.md);
    final fundo = destacado && !estiloFila
        ? const Color(0x0FE40D2C)
        : expandido
            ? const Color(0xFFFAFAFA)
            : AppColors.surface;
    final nomeDisp = (dispositivo?.nome?.trim().isNotEmpty ?? false) ? dispositivo!.nome! : 'Desconhecido';
    final codigoDisp = (dispositivo?.codigo?.trim().isNotEmpty ?? false) ? dispositivo!.codigo : null;
    final solicitante = (r.solicitanteNome?.trim().isNotEmpty ?? false)
        ? r.solicitanteNome!
        : (r.responsavel.trim().isNotEmpty ? r.responsavel : 'N/A');

    return Semantics(
      container: true,
      selected: destacado,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          borderRadius: raio,
          boxShadow: destacado && estiloFila
              ? const [BoxShadow(color: AppColors.primary, spreadRadius: 2)]
              : AppShadows.sm,
        ),
        child: Material(
          color: fundo,
          shape: RoundedRectangleBorder(borderRadius: raio, side: const BorderSide(color: AppColors.border)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onAlternar,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  if (selecionado != null) ...[
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: Checkbox(
                        value: selecionado,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        semanticLabel: 'Selecionar ${r.descricaoAlteracao.isEmpty ? r.id : r.descricaoAlteracao}',
                        onChanged: (v) => onSelecionar?.call(v ?? false),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(child: ChipStatusReutilizacao(r.status)),
                  const Spacer(),
                  Text(dataDaReutilizacao(r),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSubtle, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: expandido ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(LucideIcons.chevronDown, size: 18, color: AppColors.textMuted),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(
                  r.descricaoAlteracao.trim().isEmpty ? 'Descrição não informada' : r.descricaoAlteracao,
                  maxLines: expandido ? null : 2,
                  overflow: expandido ? null : TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                ),
                const SizedBox(height: 6),
                _LinkDispositivo(nome: nomeDisp, codigo: codigoDisp, onTap: onAbrirDispositivo),
                const SizedBox(height: 4),
                Wrap(spacing: 12, runSpacing: 2, children: [
                  _Meta(rotulo: 'Peça', valor: _ouNA(r.codigoPeca)),
                  _Meta(rotulo: 'Solicitante', valor: solicitante),
                  Text(formatarMoeda(r.hardSaving),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.success)),
                ]),
                if (r.status == ReutilizacaoStatus.naoAprovada &&
                    (r.motivoRejeicao?.trim().isNotEmpty ?? false) &&
                    !expandido) ...[
                  const SizedBox(height: 6),
                  Text('Motivo: ${r.motivoRejeicao}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.danger, fontWeight: FontWeight.w500)),
                ],
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.topCenter,
                  child: expandido ? _Detalhes(cartao: this) : const SizedBox(width: double.infinity),
                ),
                if (acoes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: [
                    for (final a in acoes)
                      AppButton(
                        key: ValueKey('acao-${r.id}-${a.para.name}'),
                        label: a.rotulo,
                        icon: a.icone,
                        compact: true,
                        variant: a.variante,
                        onPressed: ocupado ? null : () => onAcao?.call(a),
                      ),
                  ]),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkDispositivo extends StatelessWidget {
  final String nome;
  final String? codigo;
  final VoidCallback? onTap;
  const _LinkDispositivo({required this.nome, required this.codigo, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: 'Abrir dispositivo $nome',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            const Icon(LucideIcons.component, size: 14, color: AppColors.textSubtle),
            const SizedBox(width: 6),
            Flexible(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: nome,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, color: AppColors.textDark, decoration: TextDecoration.underline)),
                  if (codigo != null) TextSpan(text: ' · $codigo', style: const TextStyle(color: AppColors.textSubtle)),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(LucideIcons.chevronRight, size: 14, color: AppColors.textMuted),
            ],
          ]),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final String rotulo;
  final String valor;
  const _Meta({required this.rotulo, required this.valor});

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: [
          TextSpan(text: '$rotulo: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          TextSpan(text: valor),
        ]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
      );
}

class _Detalhes extends StatelessWidget {
  final CartaoReutilizacao cartao;
  const _Detalhes({required this.cartao});

  @override
  Widget build(BuildContext context) {
    final r = cartao.reutilizacao;
    final peca = '${_ouNA(r.codigoPeca)} — ${_ouNA(r.descricaoPeca)}';
    final analise = (r.aprovadorNome?.trim().isNotEmpty ?? false)
        ? '${r.aprovadorNome}${(r.dataAprovacao?.isNotEmpty ?? false) ? ' em ${formatarDataHora(r.dataAprovacao)}' : ''}'
        : null;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Divider(),
        const SizedBox(height: 4),
        InfoRow(label: 'Descrição da alteração', valor: _ouNA(r.descricaoAlteracao)),
        InfoRow(label: 'Peça', valor: peca),
        InfoRow(label: 'Peso', valor: '${_peso.format(r.pesoPeca)} kg'),
        InfoRow(label: 'Produto', valor: ouNaoInformado(cartao.produtoNome)),
        InfoRow(label: 'Hard Saving', valor: formatarMoeda(r.hardSaving)),
        InfoRow(label: 'Responsável', valor: _ouNA(r.responsavel)),
        InfoRow(label: 'Solicitante', valor: _ouNA(r.solicitanteNome)),
        InfoRow(label: 'OS', valor: r.numeroOs.trim().isEmpty ? '—' : r.numeroOs),
        InfoRow(label: 'Data', valor: dataDaReutilizacao(r)),
        if (r.dataCriacao?.isNotEmpty ?? false) InfoRow(label: 'Registrado em', valor: formatarDataHora(r.dataCriacao)),
        InfoRow(label: 'Status', valor: r.status.valor),
        if (analise != null) InfoRow(label: 'Análise', valor: analise),
        if (r.status == ReutilizacaoStatus.naoAprovada && (r.motivoRejeicao?.trim().isNotEmpty ?? false))
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppColors.erroBg, borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Motivo da não aprovação: ', style: TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: r.motivoRejeicao),
              ]),
              style: const TextStyle(fontSize: 13, color: AppColors.danger, height: 1.4),
            ),
          ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (cartao.onAbrirDispositivo != null)
            AppButton(
              label: 'Ver Dispositivo',
              icon: LucideIcons.externalLink,
              compact: true,
              onPressed: cartao.onAbrirDispositivo,
            ),
          if (cartao.onExcluir != null)
            AppButton(
              key: ValueKey('excluir-${r.id}'),
              label: 'Excluir',
              icon: LucideIcons.trash2,
              compact: true,
              variant: AppButtonVariant.danger,
              onPressed: cartao.onExcluir,
            ),
        ]),
      ]),
    );
  }
}
