import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retoolapp/domain/entities/audit_log.dart';
import 'package:retoolapp/domain/entities/classificacao.dart';
import 'package:retoolapp/features/categorias/categorias_screen.dart';

import '../../support/fakes.dart';
import '../../support/harness.dart';

const _cat = TipoClassificacao.categoria;

FakeBackend _backend(String perfil) {
  final b = FakeBackend()..semearDadosFabris();
  b.criarUsuario('u', perfil: perfil, logar: true);
  return b;
}

Future<ControladoresTeste> _abrir(WidgetTester tester, FakeBackend b, {Size tamanho = const Size(412, 915)}) =>
    pumpTela(tester, b, const CategoriasScreen(), tamanho: tamanho);

Future<void> _aba(WidgetTester tester, String rotulo) =>
    tocar(tester, find.descendant(of: find.byType(TabBar), matching: find.text(rotulo)));

Classificacao? _porNome(FakeBackend b, TipoClassificacao t, String nome) =>
    b.classificacoes.itens(t).values.where((c) => c.nome == nome).firstOrNull;

void main() {
  testWidgets('lista os 3 tipos com contador e dispositivos vinculados', (tester) async {
    final b = _backend('admin');
    await _abrir(tester, b);

    expect(find.text('Classificações'), findsOneWidget);
    expect(find.text('Gabaritos'), findsOneWidget);
    expect(find.text('Ferramentas de Corte'), findsOneWidget);
    expect(find.byTooltip('1 dispositivo vinculado'), findsNWidgets(2));

    await _aba(tester, 'Famílias');
    expect(find.text('Famílias de Produto'), findsOneWidget);
    expect(find.text('Preparo de Solo'), findsOneWidget);
    expect(find.text('Colheita'), findsOneWidget);
    expect(find.text('Inativo'), findsOneWidget);

    await _aba(tester, 'Produtos');
    expect(find.text('SPE 5500'), findsOneWidget);
    expect(find.text('AVOLA 2500'), findsOneWidget);
  });

  testWidgets('botão "i" mostra o que é cada classificação', (tester) async {
    final b = _backend('admin');
    await _abrir(tester, b);
    await tocar(tester, find.byTooltip('O que são categorias?'));
    expect(find.textContaining('Grupos macro', findRichText: true), findsOneWidget);
    expect(find.textContaining('Exemplos: Ferramentas de Corte, EPIs, Gabaritos.', findRichText: true), findsOneWidget);
  });

  testWidgets('criar categoria grava, audita e avisa', (tester) async {
    final b = _backend('projetista');
    final c = await _abrir(tester, b);

    await tocar(tester, find.byTooltip('Criar novo registro em Categorias'));
    expect(find.text('Nova Categoria'), findsOneWidget);
    expect(find.textContaining('Nome da Categoria', findRichText: true), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '  EPIs ');
    await tocar(tester, find.text('Salvar'));

    final criada = _porNome(b, _cat, 'EPIs');
    expect(criada, isNotNull);
    expect(criada!.ativo, isTrue);
    expect(find.text('Nova Categoria'), findsNothing);
    expect(find.text('EPIs'), findsOneWidget);
    final log = b.audit.registros.last;
    expect(log.acao, AuditLogAcao.criacao);
    expect(log.acaoDescricao, 'Cadastrou categoria');
    expect(log.entidadeNome, 'EPIs');
    expect(c.anuncios, contains('Categoria adicionada com sucesso'));
  });

  testWidgets('nome duplicado (caixa, espaços e acentos) é recusado', (tester) async {
    final b = _backend('admin');
    await _abrir(tester, b);
    final antes = b.classificacoes.itens(_cat).length;

    await tocar(tester, find.byTooltip('Criar novo registro em Categorias'));
    await tester.enterText(find.byType(TextFormField), '  GABARÍTOS ');
    await tocar(tester, find.text('Salvar'));

    expect(find.text('Já existe uma categoria com este nome: "Gabaritos".'), findsOneWidget);
    expect(find.text('Nova Categoria'), findsOneWidget); // continua aberto
    expect(b.classificacoes.itens(_cat).length, antes);

    await tester.enterText(find.byType(TextFormField), '   ');
    await tocar(tester, find.text('Salvar'));
    expect(find.text('Informe o nome da categoria.'), findsOneWidget);
    expect(b.classificacoes.itens(_cat).length, antes);
  });

  testWidgets('editar nome grava e audita; tocar na linha também abre a edição', (tester) async {
    final b = _backend('projetista');
    await _abrir(tester, b);

    await tocar(tester, find.byTooltip('Editar categoria Gabaritos'));
    expect(find.text('Editar Categoria'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Gabaritos de Solda');
    await tocar(tester, find.text('Salvar'));

    expect(b.classificacoes.itens(_cat)['cat-1']!.nome, 'Gabaritos de Solda');
    expect(b.audit.registros.last.acaoDescricao, 'Editou categoria');
    expect(b.audit.registros.last.dadosAnteriores?['nome'], 'Gabaritos');

    // Renomear para o nome de outra categoria é bloqueado.
    await tocar(tester, find.text('Gabaritos de Solda'));
    expect(find.text('Editar Categoria'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'ferramentas de corte');
    await tocar(tester, find.text('Salvar'));
    expect(find.textContaining('Já existe uma categoria'), findsOneWidget);
    expect(b.classificacoes.itens(_cat)['cat-1']!.nome, 'Gabaritos de Solda');
  });

  testWidgets('projetista desativa e reativa (soft delete) e não vê excluir', (tester) async {
    final b = _backend('projetista');
    await _abrir(tester, b);

    expect(find.byTooltip('Excluir ou desativar categoria Gabaritos'), findsNothing);
    expect(find.byTooltip('Ações em massa para Categorias'), findsOneWidget);

    await tocar(tester, find.byTooltip('Desativar categoria Gabaritos'));
    expect(b.classificacoes.itens(_cat)['cat-1']!.ativo, isFalse);
    expect(b.audit.registros.last.conteudo?['valoresAlterados'], {'ativo': false});
    expect(find.text('Inativo'), findsOneWidget);

    await tocar(tester, find.byTooltip('Ativar categoria Gabaritos'));
    expect(b.classificacoes.itens(_cat)['cat-1']!.ativo, isTrue);

    // Ações em massa sem "Excluir".
    await tocar(tester, find.byTooltip('Ações em massa para Categorias'));
    expect(find.text('Desativar'), findsOneWidget);
    expect(find.text('Excluir'), findsNothing);
  });

  testWidgets('admin desativa pelo "Gerenciar" e ativa família inativa', (tester) async {
    final b = _backend('admin');
    await _abrir(tester, b);

    await tocar(tester, find.byTooltip('Excluir ou desativar categoria Ferramentas de Corte'));
    expect(find.text('Gerenciar Categoria'), findsOneWidget);
    await tocar(tester, find.widgetWithText(InkWell, 'Desativar'));
    expect(b.classificacoes.itens(_cat)['cat-2']!.ativo, isFalse);

    await _aba(tester, 'Famílias');
    await tocar(tester, find.byTooltip('Ativar família Colheita'));
    expect(b.classificacoes.itens(TipoClassificacao.familia)['fam-2']!.ativo, isTrue);
  });

  testWidgets('admin exclui com confirmação e aviso de dispositivos vinculados', (tester) async {
    final b = _backend('admin');
    final c = await _abrir(tester, b);

    await tocar(tester, find.byTooltip('Excluir ou desativar categoria Gabaritos'));
    expect(find.text('Gerenciar Categoria'), findsOneWidget);
    expect(find.text('1 dispositivo usa esta categoria'), findsOneWidget);

    // Cancelar não exclui.
    await tocar(tester, find.text('Cancelar'));
    expect(b.classificacoes.itens(_cat).containsKey('cat-1'), isTrue);

    await tocar(tester, find.byTooltip('Excluir ou desativar categoria Gabaritos'));
    await tocar(tester, find.text('Excluir Permanente'));

    expect(b.classificacoes.itens(_cat).containsKey('cat-1'), isFalse);
    expect(find.text('Gabaritos'), findsNothing);
    final log = b.audit.registros.last;
    expect(log.acao, AuditLogAcao.exclusao);
    expect(log.entidadeNome, 'Gabaritos');
    expect(c.anuncios, contains('Categoria removida com sucesso'));
  });

  testWidgets('ações em massa: desativar todos com progresso e toast resumo', (tester) async {
    final b = _backend('admin');
    final c = await _abrir(tester, b);

    await tocar(tester, find.byTooltip('Ações em massa para Categorias'));
    expect(find.text('Ações em Massa'), findsOneWidget);
    expect(find.text('Nenhum selecionado'), findsOneWidget);
    await tocar(tester, find.text('Selecionar todos (2)'));
    expect(find.text('2 selecionados', findRichText: true), findsOneWidget);

    await tocar(tester, find.widgetWithText(InkWell, 'Desativar'));
    expect(find.text('Desativar itens'), findsOneWidget);
    await tester.tap(find.text('Desativar 2'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('2 de 2 itens'), findsOneWidget);
    expect(find.text('Não feche esta janela'), findsOneWidget);
    await assentar(tester);

    expect(b.classificacoes.itens(_cat).values.every((x) => !x.ativo), isTrue);
    expect(c.anuncios, contains('2 categorias desativadas com sucesso'));
    expect(c.anuncios, isNot(contains('Categoria atualizada com sucesso'))); // silent
    expect(find.text('Ações em Massa'), findsNothing);

    // Reativa tudo em massa.
    await tocar(tester, find.byTooltip('Ações em massa para Categorias'));
    await tocar(tester, find.text('Selecionar todos (2)'));
    await tocar(tester, find.widgetWithText(InkWell, 'Ativar'));
    await tocar(tester, find.text('Ativar 2'));
    expect(b.classificacoes.itens(_cat).values.every((x) => x.ativo), isTrue);
    expect(c.anuncios, contains('2 categorias ativadas com sucesso'));
  });

  testWidgets('ações em massa: busca, seleção individual e exclusão', (tester) async {
    final b = _backend('admin');
    final c = await _abrir(tester, b);
    await _aba(tester, 'Produtos');

    await tocar(tester, find.byTooltip('Ações em massa para Produtos'));
    final buscaSheet = find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField));
    await tester.enterText(buscaSheet, 'avola');
    await assentar(tester);
    expect(find.text('Selecionar todos (1)'), findsOneWidget);
    await tocar(tester, find.descendant(of: find.byType(BottomSheet), matching: find.text('AVOLA 2500')));
    expect(find.text('1 selecionado', findRichText: true), findsOneWidget);

    await tocar(tester, find.widgetWithText(InkWell, 'Excluir'));
    expect(find.text('Excluir itens'), findsOneWidget);
    expect(find.textContaining('1 dispositivo(s) usam os itens selecionados'), findsOneWidget);
    await tocar(tester, find.text('Excluir 1'));

    expect(b.classificacoes.itens(TipoClassificacao.produto).keys, ['prod-1']);
    expect(c.anuncios, contains('1 produto excluído com sucesso'));
    expect(b.audit.registros.last.acao, AuditLogAcao.exclusao);
  });

  testWidgets('busca e filtro de situação no painel', (tester) async {
    final b = _backend('admin');
    await _abrir(tester, b);

    await tester.enterText(find.byType(TextField).first, 'ferr');
    await assentar(tester);
    expect(find.text('Ferramentas de Corte'), findsOneWidget);
    expect(find.text('Gabaritos'), findsNothing);
    expect(find.text('1 de 2'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'xyz');
    await assentar(tester);
    expect(find.text('Nenhum resultado'), findsOneWidget);

    await _aba(tester, 'Famílias');
    await tocar(tester, find.widgetWithText(ChoiceChip, 'Inativos'));
    expect(find.text('Colheita'), findsOneWidget);
    expect(find.text('Preparo de Solo'), findsNothing);
    await tocar(tester, find.widgetWithText(ChoiceChip, 'Ativos'));
    expect(find.text('Colheita'), findsNothing);
    expect(find.text('Preparo de Solo'), findsOneWidget);
  });

  testWidgets('sem overflow em 360x740 (lista, explicação, formulário, gerenciar e massa)', (tester) async {
    final b = _backend('admin');
    const longo = 'Categoria com um nome bem comprido para testar reticências';
    for (var i = 0; i < 30; i++) {
      await b.classificacoes.add(_cat, nome: '$longo $i');
    }
    await _abrir(tester, b, tamanho: const Size(360, 740));
    expect(tester.takeException(), isNull);

    await tocar(tester, find.byTooltip('O que são categorias?'));
    expect(tester.takeException(), isNull);

    await tocar(tester, find.byTooltip('Criar novo registro em Categorias'));
    expect(tester.takeException(), isNull);
    await tocar(tester, find.text('Cancelar'));

    await tocar(tester, find.byTooltip('Excluir ou desativar categoria $longo 0'));
    expect(tester.takeException(), isNull);
    await tocar(tester, find.text('Cancelar'));

    await tocar(tester, find.byTooltip('Ações em massa para Categorias'));
    await tocar(tester, find.text('Selecionar todos (32)'));
    expect(tester.takeException(), isNull);

    await tocar(tester, find.widgetWithText(InkWell, 'Excluir'));
    await tester.tap(find.text('Excluir 32'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.takeException(), isNull);
    await assentar(tester);
    expect(b.classificacoes.itens(_cat), isEmpty);
    expect(find.text('Nenhuma categoria cadastrada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deslizar troca de painel e preserva a busca de cada um', (tester) async {
    final b = _backend('admin');
    await _abrir(tester, b);
    await tester.enterText(find.byType(TextField).first, 'gab');
    await assentar(tester);

    await tester.fling(find.text('Gabaritos'), const Offset(-300, 0), 1000);
    await assentar(tester);
    expect(find.text('Preparo de Solo'), findsOneWidget);
    expect(find.text('Gabaritos'), findsNothing);

    await tester.fling(find.text('Preparo de Solo'), const Offset(300, 0), 1000);
    await assentar(tester);
    expect(find.text('Gabaritos'), findsOneWidget);
    expect(find.text('Ferramentas de Corte'), findsNothing); // busca "gab" mantida
  });

  testWidgets('no app, a aba Categorias da barra inferior abre as classificações', (tester) async {
    final b = _backend('admin');
    await pumpApp(tester, b);
    await tocar(tester, find.descendant(of: find.byType(NavigationBar), matching: find.text('Categorias')));
    expect(find.text('Classificações'), findsOneWidget);
    expect(find.text('Gabaritos'), findsOneWidget);
    expect(find.byTooltip('Criar novo registro em Categorias'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
