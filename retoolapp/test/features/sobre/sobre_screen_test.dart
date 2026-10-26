import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retoolapp/features/sobre/logo_fatec.dart';
import 'package:retoolapp/features/sobre/sobre_screen.dart';

import '../../support/fakes.dart';
import '../../support/harness.dart';

void main() {
  testWidgets('mostra identificação, contexto, objetivos, equipes e parceiros', (tester) async {
    await pumpTela(tester, FakeBackend(), const SobreScreen());

    expect(find.text('Sobre'), findsOneWidget);
    expect(find.text('Sobre o Projeto', findRichText: true), findsOneWidget);
    expect(find.text('Identificação, Contexto e Objetivos do ReTool'), findsOneWidget);
    expect(find.text('1. Identificação'), findsOneWidget);
    expect(find.text('Instituição: Fatec Matão', findRichText: true), findsOneWidget);
    expect(find.text('Parceira: Baldan', findRichText: true), findsOneWidget);

    final lista = find.byType(Scrollable).first;
    Future<void> rolarAte(Finder f) => tester.scrollUntilVisible(f, 250, scrollable: lista);

    await rolarAte(find.text('"Onde o dispositivo atual vira o ponto de partida do futuro."'));
    await rolarAte(find.text('3. Objetivos'));
    expect(find.text('Registrar a utilização de cada peça e sua aplicação.'), findsOneWidget);

    await rolarAte(find.text('4. Equipe (Fatec)'));
    for (final nome in desenvolvedoresRetool) {
      await rolarAte(find.text('• $nome'));
    }
    await rolarAte(find.text('Orientador'));
    await rolarAte(find.text('• Douglas Ribeiro'));

    await rolarAte(find.text('5. Envolvidos (Baldan)'));
    for (final nome in envolvidosBaldan) {
      await rolarAte(find.text('• $nome'));
    }

    await rolarAte(find.byType(LogoFatec));
    expect(find.text('EMPRESA PARCEIRA'), findsOneWidget);
    expect(find.bySemanticsLabel('Baldan Implementos Agrícolas'), findsOneWidget);
    expect(find.bySemanticsLabel('Fatec Matão - Luiz Marchesan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sem overflow em 360x740 do topo ao rodapé', (tester) async {
    await pumpTela(tester, FakeBackend(), const SobreScreen(), tamanho: const Size(360, 740));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('INSTITUIÇÃO DE ENSINO'), 300, scrollable: find.byType(Scrollable).first);
    await assentar(tester);
    expect(tester.takeException(), isNull);
  });

  test('SVG do Illustrator: classes CSS viram atributos fill', () {
    const svg =
        '<svg><style type="text/css">\n\t.st0{fill:#4A555C;}\n\t.st1{fill:#B01116;}\n</style>'
        '<path class="st0" d="M0"/><path class="st1" d="M1"/><path class="outra" d="M2"/></svg>';
    final r = svgSemClassesCss(svg);
    expect(r, contains('<path fill="#4A555C" d="M0"/>'));
    expect(r, contains('<path fill="#B01116" d="M1"/>'));
    expect(r, contains('class="outra"'));
    expect(r, isNot(contains('<style')));
  });
}
