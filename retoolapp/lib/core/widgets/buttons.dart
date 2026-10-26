import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppButtonVariant { primary, secondary, danger, success, ghost }

/// Botão pílula do desktop (`.btn`, `.btn-primary`): altura mínima 44 (toque).
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Ícone depois do texto (ex.: seta do "Entrar no ReTool").
  final IconData? trailingIcon;
  final AppButtonVariant variant;
  final bool loading;
  final bool expand;
  final bool compact;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.variant = AppButtonVariant.secondary,
    this.loading = false,
    this.expand = false,
    this.compact = false,
  });

  const AppButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = false,
    this.compact = false,
  }) : variant = AppButtonVariant.primary;

  const AppButton.danger({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = false,
    this.compact = false,
  }) : variant = AppButtonVariant.danger;

  ({Color bg, Color fg, Color border}) get _cores => switch (variant) {
        AppButtonVariant.primary => (bg: AppColors.primary, fg: Colors.white, border: AppColors.primary),
        AppButtonVariant.danger => (bg: AppColors.danger, fg: Colors.white, border: AppColors.danger),
        AppButtonVariant.success => (bg: AppColors.success, fg: Colors.white, border: AppColors.success),
        AppButtonVariant.secondary => (bg: AppColors.surface, fg: AppColors.textDark, border: AppColors.border),
        AppButtonVariant.ghost => (bg: Colors.transparent, fg: AppColors.textBody, border: Colors.transparent),
      };

  @override
  Widget build(BuildContext context) {
    final c = _cores;
    final desabilitado = onPressed == null || loading;
    final conteudo = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: c.fg))
        else if (icon != null)
          Icon(icon, size: 18, color: c.fg),
        if (loading || icon != null) const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.fg, fontWeight: FontWeight.w600, fontSize: compact ? 13 : 15),
          ),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Icon(trailingIcon, size: 18, color: c.fg),
        ],
      ],
    );
    return Opacity(
      opacity: desabilitado && !loading ? 0.55 : 1,
      child: Material(
        color: c.bg,
        shape: StadiumBorder(side: BorderSide(color: c.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: desabilitado ? null : onPressed,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: compact ? 36 : 44),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 18, vertical: compact ? 6 : 10),
              child: Center(widthFactor: expand ? null : 1, heightFactor: 1, child: conteudo),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão circular com ícone (`.btn-icon`).
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool primary;
  final double size;
  final Color? color;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.primary = false,
    this.size = 40,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bg = primary ? AppColors.primary : AppColors.surface;
    final fg = color ?? (primary ? Colors.white : AppColors.textDark);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        shape: CircleBorder(side: BorderSide(color: primary ? AppColors.primary : AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: size * 0.48, color: fg, semanticLabel: tooltip),
          ),
        ),
      ),
    );
  }
}
