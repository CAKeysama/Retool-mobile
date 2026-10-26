import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/dispositivo.dart';
import 'galeria_midias.dart';

const _naoInformado = 'Não informado';

/// Rótulo cinza em caixa alta + valor (padrão dos campos da ficha no desktop).
class CampoFicha extends StatelessWidget {
  final String rotulo;
  final String? valor;
  final Widget? child;
  const CampoFicha({super.key, required this.rotulo, this.valor, this.child});

  @override
  Widget build(BuildContext context) {
    final texto = ouNaoInformado(valor);
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rotulo.toUpperCase(),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          child ??
              Text(
                texto,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: texto == _naoInformado ? AppColors.textMuted : AppColors.textDark,
                ),
              ),
        ],
      ),
    );
  }
}

class _LinhaDupla extends StatelessWidget {
  final Widget a;
  final Widget b;
  const _LinhaDupla(this.a, this.b);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: b),
      ],
    ),
  );
}

/// Cartão "Dados da Peça e Dispositivo" (ficha técnica completa + mídias).
class FichaTecnicaCard extends StatelessWidget {
  final Dispositivo dispositivo;
  final String? categoria;
  final String? familia;
  final String? produto;
  const FichaTecnicaCard({super.key, required this.dispositivo, this.categoria, this.familia, this.produto});

  @override
  Widget build(BuildContext context) {
    final d = dispositivo;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.box, size: 16, color: AppColors.primary),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Dados da Peça e Dispositivo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _LinhaDupla(
            CampoFicha(rotulo: 'Nº dispositivo', valor: d.nome),
            CampoFicha(rotulo: 'Código peça', valor: d.codigo),
          ),
          _LinhaDupla(
            CampoFicha(rotulo: 'Peso dispositivo', valor: formatarPeso(d.peso)),
            CampoFicha(rotulo: 'Categoria', valor: categoria),
          ),
          _LinhaDupla(
            CampoFicha(rotulo: 'Família do Produto', valor: familia),
            CampoFicha(rotulo: 'Produto', valor: produto),
          ),
          _LinhaDupla(
            CampoFicha(
              rotulo: 'Status',
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatusDispositivoPill(ativo: d.ativo),
              ),
            ),
            CampoFicha(rotulo: 'Data de criação', valor: d.dataCriacao == null ? null : formatarData(d.dataCriacao)),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: CampoFicha(
              rotulo: 'Palavras chave',
              child: d.palavrasChave.isEmpty
                  ? const Text(_naoInformado, style: TextStyle(fontSize: 14.5, color: AppColors.textMuted))
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [for (final t in d.palavrasChave) AppBadge(t, cor: BadgeCor.pink)],
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: CampoFicha(rotulo: 'Descrição peça', valor: d.descricao),
          ),
          CampoFicha(rotulo: 'Observações', valor: d.observacoes),
          SecaoMidiasDispositivo(imagemPeca: d.imagemPeca, imagemDispositivo: d.imagemDispositivo, anexos: d.anexos),
        ],
      ),
    );
  }
}

/// Selo Ativo/Inativo do dispositivo.
class StatusDispositivoPill extends StatelessWidget {
  final bool ativo;
  const StatusDispositivoPill({super.key, required this.ativo});

  @override
  Widget build(BuildContext context) => ativo
      ? const Pill(label: '● Ativo', fundo: AppColors.sucessoBg, texto: AppColors.sucessoText)
      : const Pill(label: '● Inativo', fundo: Color(0xFFF3F4F6), texto: Color(0xFF4B5563));
}

/// Cor de badge determinística pelo nome (mesma regra `getBadgeColor` do desktop).
BadgeCor corDoBadgePorNome(String nome) {
  if (nome.isEmpty) return BadgeCor.neutro;
  return switch (nome.codeUnitAt(0) % 4) {
    0 => BadgeCor.pink,
    1 => BadgeCor.teal,
    2 => BadgeCor.yellow,
    _ => BadgeCor.blue,
  };
}

/// Cartão "Resumo do Dispositivo": métricas de reutilização e classificação.
class ResumoDispositivoCard extends StatelessWidget {
  final int totalReutilizacoes;
  final double hardSavingTotal;
  final String? primeira;
  final String? ultima;
  final String? categoria;
  final String? familia;
  final String? dataCriacao;

  const ResumoDispositivoCard({
    super.key,
    required this.totalReutilizacoes,
    required this.hardSavingTotal,
    this.primeira,
    this.ultima,
    this.categoria,
    this.familia,
    this.dataCriacao,
  });

  @override
  Widget build(BuildContext context) {
    Widget linha(String rotulo, Widget valor, {bool ultimaLinha = false}) => Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: ultimaLinha ? null : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(rotulo, style: const TextStyle(fontSize: 13.5, color: AppColors.textSubtle)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Align(alignment: Alignment.centerRight, child: valor),
          ),
        ],
      ),
    );
    Widget badge(String? nome) => (nome == null || nome.isEmpty)
        ? const Text('N/A', style: TextStyle(fontSize: 13.5, color: AppColors.textMuted))
        : AppBadge(nome, cor: corDoBadgePorNome(nome));
    const estiloData = TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textDark);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Resumo do Dispositivo',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark),
          ),
          const SizedBox(height: AppSpacing.sm),
          linha(
            'Reutilizações',
            Text(
              '$totalReutilizacoes',
              key: const Key('resumo_total_reutilizacoes'),
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 15),
            ),
          ),
          linha(
            'Hard Saving Total',
            Text(
              formatarMoeda(hardSavingTotal),
              key: const Key('resumo_hard_saving'),
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.success, fontSize: 15),
            ),
          ),
          linha('Primeira Reutilização', Text(primeira ?? 'N/A', style: estiloData)),
          linha('Última Reutilização', Text(ultima ?? 'N/A', style: estiloData)),
          linha('Categoria', badge(categoria)),
          linha('Família', badge(familia)),
          linha(
            'Cadastro',
            Text(formatarData(dataCriacao), style: const TextStyle(fontSize: 13.5, color: AppColors.textMuted)),
            ultimaLinha: true,
          ),
        ],
      ),
    );
  }
}
