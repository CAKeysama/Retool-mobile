import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';

/// Elementos visuais compartilhados pelos painéis da Administração
/// (equivalentes a `Feedback.tsx`, `Tabs.tsx` e `admin/estilos.ts` do desktop).

/// Cores do `estiloBotaoAcao` do desktop.
enum CorAcao { success, danger, primary, neutro, bloquear, desbloquear, senha }

/// Botão de ação compacto dos cartões administrativos (`.btn` + `estiloBotaoAcao`).
class BotaoAcao extends StatelessWidget {
  final String label;
  final IconData? icon;
  final CorAcao cor;
  final VoidCallback? onPressed;
  final bool loading;
  final String? tooltip;

  const BotaoAcao({
    super.key,
    required this.label,
    this.icon,
    this.cor = CorAcao.neutro,
    this.onPressed,
    this.loading = false,
    this.tooltip,
  });

  ({Color bg, Color fg, Color borda}) get _cores => switch (cor) {
        CorAcao.success => (bg: AppColors.success, fg: Colors.white, borda: AppColors.success),
        CorAcao.danger => (bg: AppColors.danger, fg: Colors.white, borda: AppColors.danger),
        CorAcao.primary => (bg: AppColors.primary, fg: Colors.white, borda: AppColors.primary),
        CorAcao.neutro => (bg: AppColors.surface, fg: AppColors.textDark, borda: AppColors.border),
        CorAcao.bloquear => (bg: const Color(0xFFFEF2F2), fg: const Color(0xFFB91C1C), borda: const Color(0xFFFCA5A5)),
        CorAcao.desbloquear => (bg: const Color(0xFFF0FDF4), fg: const Color(0xFF15803D), borda: const Color(0xFF86EFAC)),
        CorAcao.senha => (bg: const Color(0xFFFFFBEB), fg: const Color(0xFFB45309), borda: const Color(0xFFFCD34D)),
      };

  @override
  Widget build(BuildContext context) {
    final c = _cores;
    final desabilitado = onPressed == null || loading;
    final botao = Opacity(
      opacity: desabilitado && !loading ? 0.55 : 1,
      child: Material(
        color: c.bg,
        shape: StadiumBorder(side: BorderSide(color: c.borda)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: desabilitado ? null : onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (loading)
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: c.fg))
                else if (icon != null)
                  Icon(icon, size: 14, color: c.fg),
                if (loading || icon != null) const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.fg)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? botao : Tooltip(message: tooltip!, child: botao);
  }
}

/// Botão circular de ícone dos cartões (nova senha temporária, excluir).
class BotaoIconeAcao extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final CorAcao cor;
  final VoidCallback? onPressed;

  const BotaoIconeAcao({super.key, required this.icon, required this.tooltip, this.cor = CorAcao.neutro, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final c = BotaoAcao(label: '', cor: cor)._cores;
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: onPressed == null ? 0.4 : 1,
        child: Material(
          color: c.bg,
          shape: CircleBorder(side: BorderSide(color: c.borda)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(width: 36, height: 36, child: Icon(icon, size: 16, color: c.fg, semanticLabel: tooltip)),
          ),
        ),
      ),
    );
  }
}

enum TipoAviso { sucesso, erro, info }

/// Aviso do topo dos painéis (`Aviso` do desktop), com botão de fechar opcional.
class AvisoAdmin extends StatelessWidget {
  final TipoAviso tipo;
  final String texto;
  final VoidCallback? onFechar;
  final Widget? acao;

  const AvisoAdmin({super.key, required this.tipo, required this.texto, this.onFechar, this.acao});

