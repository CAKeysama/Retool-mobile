import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retoolapp/features/dispositivos/dispositivo_detalhes_screen.dart';
import 'package:retoolapp/features/dispositivos/dispositivos_screen.dart';
import 'package:retoolapp/features/home/home_screen.dart';
import 'package:retoolapp/features/home/widgets/home_card.dart';

import '../../support/fakes.dart';
import '../../support/harness.dart';

FakeBackend _backend(String perfil) {
  final b = FakeBackend();
  b.criarUsuario('u1', perfil: perfil, logar: true);
  b.semearDadosFabris();
  return b;
}

Finder _cartao(String label) => find.ancestor(of: find.text(label), matching: find.byType(HomeCard));

void main() {
  testWidgets('renderiza logotipo, subtítulo e contagens dos cartões', (tester) async {
    await pumpApp(tester, _backend('admin'));

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Gestão de Dispositivos e Ferramentas Industriais'), findsOneWidget);
    expect(find.text('Sobre o Projeto'), findsOneWidget);
    expect(find.descendant(of: _cartao('Dispositivos'), matching: find.text('3')), findsOneWidget);
    expect(find.descendant(of: _cartao('Reutilizações'), matching: find.text('2')), findsOneWidget);
    expect(find.descendant(of: _cartao('Categorias'), matching: find.text('2')), findsOneWidget);
    expect(find.byTooltip('Cadastrar novo dispositivo'), findsOneWidget);
    expect(find.bySemanticsLabel('Reportar um bug'), findsOneWidget);
  });

  testWidgets('Engenharia não vê o "+" nem o cartão de Categorias', (tester) async {
    await pumpApp(tester, _backend('engenharia'));

    expect(find.byTooltip('Cadastrar novo dispositivo'), findsNothing);
    expect(find.byType(HomeCard), findsNWidgets(2));
    expect(_cartao('Categorias'), findsNothing);
  });

  testWidgets('sugestões aparecem, filtram sem acento e abrem o dispositivo', (tester) async {
    await pumpApp(tester, _backend('admin'));

    await tester.enterText(find.byType(TextField), 'valvula');
    await assentar(tester);
    expect(find.text('Válvula de Alívio'), findsOneWidget);
    expect(find.text('VAL-0007'), findsOneWidget);
    expect(find.text('Gabarito de Furação Lateral'), findsNothing);

    await tester.enterText(find.byType(TextField), 'gab');
    await assentar(tester);
    expect(find.text('Válvula de Alívio'), findsNothing);
    expect(find.text('Gabarito de Furação Lateral'), findsOneWidget);

    await tocar(tester, find.text('Gabarito de Furação Lateral'));
    expect(find.byType(DispositivoDetalhesScreen), findsOneWidget);
  });

  testWidgets('enviar a busca abre a lista filtrada', (tester) async {
    await pumpApp(tester, _backend('admin'));

    await tester.enterText(find.byType(TextField), 'valvula');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await assentar(tester);

    expect(find.byType(DispositivosScreen), findsOneWidget);
    expect(find.text('1 dispositivo encontrado'), findsOneWidget);
    expect(find.text('Válvula de Alívio'), findsOneWidget);
  });

  testWidgets('"Buscar dispositivos" e cartões navegam para as abas', (tester) async {
    await pumpApp(tester, _backend('admin'));

    await tester.enterText(find.byType(TextField), 'GAB');
    await tocar(tester, find.text('Buscar dispositivos'));
    expect(find.byType(DispositivosScreen), findsOneWidget);
    expect(find.text('1 dispositivo encontrado'), findsOneWidget);

    await tocar(tester, find.descendant(of: find.byType(NavigationBar), matching: find.text('Home')));
    await tocar(tester, _cartao('Dispositivos'));
    expect(find.byType(DispositivosScreen), findsOneWidget);
  });

  testWidgets('sem overflow em 360 px de largura', (tester) async {
    await pumpApp(tester, _backend('admin'), tamanho: const Size(360, 740));
    expect(find.byType(HomeCard), findsNWidgets(3));
    await tester.enterText(find.byType(TextField), 'a');
    await assentar(tester);
    expect(tester.takeException(), isNull);
  });
}
