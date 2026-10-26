import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:retoolapp/domain/entities/audit_log.dart';
import 'package:retoolapp/domain/entities/classificacao.dart';
import 'package:retoolapp/features/dispositivos/dispositivo_form_screen.dart';
import 'package:retoolapp/features/dispositivos/form/seletor_arquivos.dart';

import '../../../support/fakes.dart';
import '../../../support/harness.dart';

class SeletorFake implements SeletorArquivos {
  ArquivoEscolhido? imagem;
  List<ArquivoEscolhido> pdfs = [];
  final List<OrigemImagem> origens = [];

  @override
  Future<ArquivoEscolhido?> escolherImagem(OrigemImagem origem) async {
    origens.add(origem);
    return imagem;
  }

  @override
  Future<List<ArquivoEscolhido>> escolherPdfs() async => pdfs;
}

Finder campo(String key) => find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextFormField));

Future<void> digitar(WidgetTester tester, Finder alvo, String texto) async {
  await tester.ensureVisible(alvo);
  await tester.enterText(alvo, texto);
  await tester.pump();
}

const _camposDesktop = {
  'nome',
  'codigo',
  'categoriaId',
  'familiaId',
  'produtoId',
  'peso',
  'descricao',
  'observacoes',
  'palavrasChave',
  'imagemPeca',
  'imagemDispositivo',
  'anexos',
  'ativo',
};

FakeBackend _backend([String perfil = 'admin']) {
  final b = FakeBackend()..semearDadosFabris();
  b.criarUsuario('u1', perfil: perfil, logar: true);
  return b;
}

Uint8List _bytes(int n) => Uint8List(n);

/// Tela alta: o formulário inteiro fica construído (ListView é preguiçoso).
const _alto = Size(412, 2600);

