import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';

/// Rótulo de campo (`.input-label`).
class FieldLabel extends StatelessWidget {
  final String text;
  final bool obrigatorio;
  const FieldLabel(this.text, {super.key, this.obrigatorio = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text.rich(TextSpan(
          text: text,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
          children: [
            if (obrigatorio) const TextSpan(text: ' *', style: TextStyle(color: AppColors.primary)),
          ],
        )),
      );
}

/// Campo de texto com rótulo acima, como no desktop.
class AppTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? helper;
  final TextEditingController? controller;
  final String? initialValue;
  final IconData? prefixIcon;
  final bool obscure;
  final bool obrigatorio;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final bool enabled;
  final bool autofocus;
  final Iterable<String>? autofillHints;
  final Widget? suffix;

  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.helper,
    this.controller,
    this.initialValue,
    this.prefixIcon,
    this.obscure = false,
    this.obrigatorio = false,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.enabled = true,
    this.autofocus = false,
    this.autofillHints,
    this.suffix,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _oculto = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) FieldLabel(widget.label!, obrigatorio: widget.obrigatorio),
        TextFormField(
          controller: widget.controller,
          initialValue: widget.controller == null ? widget.initialValue : null,
          obscureText: _oculto,
          maxLines: widget.obscure ? 1 : widget.maxLines,
          minLines: widget.maxLines > 1 ? 2 : 1,
          maxLength: widget.maxLength,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          inputFormatters: widget.inputFormatters,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          validator: widget.validator,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          autofillHints: widget.autofillHints,
          style: const TextStyle(fontSize: 15, color: AppColors.textDark),
          decoration: InputDecoration(
            hintText: widget.hint,
            helperText: widget.helper,
            helperMaxLines: 3,
            helperStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon, size: 18) : null,
            suffixIcon: widget.obscure
                ? IconButton(
                    tooltip: _oculto ? 'Mostrar senha' : 'Ocultar senha',
                    icon: Icon(_oculto ? LucideIcons.eye : LucideIcons.eyeOff, size: 18),
                    onPressed: () => setState(() => _oculto = !_oculto),
                  )
                : widget.suffix,
          ),
        ),
      ],
    );
  }
}

/// Busca em pílula (Home/listas): borda vermelha no foco e botão de limpar.
class AppSearchField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool grande;

  const AppSearchField({
    super.key,
    required this.controller,
    this.hint = 'Buscar...',
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofocus = false,
    this.grande = false,
  });

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_rebuild);
    widget.controller.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_rebuild);
    widget.controller.removeListener(_rebuild);
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focado = _focus.hasFocus;
    final raio = BorderRadius.circular(30);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: raio,
        boxShadow: [
          BoxShadow(
            color: focado ? const Color(0x14E40D2C) : const Color(0x05000000),
            blurRadius: focado ? 12 : 6,
            offset: Offset(0, focado ? 6 : 4),
          ),
        ],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        autofocus: widget.autofocus,
        textInputAction: TextInputAction.search,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        style: TextStyle(fontSize: widget.grande ? 16 : 15, color: AppColors.textDark),
        decoration: InputDecoration(
          hintText: widget.hint,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: widget.grande ? 16 : 12),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 14, right: 6),
            child: Icon(LucideIcons.search, size: 18, color: AppColors.textMuted),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
          suffixIcon: widget.controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Limpar busca',
                  icon: const Icon(LucideIcons.x, size: 18, color: AppColors.textMuted),
                  onPressed: () {
                    widget.controller.clear();
                    widget.onChanged?.call('');
                  },
                ),
          border: OutlineInputBorder(borderRadius: raio, borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: raio, borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: raio, borderSide: const BorderSide(color: AppColors.primary)),
        ),
      ),
    );
  }
}

/// Seletor (dropdown) com rótulo acima, no padrão dos campos do desktop.
class AppDropdown<T> extends StatelessWidget {
  final String? label;
  final String? hint;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool obrigatorio;
  final String? Function(T?)? validator;

  const AppDropdown({
    super.key,
    this.label,
    this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    this.obrigatorio = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) FieldLabel(label!, obrigatorio: obrigatorio),
          DropdownButtonFormField<T>(
            initialValue: value,
            items: items,
            onChanged: onChanged,
            validator: validator,
            isExpanded: true,
            hint: hint != null ? Text(hint!, style: const TextStyle(color: AppColors.textMuted)) : null,
            icon: const Icon(LucideIcons.chevronDown, size: 18),
            borderRadius: BorderRadius.circular(AppRadius.md),
            style: const TextStyle(fontSize: 15, color: AppColors.textDark),
          ),
        ],
      );
}
