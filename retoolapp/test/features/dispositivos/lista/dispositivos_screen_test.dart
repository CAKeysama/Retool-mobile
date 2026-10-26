import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retoolapp/domain/entities/dispositivo.dart';
import 'package:retoolapp/features/dispositivos/dispositivo_detalhes_screen.dart';
import 'package:retoolapp/features/dispositivos/dispositivos_screen.dart';
import 'package:retoolapp/features/dispositivos/lista/dispositivo_card.dart';

import '../../../support/fakes.dart';
import '../../../support/harness.dart';

FakeBackend _backend(String perfil) {
  final b = FakeBackend();
  b.criarUsuario('u1', perfil: perfil, logar: true);
  b.semearDadosFabris();
  return b;
}

Finder _card(String nome) => find.ancestor(of: find.text(nome), matching: find.byType(DispositivoCard));

Future<void> _buscar(WidgetTester tester, String texto) async {
  await tester.enterText(find.byType(TextField), texto);
  await assentar(tester);
}

void main() {
  testWidgets('lista todos com contador, inativo, badges e reutilizações', (tester) async {
    await pumpTela(tester, _backend('admin'), const DispositivosScreen());

    expect(find.text('Dispositivos'), findsOneWidget);
    expect(find.text('3 dispositivos encontrados'), findsOneWidget);
    expect(find.byType(DispositivoCard), findsNWidgets(3));
    expect(find.descendant(of: _card('Suporte Inativo'), matching: find.text('Inativo')), findsOneWidget);
    final gabarito = _card('Gabarito de Furação Lateral');
    expect(find.descendant(of: gabarito, matching: find.text('Gabaritos')), findsOneWidget);
    expect(find.descendant(of: gabarito, matching: find.text('Preparo de Solo')), findsOneWidget);
    expect(find.descendant(of: gabarito, matching: find.text('SPE 5500')), findsOneWidget);
    expect(find.descendant(of: gabarito, matching: find.text('GAB-0042')), findsOneWidget);
    expect(
      find.descendant(of: gabarito, matching: find.text('2')),
      findsOneWidget,
      reason: '2 reutilizações',
    );
    expect(find.byTooltip('Cadastrar novo dispositivo'), findsOneWidget);
  });

  testWidgets('busca sem acento encontra "Válvula" e vazio mostra estado limpo', (tester) async {
    await pumpTela(tester, _backend('engenharia'), const DispositivosScreen());

    await _buscar(tester, 'valvula');
    expect(find.text('1 dispositivo encontrado'), findsOneWidget);
    expect(find.text('Válvula de Alívio'), findsOneWidget);
    expect(find.text('Gabarito de Furação Lateral'), findsNothing);

    await _buscar(tester, 'preparo de solo'); // pela família
    expect(find.text('Gabarito de Furação Lateral'), findsOneWidget);

    await _buscar(tester, 'xyz-inexistente');
    expect(find.text('Nenhum item encontrado.'), findsOneWidget);
    await tocar(tester, find.text('Limpar busca e filtros'));
    expect(find.text('3 dispositivos encontrados'), findsOneWidget);
    // Engenharia não cadastra.
    expect(find.byTooltip('Cadastrar novo dispositivo'), findsNothing);
  });

  testWidgets('busca inicial vinda da Home é aplicada', (tester) async {
    await pumpTela(tester, _backend('admin'), const DispositivosScreen(buscaInicial: 'GAB'));
    expect(find.text('1 dispositivo encontrado'), findsOneWidget);
    expect(find.text('Gabarito de Furação Lateral'), findsOneWidget);
  });

  testWidgets('filtro por categoria e por situação, com chips removíveis', (tester) async {
    await pumpTela(tester, _backend('admin'), const DispositivosScreen());

    await tocar(tester, find.bySemanticsLabel('Filtros'));
    await tocar(tester, find.byKey(const Key('filtro-categoria')));
    await tocar(tester, find.text('Ferramentas de Corte').last);
    await tocar(tester, find.text('Ver resultados'));

    expect(find.text('1 dispositivo encontrado'), findsOneWidget);
    expect(find.text('Válvula de Alívio'), findsOneWidget);
    expect(find.text('Categoria: Ferramentas de Corte'), findsOneWidget);

    await tocar(tester, find.byTooltip('Remover filtro'));
    expect(find.text('3 dispositivos encontrados'), findsOneWidget);

    await tocar(tester, find.bySemanticsLabel('Filtros'));
    await tocar(tester, find.text('Inativos'));
    await tocar(tester, find.text('Ver resultados'));
    expect(find.text('1 dispositivo encontrado'), findsOneWidget);
    expect(find.text('Suporte Inativo'), findsOneWidget);
  });

  testWidgets('filtro por processo industrial casa nome, descrição ou palavras-chave', (tester) async {
    final b = _backend('admin');
    b.dispositivos.seed(const [
      Dispositivo(id: 'p1', nome: 'Gabarito Drilling', codigo: 'DR-1'),
      Dispositivo(id: 'p2', nome: 'Suporte', codigo: 'SB-1', palavrasChave: ['shotblaster']),
    ]);
    await pumpTela(tester, b, const DispositivosScreen());

    await tocar(tester, find.bySemanticsLabel('Filtros'));
    await tocar(tester, find.byKey(const Key('filtro-processo')));
    await tocar(tester, find.text('Shotblaster').last);
    await tocar(tester, find.text('Ver resultados'));

    expect(find.text('1 dispositivo encontrado'), findsOneWidget);
    expect(find.text('Suporte'), findsOneWidget);
    expect(find.text('Processo: Shotblaster'), findsOneWidget);
  });

  testWidgets('Projetista desativa em massa (ativo:false) e não vê Excluir', (tester) async {
    final b = _backend('projetista');
    final c = await pumpTela(tester, b, const DispositivosScreen());

    await tester.longPress(_card('Gabarito de Furação Lateral'));
    await assentar(tester);
    expect(find.text('1 selecionado'), findsOneWidget);
    await tocar(tester, _card('Válvula de Alívio'));
    expect(find.text('2 selecionados'), findsOneWidget);
    expect(find.text('Excluir'), findsNothing);

    await tocar(tester, find.text('Desativar'));
    expect(find.text('Desativar itens'), findsOneWidget);
    await tocar(tester, find.text('Desativar 2'));

    expect(b.dispositivos.itens['d1']!.ativo, isFalse);
    expect(b.dispositivos.itens['d2']!.ativo, isFalse);
    expect(b.dispositivos.itens['d3']!.ativo, isFalse);
    expect(c.anuncios.last, '2 dispositivos desativados com sucesso');
    expect(find.text('2 selecionados'), findsNothing, reason: 'sai do modo seleção');
  });

  testWidgets('cancelar a confirmação não grava nada', (tester) async {
    final b = _backend('projetista');
    await pumpTela(tester, b, const DispositivosScreen());

    await tester.longPress(_card('Válvula de Alívio'));
    await assentar(tester);
    await tocar(tester, find.text('Desativar'));
    await tocar(tester, find.text('Cancelar'));
    expect(b.dispositivos.itens['d2']!.ativo, isTrue);
    expect(find.text('1 selecionado'), findsOneWidget);
  });

  testWidgets('selecionar inativo oferece Ativar', (tester) async {
    final b = _backend('admin');
    final c = await pumpTela(tester, b, const DispositivosScreen());

    await tester.longPress(_card('Suporte Inativo'));
    await assentar(tester);
    await tocar(tester, find.text('Ativar'));
    await tocar(tester, find.text('Ativar 1'));
    expect(b.dispositivos.itens['d3']!.ativo, isTrue);
    expect(c.anuncios.last, '1 dispositivo ativado com sucesso');
  });

  testWidgets('Administração exclui em massa com confirmação', (tester) async {
    final b = _backend('admin');
    final c = await pumpTela(tester, b, const DispositivosScreen());

    await tester.longPress(_card('Válvula de Alívio'));
    await assentar(tester);
    await tocar(tester, find.text('Excluir'));
    expect(find.textContaining('Esta ação não pode ser desfeita'), findsOneWidget);
    await tocar(tester, find.text('Excluir 1'));

    expect(b.dispositivos.itens.containsKey('d2'), isFalse);
    expect(c.anuncios.last, '1 dispositivo excluído com sucesso');
    expect(find.text('Válvula de Alívio'), findsNothing);
    expect(find.text('2 dispositivos encontrados'), findsOneWidget);
  });

  testWidgets('"Todos" seleciona todo o resultado filtrado', (tester) async {
    await pumpTela(tester, _backend('admin'), const DispositivosScreen());
    await tester.longPress(_card('Válvula de Alívio'));
    await assentar(tester);
    await tocar(tester, find.text('Todos (3)'));
    expect(find.text('3 selecionados'), findsOneWidget);
    await tocar(tester, find.byTooltip('Cancelar seleção'));
    expect(find.text('3 dispositivos encontrados'), findsOneWidget);
  });

  testWidgets('Engenharia não entra em seleção nem vê o menu de ações', (tester) async {
    await pumpApp(tester, _backend('engenharia'));
    await tocar(tester, find.descendant(of: find.byType(NavigationBar), matching: find.text('Dispositivos')));
    expect(find.byTooltip('Mais ações'), findsNothing);
    // Sem permissão, o toque longo age como toque simples (abre os detalhes).
    await tester.longPress(_card('Válvula de Alívio'));
    await assentar(tester);
    expect(find.text('1 selecionado'), findsNothing);
    expect(find.byType(DispositivoDetalhesScreen), findsOneWidget);
  });

  testWidgets('menu: Projetista importa, mas só a Administração verifica duplicados', (tester) async {
    await pumpTela(tester, _backend('projetista'), const DispositivosScreen());
    await tocar(tester, find.byTooltip('Mais ações'));
    expect(find.text('Importar planilha'), findsOneWidget);
    expect(find.text('Selecionar vários'), findsOneWidget);
    expect(find.text('Verificar duplicados'), findsNothing);
  });

  testWidgets('Administração revisa e remove duplicados sem vínculos', (tester) async {
    final b = _backend('admin');
    b.dispositivos.seed(const [
      Dispositivo(id: 'x1', nome: 'Bucha', codigo: 'BU-1', dataCriacao: '2026-01-01T00:00:00.000Z'),
      Dispositivo(id: 'x2', nome: 'bucha ', codigo: 'BU-1', dataCriacao: '2026-01-02T00:00:00.000Z'),
      Dispositivo(
        id: 'x3',
        nome: 'Bucha',
        codigo: 'BU-1',
        observacoes: 'tem nota',
        dataCriacao: '2026-01-03T00:00:00.000Z',
      ),
    ]);
    final c = await pumpTela(tester, b, const DispositivosScreen());

    await tocar(tester, find.byTooltip('Mais ações'));
    await tocar(tester, find.text('Verificar duplicados'));
    expect(find.text('Dispositivos duplicados'), findsOneWidget);
    expect(find.textContaining('1 combinações repetidas'), findsOneWidget);
    expect(find.text('Remover 2 duplicados'), findsOneWidget);

    // Sem "Revisei a lista" o botão não age.
    await tocar(tester, find.text('Remover 2 duplicados'));
    expect(b.dispositivos.itens.length, 6);

    await tocar(tester, find.text('Revisei a lista'));
    await tocar(tester, find.text('Remover 2 duplicados'));

    // Mantém o documento com vínculo (x3), remove os repetidos sem vínculo e preserva os demais.
    expect(b.dispositivos.itens.keys, containsAll(['x3', 'd1', 'd2', 'd3']));
    expect(b.dispositivos.itens.length, 4);
    expect(find.text('2 removidos.'), findsOneWidget);
    expect(c.anuncios.last, '2 dispositivos duplicados removidos.');
  });

  testWidgets('sem dispositivos mostra estado vazio com ação de cadastro', (tester) async {
    final b = FakeBackend()..criarUsuario('u1', perfil: 'admin', logar: true);
    await pumpTela(tester, b, const DispositivosScreen());
    expect(find.text('Nenhum dispositivo cadastrado'), findsOneWidget);
    expect(find.text('Cadastrar dispositivo'), findsOneWidget);
  });

  testWidgets('rolagem infinita carrega mais itens sob demanda', (tester) async {
    final b = FakeBackend()..criarUsuario('u1', perfil: 'gerencia', logar: true);
    b.dispositivos.seed([
      for (var i = 0; i < 120; i++) Dispositivo(id: 'm$i', nome: 'Disp ${i.toString().padLeft(3, '0')}', codigo: 'C$i'),
    ]);
    await pumpTela(tester, b, const DispositivosScreen());
    expect(find.text('120 dispositivos encontrados'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Disp 119'), 500, scrollable: find.byType(Scrollable).last);
    await assentar(tester);
    expect(find.text('Disp 119'), findsOneWidget);
  });

  testWidgets('sem overflow em 360 px, inclusive em modo seleção', (tester) async {
    await pumpTela(tester, _backend('admin'), const DispositivosScreen(), tamanho: const Size(360, 740));
    await tocar(tester, find.bySemanticsLabel('Filtros'));
    await tocar(tester, find.text('Inativos'));
    await tocar(tester, find.text('Ver resultados'));
    await tocar(tester, find.byTooltip('Remover filtro'));
    await tester.longPress(_card('Gabarito de Furação Lateral'));
    await assentar(tester);
    await tocar(tester, _card('Suporte Inativo'));
    expect(find.text('Desativar'), findsOneWidget);
    expect(find.text('Ativar'), findsOneWidget);
    expect(find.text('Excluir'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tocar no cartão abre os detalhes (com rotas)', (tester) async {
    await pumpApp(tester, _backend('admin'));
    await tocar(tester, find.descendant(of: find.byType(NavigationBar), matching: find.text('Dispositivos')));
    await tocar(tester, _card('Válvula de Alívio'));
    expect(find.byType(DispositivoDetalhesScreen), findsOneWidget);
  });
}
