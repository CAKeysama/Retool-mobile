import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Logo "Fatec Matão – Luiz Marchesan" (`assets/images/fatec.svg`).
///
/// O SVG exportado do Illustrator pinta os traços via `<style>` (`.st0{fill:...}`),
/// que o renderizador do flutter_svg não aplica; as classes são convertidas em
/// atributos `fill` uma única vez e o resultado fica em cache.
class LogoFatec extends StatelessWidget {
  final double altura;
  const LogoFatec({super.key, this.altura = 50});

  static const asset = 'assets/images/fatec.svg';
  static const _proporcao = 2000 / 1043; // viewBox do arquivo
  static Future<String>? _cache;

  static Future<String> _carregar(AssetBundle bundle) => _cache ??= bundle.loadString(asset).then(svgSemClassesCss);

  @override
  Widget build(BuildContext context) {
    final largura = altura * _proporcao;
    return Semantics(
      container: true,
      image: true,
      label: 'Fatec Matão - Luiz Marchesan',
      child: SizedBox(
        width: largura,
        height: altura,
        child: FutureBuilder<String>(
          future: _carregar(DefaultAssetBundle.of(context)),
          builder: (_, snap) => snap.hasData
              ? SvgPicture.string(
                  snap.data!,
                  width: largura,
                  height: altura,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// Substitui `class="stN"` pelo `fill` declarado no bloco `<style>` do SVG.
String svgSemClassesCss(String svg) {
  final cores = <String, String>{
    for (final m in RegExp(r'\.([\w-]+)\s*\{\s*fill:\s*(#[0-9A-Fa-f]{3,8})\s*;?\s*\}').allMatches(svg)) m[1]!: m[2]!,
  };
  if (cores.isEmpty) return svg;
  return svg
      .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>'), '')
      .replaceAllMapped(RegExp(r'class="([\w-]+)"'), (m) => cores.containsKey(m[1]) ? 'fill="${cores[m[1]]}"' : m[0]!);
}