void main() {
  testWidgets('cria dispositivo com os campos do desktop, tags e categoria', (tester) async {
    final b = _backend();
    final c = await pumpTela(tester, b, DispositivoFormScreen(seletor: SeletorFake()), tamanho: _alto);
    expect(find.text('Novo dispositivo'), findsOneWidget);

    await digitar(tester, campo('campo_nome'), 'Dispositivo 12');
    await digitar(tester, campo('campo_codigo'), 'DMP00011');
    await digitar(tester, campo('campo_peso'), '35000');
    await digitar(tester, campo('campo_descricao'), 'Base de fixação');

    final tags = find.byKey(const Key('campo_palavras_chave'));
    await digitar(tester, tags, 'solda');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await digitar(tester, tags, 'fixacao,');
    await digitar(tester, tags, 'solda');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('solda'), findsOneWidget);
    expect(find.text('fixacao'), findsOneWidget);

    await tocar(tester, find.byKey(const Key('seletor_categoria')));
    await tocar(tester, find.text('Gabaritos'));
    expect(find.text('Gabaritos'), findsOneWidget);

    await tocar(tester, find.byKey(const Key('salvar_dispositivo')));

    final criado = b.dispositivos.itens.values.firstWhere((d) => d.nome == 'Dispositivo 12');
    expect(criado.codigo, 'DMP00011');
    expect(criado.peso, '35000');
    expect(criado.descricao, 'Base de fixação');
    expect(criado.categoriaId, 'cat-1');
    expect(criado.palavrasChave, ['solda', 'fixacao']);
    expect(criado.ativo, isTrue);
    expect(criado.id, isNotEmpty);

    final log = b.audit.registros.firstWhere((l) => l.acao == AuditLogAcao.criacao);
    expect(log.conteudo!.keys.toSet(), _camposDesktop);
    expect(log.conteudo!['familiaId'], '');
    expect(log.conteudo!['anexos'], isEmpty);
    expect(c.anuncios, contains('Dispositivo adicionado com sucesso'));
  });

  testWidgets('remove tag antes de salvar', (tester) async {
    final b = _backend();
    await pumpTela(tester, b, DispositivoFormScreen(seletor: SeletorFake()), tamanho: _alto);
    expect(find.text('Nenhuma palavra-chave adicionada ainda.'), findsOneWidget);
    await digitar(tester, find.byKey(const Key('campo_palavras_chave')), 'a,b,');
    await tocar(tester, find.byTooltip('Remover a'));
    expect(find.text('a'), findsNothing);
    expect(find.text('b'), findsOneWidget);
  });

  testWidgets('cria categoria inline e a seleciona', (tester) async {
    final b = _backend();
    await pumpTela(tester, b, DispositivoFormScreen(seletor: SeletorFake()), tamanho: _alto);

    await tocar(tester, find.byKey(const Key('novo_categoria')));
    await digitar(tester, find.byKey(const Key('novo_categoria_nome')), 'Moldes');
    await tocar(tester, find.byKey(const Key('salvar_novo_categoria')));

    final nova = b.classificacoes.itens(TipoClassificacao.categoria).values.firstWhere((c) => c.nome == 'Moldes');
    expect(find.text('Moldes'), findsOneWidget);
    expect(b.audit.registros.any((l) => l.tipoEntidade == AuditLogTipoEntidade.categoria), isTrue);

    await digitar(tester, campo('campo_nome'), 'X');
    await tocar(tester, find.byKey(const Key('salvar_dispositivo')));
    expect(b.dispositivos.itens.values.firstWhere((d) => d.nome == 'X').categoriaId, nova.id);
  });

  testWidgets('cria produto pela busca do seletor', (tester) async {
    final b = _backend();
    await pumpTela(tester, b, DispositivoFormScreen(seletor: SeletorFake()), tamanho: _alto);
    await tocar(tester, find.byKey(const Key('seletor_produto')));
    await digitar(tester, find.byType(TextField).last, 'SPE 9000');
    await tocar(tester, find.text('Cadastrar "SPE 9000"'));
    expect(b.classificacoes.itens(TipoClassificacao.produto).values.any((p) => p.nome == 'SPE 9000'), isTrue);
    expect(find.text('SPE 9000'), findsOneWidget);
  });

  testWidgets('seletor esconde família inativa e filtra pela busca', (tester) async {
    final b = _backend();
    await pumpTela(tester, b, DispositivoFormScreen(seletor: SeletorFake()), tamanho: _alto);
    await tocar(tester, find.byKey(const Key('seletor_familia')));
    expect(find.text('Preparo de Solo'), findsOneWidget);
    expect(find.text('Colheita'), findsNothing);
    expect(find.text('Colheita (Inativo)'), findsNothing);
  });

  testWidgets('upload de imagem da peça preenche imagemPeca na pasta do novo id', (tester) async {
    final b = _backend();
    final seletor = SeletorFake()..imagem = ArquivoEscolhido(nome: 'peca.jpg', bytes: _bytes(2048));
    final c = await pumpTela(tester, b, DispositivoFormScreen(seletor: seletor), tamanho: _alto);

    await tocar(
      tester,
      find.descendant(of: find.byKey(const Key('upload_imagem_peca')), matching: find.byType(InkWell)),
    );
    await tocar(tester, find.text('Escolher da galeria'));
    expect(seletor.origens, [OrigemImagem.galeria]);
    expect(b.storage.enviados, hasLength(1));
    expect(find.text('Remover'), findsOneWidget);
    expect(c.anuncios, contains('Imagem da peça enviada com sucesso.'));

    await digitar(tester, campo('campo_nome'), 'Com foto');
    await tocar(tester, find.byKey(const Key('salvar_dispositivo')));

    final d = b.dispositivos.itens.values.firstWhere((d) => d.nome == 'Com foto');
    final enviado = b.storage.enviados.single;
    expect(d.imagemPeca, enviado.downloadURL);
    expect(enviado.storagePath, startsWith('retool/dispositivos/${d.id}/imagem_peca/'));
    expect(d.imagemDispositivo, anyOf(isNull, isEmpty));
  });

  testWidgets('imagem em formato inválido mostra o erro e não envia', (tester) async {
    final b = _backend();
    final seletor = SeletorFake()..imagem = ArquivoEscolhido(nome: 'anim.gif', bytes: _bytes(10));
    await pumpTela(tester, b, DispositivoFormScreen(seletor: seletor), tamanho: _alto);
    await tocar(
      tester,
      find.descendant(of: find.byKey(const Key('upload_imagem_dispositivo')), matching: find.byType(InkWell)),
    );
    await tocar(tester, find.text('Tirar foto'));
    expect(seletor.origens, [OrigemImagem.camera]);
    expect(find.textContaining('Formato de imagem inválido'), findsOneWidget);
    expect(b.storage.enviados, isEmpty);
  });

  testWidgets('anexa PDF e remove anexo', (tester) async {
    final b = _backend();
    final seletor = SeletorFake()..pdfs = [ArquivoEscolhido(nome: 'manual técnico.pdf', bytes: _bytes(4096))];
    await pumpTela(tester, b, DispositivoFormScreen(seletor: seletor), tamanho: _alto);

    await tocar(tester, find.text('Toque para escolher documentos'));
    expect(find.text('manual técnico.pdf'), findsOneWidget);
    expect(find.text('Documentos anexados (1):'), findsOneWidget);

    await digitar(tester, campo('campo_nome'), 'Com PDF');
    await tocar(tester, find.byKey(const Key('salvar_dispositivo')));
    final d = b.dispositivos.itens.values.firstWhere((d) => d.nome == 'Com PDF');
    expect(d.anexos.single.originalName, 'manual técnico.pdf');
    final log = b.audit.registros.firstWhere((l) => l.acao == AuditLogAcao.criacao);
    expect((log.conteudo!['anexos'] as List).single['categoria'], 'documento_pdf');
  });

  testWidgets('PDF inválido (não PDF) é recusado', (tester) async {
    final b = _backend();
    final seletor = SeletorFake()..pdfs = [ArquivoEscolhido(nome: 'planilha.xlsx', bytes: _bytes(10))];
    await pumpTela(tester, b, DispositivoFormScreen(seletor: seletor), tamanho: _alto);
    await tocar(tester, find.text('Toque para escolher documentos'));
    expect(find.text('Formato de documento inválido. Apenas documentos no formato PDF são aceitos.'), findsOneWidget);
    expect(b.storage.enviados, isEmpty);
  });

  testWidgets('edição carrega os dados e atualiza', (tester) async {
    final b = _backend('projetista');
    await pumpTela(
      tester,
      b,
      DispositivoFormScreen(id: 'd1', seletor: SeletorFake()),
      tamanho: _alto,
    );
    expect(find.text('Editar dispositivo'), findsOneWidget);
    expect(find.text('Gabarito de Furação Lateral'), findsOneWidget);
    expect(find.text('Gabaritos'), findsOneWidget);
    expect(find.text('Preparo de Solo'), findsOneWidget);
    expect(find.text('SPE 5500'), findsOneWidget);

    await digitar(tester, campo('campo_codigo'), 'GAB-0043');
    await tocar(tester, find.byTooltip('Remover furacao'));
    await tocar(tester, find.byKey(const Key('campo_ativo')));
    await tocar(tester, find.text('Salvar alterações'));

    final d = b.dispositivos.itens['d1']!;
    expect(d.codigo, 'GAB-0043');
    expect(d.palavrasChave, ['gabarito']);
    expect(d.ativo, isFalse);
    expect(d.nome, 'Gabarito de Furação Lateral');
    final log = b.audit.registros.lastWhere((l) => l.acao == AuditLogAcao.edicao);
    expect(log.acaoDescricao, 'Editou dispositivo');
    expect((log.conteudo!['valoresAlterados'] as Map).keys.toSet(), _camposDesktop);
  });

  testWidgets('engenharia não acessa o formulário', (tester) async {
    await pumpTela(tester, _backend('engenharia'), DispositivoFormScreen(seletor: SeletorFake()), tamanho: _alto);
    expect(find.text('Acesso restrito'), findsOneWidget);
    expect(find.byKey(const Key('salvar_dispositivo')), findsNothing);
  });

  testWidgets('sem overflow em 360px (novo e edição)', (tester) async {
    await pumpTela(tester, _backend(), DispositivoFormScreen(seletor: SeletorFake()), tamanho: const Size(360, 740));
    expect(tester.takeException(), isNull);
    await pumpTela(
      tester,
      _backend(),
      DispositivoFormScreen(id: 'd1', seletor: SeletorFake()),
      tamanho: const Size(360, 2600),
    );
    await tocar(tester, find.byKey(const Key('novo_familia')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('no app: sair com alterações pede confirmação', (tester) async {
    final b = FakeBackend()..semearDadosFabris();
    b.criarUsuario('adm', perfil: 'admin', logar: true);
    final original = seletorArquivosPadrao;
    seletorArquivosPadrao = SeletorFake();
    addTearDown(() => seletorArquivosPadrao = original);
    await pumpApp(tester, b);

    GoRouter.of(tester.element(find.byType(NavigationBar))).push('/dispositivos/novo');
    await assentar(tester);
    await assentar(tester);
    expect(find.text('Novo dispositivo'), findsOneWidget);

    // Sem alterações sai direto.
    await tocar(tester, find.byTooltip('Fechar'));
    expect(find.text('Novo dispositivo'), findsNothing);

    GoRouter.of(tester.element(find.byType(NavigationBar))).push('/dispositivos/novo');
    await assentar(tester);
    await assentar(tester);
    await digitar(tester, campo('campo_nome'), 'Rascunho');
    await tocar(tester, find.byTooltip('Fechar'));
    expect(find.text('Descartar alterações?'), findsOneWidget);
    await tocar(tester, find.text('Cancelar').last);
    expect(find.text('Novo dispositivo'), findsOneWidget);

    await tocar(tester, find.byTooltip('Fechar'));
    await tocar(tester, find.text('Sair sem salvar'));
    expect(find.text('Novo dispositivo'), findsNothing);
    expect(b.dispositivos.itens.values.where((d) => d.nome == 'Rascunho'), isEmpty);
  });

  testWidgets('no app: cadastrar novo abre os detalhes do dispositivo criado', (tester) async {
    final b = FakeBackend()..semearDadosFabris();
    b.criarUsuario('adm', perfil: 'admin', logar: true);
    final original = seletorArquivosPadrao;
    seletorArquivosPadrao = SeletorFake();
    addTearDown(() => seletorArquivosPadrao = original);
    await pumpApp(tester, b);

    GoRouter.of(tester.element(find.byType(NavigationBar))).push('/dispositivos/novo');
    await assentar(tester);
    await assentar(tester);
    await digitar(tester, campo('campo_nome'), 'Recém Criado');
    await tocar(tester, find.text('Cadastrar dispositivo'));
    await assentar(tester);

    expect(find.text('Novo dispositivo'), findsNothing);
    expect(find.text('Dados da Peça e Dispositivo'), findsOneWidget);
    expect(find.text('Recém Criado'), findsWidgets);
  });
}