  @override
  Widget build(BuildContext context) {
    final (fundo, cor, icone) = switch (tipo) {
      TipoAviso.sucesso => (const Color(0xFFDCFCE7), const Color(0xFF15803D), LucideIcons.circleCheck),
      TipoAviso.erro => (const Color(0xFFFEE2E2), const Color(0xFFB91C1C), LucideIcons.circleAlert),
      TipoAviso.info => (const Color(0xFFEFF6FF), const Color(0xFF1D4ED8), LucideIcons.info),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(AppRadius.sm)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icone, size: 16, color: cor)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(texto, style: TextStyle(color: cor, fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.45)),
              ?acao,
            ]),
          ),
          if (onFechar != null)
            InkResponse(
              onTap: onFechar,
              radius: 18,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(LucideIcons.x, size: 16, color: cor, semanticLabel: 'Fechar aviso'),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Carregamento inline (`EstadoCarregando`).
class EstadoCarregando extends StatelessWidget {
  final String mensagem;
  const EstadoCarregando({super.key, this.mensagem = 'Carregando...'});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2l, horizontal: AppSpacing.md),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5)),
          const SizedBox(width: 10),
          Flexible(child: Text(mensagem, style: const TextStyle(color: AppColors.textSubtle, fontSize: 14))),
        ]),
      );
}

/// Erro de carregamento (`EstadoErro`) com "Tentar novamente" opcional.
class EstadoErro extends StatelessWidget {
  final String mensagem;
  final VoidCallback? onTentarNovamente;
  const EstadoErro({super.key, required this.mensagem, this.onTentarNovamente});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.md),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(LucideIcons.circleAlert, size: 22, color: Color(0xFFB91C1C)),
          const SizedBox(height: AppSpacing.sm),
          Text(mensagem, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 14)),
          if (onTentarNovamente != null) ...[
            const SizedBox(height: AppSpacing.sm),
            BotaoAcao(label: 'Tentar novamente', onPressed: onTentarNovamente),
          ],
        ]),
      );
}

/// Estado vazio das filas (`EmptyState` de `Tabs.tsx`): ponto + mensagem cinza.
class FilaVazia extends StatelessWidget {
  final String mensagem;
  const FilaVazia(this.mensagem, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.md),
        child: Column(children: [
          const Text('•', style: TextStyle(fontSize: 26, color: AppColors.textMuted, height: 1)),
          const SizedBox(height: AppSpacing.sm),
          Text(mensagem, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
        ]),
      );
}

/// Cartão das filas administrativas (`cartaoAdmin`), com anel vermelho quando destacado.
class CartaoAdmin extends StatelessWidget {
  final Widget child;
  final bool destacado;
  final VoidCallback? onTap;
  final Color? cor;
  const CartaoAdmin({super.key, required this.child, this.destacado = false, this.onTap, this.cor});

  @override
  Widget build(BuildContext context) {
    final raio = BorderRadius.circular(AppRadius.md);
    return Container(
      decoration: BoxDecoration(
        borderRadius: raio,
        boxShadow: destacado ? const [BoxShadow(color: AppColors.primary, spreadRadius: 2)] : AppShadows.sm,
      ),
      child: Material(
        color: cor ?? AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: raio, side: const BorderSide(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 14), child: child),
        ),
      ),
    );
  }
}

/// Título de seção dos painéis ("Decisões recentes", "Pendentes (n)").
class TituloSecao extends StatelessWidget {
  final String texto;
  final Widget? trailing;
  const TituloSecao(this.texto, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(texto,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            ),
          ),
          ?trailing,
        ]),
      );
}

/// Texto secundário pequeno (e-mail, datas) dos cartões.
class TextoSecundario extends StatelessWidget {
  final String texto;
  final Color cor;
  final double tamanho;
  const TextoSecundario(this.texto, {super.key, this.cor = AppColors.textSubtle, this.tamanho = 12.5});

  @override
  Widget build(BuildContext context) => Text(texto, style: TextStyle(fontSize: tamanho, color: cor, height: 1.4));
}

/// Rola até o cartão destacado (vindo de notificação ou de "Analisar cadastro").
void rolarAteDestaque(GlobalKey chave) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final ctx = chave.currentContext;
    if (ctx != null && ctx.mounted) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.1);
    }
  });
}
