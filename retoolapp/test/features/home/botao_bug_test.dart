import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retoolapp/features/home/widgets/botao_bug.dart';

void main() {
  testWidgets('explode, abre o formulário após 0,5 s e reaparece depois', (tester) async {
    var aberturas = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: BotaoBug(tempoOculto: const Duration(seconds: 1), onAbrir: () async => aberturas++),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    final botao = find.byKey(const Key('botao-bug'));
    expect(botao, findsOneWidget);

    await tester.tap(botao);
    await tester.pump(const Duration(milliseconds: 100));
    expect(botao, findsNothing, reason: 'some durante a explosão');
    expect(aberturas, 0);

    await tester.pump(const Duration(milliseconds: 450));
    expect(aberturas, 1);

    // Oculto (1 s) + reconstrução (0,6 s).
    await tester.pump(const Duration(milliseconds: 600));
    expect(botao, findsNothing);
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 400));
    expect(botao, findsOneWidget);
    expect(aberturas, 1);
  });

  testWidgets('toques repetidos durante a animação não reabrem o formulário', (tester) async {
    var aberturas = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: BotaoBug(onAbrir: () async => aberturas++)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('botao-bug')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(BotaoBug), warnIfMissed: false);
    await tester.pump(const Duration(seconds: 1));
    expect(aberturas, 1);
    // Desmonta com timers pendentes: o dispose precisa cancelá-los.
    await tester.pumpWidget(const SizedBox());
  });
}
