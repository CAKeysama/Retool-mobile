import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';

/// Logotipo textual: "Re" cinza + "Tool" vermelho.
class ReToolLogo extends StatelessWidget {
  final double fontSize;
  final Color? corRe;
  const ReToolLogo({super.key, this.fontSize = 26, this.corRe});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'ReTool',
        child: ExcludeSemantics(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Re', style: TextStyle(color: corRe ?? AppColors.gray00)),
              const TextSpan(text: 'Tool', style: TextStyle(color: AppColors.primary)),
            ]),
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800, letterSpacing: -fontSize / 40, height: 1.1),
          ),
        ),
      );
}

/// Cartão do desktop (`.card`): borda cinza, raio 12, sombra leve.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final EdgeInsetsGeometry? margin;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.color,
    this.borderColor,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final raio = BorderRadius.circular(AppRadius.md);
    return Container(
      margin: margin,
      decoration: BoxDecoration(borderRadius: raio, boxShadow: AppShadows.sm),
      child: Material(
        color: color ?? AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: raio, side: BorderSide(color: borderColor ?? AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

enum InfoBoxTipo { info, erro, aviso, sucesso }

/// Caixas de aviso (informativo azul, erro vermelho, alerta amarelo, sucesso verde).
class InfoBox extends StatelessWidget {
  final String? titulo;
  final String mensagem;
  final InfoBoxTipo tipo;
  final Widget? acao;

  const InfoBox({super.key, this.titulo, required this.mensagem, this.tipo = InfoBoxTipo.info, this.acao});

  @override
  Widget build(BuildContext context) {
    final (bg, borda, texto, icone, corIcone) = switch (tipo) {
      InfoBoxTipo.info => (AppColors.infoBg, AppColors.infoBorder, AppColors.infoText, LucideIcons.info, const Color(0xFF2563EB)),
      InfoBoxTipo.erro => (AppColors.erroBg, AppColors.erroBg, AppColors.erroText, LucideIcons.circleAlert, AppColors.erroText),
      InfoBoxTipo.aviso => (AppColors.avisoBg, const Color(0xFFFDE68A), AppColors.avisoText, LucideIcons.triangleAlert, AppColors.avisoText),
      InfoBoxTipo.sucesso => (AppColors.sucessoBg, AppColors.sucessoBg, AppColors.sucessoText, LucideIcons.circleCheck, AppColors.sucessoText),
    };
    return Semantics(
      liveRegion: tipo == InfoBoxTipo.erro,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: borda),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icone, size: 16, color: corIcone)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (titulo != null)
                Text(titulo!, style: TextStyle(fontWeight: FontWeight.w700, color: texto, fontSize: 13.5)),
              Text(mensagem, style: TextStyle(color: texto, fontSize: 12.5, height: 1.45)),
              if (acao != null) Padding(padding: const EdgeInsets.only(top: 8), child: acao!),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Cabeçalho de página (h2 + subtítulo + ações), padrão `.flex-responsive-header`.
class PageHeader extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final List<Widget> acoes;
  const PageHeader({super.key, required this.titulo, this.subtitulo, this.acoes = const []});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(
                header: true,
                child: Text(titulo,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              ),
              if (subtitulo != null) ...[
                const SizedBox(height: 2),
                Text(subtitulo!, style: const TextStyle(fontSize: 14, color: AppColors.textBody)),
              ],
            ]),
          ),
          if (acoes.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.sm),
            Wrap(spacing: AppSpacing.sm, children: acoes),
          ],
        ]),
      );
}

/// Rótulo de seção em caixa alta ("MENU", "ATALHOS").
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.6)),
      );
}

/// Estado vazio limpo (ícone + título + descrição + ação opcional).
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String? descricao;
  final Widget? acao;
  const EmptyState({super.key, required this.icon, required this.titulo, this.descricao, this.acao});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.primary, size: 26),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            if (descricao != null) ...[
              const SizedBox(height: 6),
              Text(descricao!,
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: AppColors.textSubtle)),
            ],
            if (acao != null) ...[const SizedBox(height: AppSpacing.md), acao!],
          ]),
        ),
      );
}

/// Carregamento centralizado com mensagem (ex.: "Sincronizando sessão ReTool...").
class LoadingView extends StatelessWidget {
  final String? mensagem;
  const LoadingView({super.key, this.mensagem});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 3.5)),
          if (mensagem != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(mensagem!, style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ],
        ]),
      );
}

/// Esqueleto de carregamento para linhas de lista (percepção de velocidade).
class SkeletonList extends StatelessWidget {
  final int linhas;
  const SkeletonList({super.key, this.linhas = 6});

  @override
  Widget build(BuildContext context) => ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: linhas,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, _) => Container(
          height: 72,
          decoration: BoxDecoration(color: AppColors.hover.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      );
}

/// Linha "rótulo: valor" usada em fichas e detalhes.
class InfoRow extends StatelessWidget {
  final String label;
  final String valor;
  final IconData? icon;
  const InfoRow({super.key, required this.label, required this.valor, this.icon});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (icon != null) ...[Icon(icon, size: 16, color: AppColors.textMuted), const SizedBox(width: 8)],
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSubtle, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(valor,
                style: TextStyle(
                  fontSize: 14,
                  color: valor == 'Não informado' ? AppColors.textMuted : AppColors.textDark,
                  fontWeight: FontWeight.w500,
                )),
          ),
        ]),
      );
}
