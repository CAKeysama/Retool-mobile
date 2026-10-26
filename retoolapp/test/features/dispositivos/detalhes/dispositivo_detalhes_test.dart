import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:retoolapp/core/utils/formatters.dart';
import 'package:retoolapp/domain/entities/audit_log.dart';
import 'package:retoolapp/domain/entities/dispositivo.dart';
import 'package:retoolapp/domain/entities/file_attachment.dart';
import 'package:retoolapp/domain/entities/reutilizacao.dart';
import 'package:retoolapp/features/dispositivos/detalhes/galeria_midias.dart';
import 'package:retoolapp/features/dispositivos/detalhes/historico_reutilizacoes.dart';
import 'package:retoolapp/features/dispositivos/dispositivo_detalhes_screen.dart';

import '../../../support/fakes.dart';
import '../../../support/harness.dart';

const _alto = Size(412, 3200);

FakeBackend _backend(String perfil) {
  final b = FakeBackend()..semearDadosFabris();
  b.criarUsuario('u1', perfil: perfil, nome: 'Usuária Teste', logar: true);
  return b;
}

void main() {
  setUpAll(prepararLocale);

  group('ordenarHistoricoReutilizacoes', () {
    test('mais recente primeiro pela data (ou dataCriacao) e estável', () {
      const lista = [
        Reutilizacao(id: 'a', dispositivoId: 'd', data: '2026-01-01'),
        Reutilizacao(id: 'b', dispositivoId: 'd', data: '', dataCriacao: '2026-03-01T10:00:00.000Z'),
        Reutilizacao(id: 'c', dispositivoId: 'd', data: '2026-02-01'),
        Reutilizacao(id: 'd', dispositivoId: 'd'),
        Reutilizacao(id: 'e', dispositivoId: 'd', data: '2026-02-01'),
      ];
      expect(ordenarHistoricoReutilizacoes(lista).map((r) => r.id), ['b', 'c', 'e', 'a', 'd']);
    });

    test('data exibida e peso da peça', () {
      expect(dataDaReutilizacao(const Reutilizacao(id: 'x', dispositivoId: 'd', data: '2026-02-10')), '10/02/2026');
      expect(dataDaReutilizacao(const Reutilizacao(id: 'x', dispositivoId: 'd')), 'N/A');
      expect(formatarPesoPeca(2.15), '2,150 kg');
    });
  });

  testWidgets('mostra a ficha técnica completa, métricas e histórico ordenado', (tester) async {
    final b = _backend('admin');
    await pumpTela(tester, b, const DispositivoDetalhesScreen(id: 'd1'), tamanho: _alto);

    expect(find.text('Gabarito de Furação Lateral'), findsWidgets);
    expect(find.text('GAB-0042'), findsWidgets);
    expect(find.text('14.5 kg'), findsOneWidget);
    expect(find.text('Gabaritos'), findsWidgets);
    expect(find.text('Preparo de Solo'), findsWidgets);
    expect(find.text('SPE 5500'), findsWidgets);
    expect(find.text('gabarito'), findsOneWidget);
    expect(find.text('furacao'), findsOneWidget);
    expect(find.text('Dispositivo para furação em chapa 3/8'), findsOneWidget);
    expect(find.text('01/01/2026'), findsWidgets); // data de criação
    expect(find.text('● Ativo'), findsWidgets);

    // Hard saving somado e totais.
    final total = tester.widget<Text>(find.byKey(const Key('resumo_hard_saving')));
    expect(total.data, formatarMoeda(19500));
    expect(tester.widget<Text>(find.byKey(const Key('resumo_total_reutilizacoes'))).data, '2');
    expect(find.text('15/01/2026'), findsWidgets); // primeira
    expect(find.text('10/02/2026'), findsWidgets); // última

    final cartoes = tester.widgetList<CartaoReutilizacao>(find.byType(CartaoReutilizacao)).toList();
    expect(cartoes.map((c) => c.reutilizacao.id), ['r1', 'r2']);
    expect(cartoes.first.maisRecente, isTrue);
    expect(cartoes.first.numero, 2);
    expect(find.text('Total de reutilizações: '), findsNothing); // é rich text
    expect(find.textContaining('Total de reutilizações', findRichText: true), findsOneWidget);
  });

  testWidgets('campos vazios exibem "Não informado"', (tester) async {
    final b = _backend('admin');
    await pumpTela(tester, b, const DispositivoDetalhesScreen(id: 'd2'), tamanho: _alto);
    // d2 não tem família, peso, descrição, observações nem palavras-chave.
    expect(find.text('Não informado'), findsNWidgets(5));
    expect(find.text('Nenhuma reutilização registrada ainda.'), findsOneWidget);
    expect(find.text(formatarMoeda(0)), findsOneWidget);
  });

  testWidgets('cartão do histórico expande com todos os campos', (tester) async {
    final b = _backend('admin');
    await pumpTela(tester, b, const DispositivoDetalhesScreen(id: 'd1'), tamanho: _alto);
    expect(find.text('Usinagem de 2 furos'), findsNothing);

    await tocar(tester, find.text('PC-5501'));
    expect(find.text('Usinagem de 2 furos'), findsOneWidget);
    expect(find.text('OS-1'), findsOneWidget);
    expect(find.text('2,150 kg'), findsOneWidget);
    expect(find.text('Engenheiro'), findsOneWidget);
    expect(find.text('Em análise (Projetista)'), findsOneWidget); // status completo

    await tocar(tester, find.text('PC-5501'));
    expect(find.text('Usinagem de 2 furos'), findsNothing);
  });

  testWidgets('reprovada mostra o motivo e a análise', (tester) async {
    final b = _backend('admin');
    b.reutilizacoes.seed(const [
      Reutilizacao(
        id: 'r9',
        dispositivoId: 'd2',
        data: '2026-03-01',
        codigoPeca: 'PC-9',
        status: ReutilizacaoStatus.naoAprovada,
        aprovadorNome: 'Paula Projetista',
        dataAprovacao: '2026-03-02T12:00:00.000Z',
        motivoRejeicao: 'Dispositivo sem folga',
      ),
    ]);
    await pumpTela(tester, b, const DispositivoDetalhesScreen(id: 'd2'), tamanho: _alto);
    await tocar(tester, find.text('PC-9'));
    expect(find.text('Dispositivo sem folga'), findsOneWidget);
    expect(find.text('Paula Projetista em 02/03/2026'), findsOneWidget);
  });

  group('ações por perfil', () {
    testWidgets('admin vê editar, excluir, nova e solicitar', (tester) async {
      await pumpTela(tester, _backend('admin'), const DispositivoDetalhesScreen(id: 'd1'), tamanho: _alto);
      expect(find.byTooltip('Editar'), findsOneWidget);
      expect(find.byTooltip('Excluir dispositivo'), findsOneWidget);
      expect(find.text('Nova Reutilização'), findsOneWidget);
      expect(find.text('Solicitar Reutilização'), findsOneWidget);
      expect(find.byTooltip('Excluir reutilização'), findsNWidgets(2));
    });

    testWidgets('projetista edita mas não exclui', (tester) async {
      await pumpTela(tester, _backend('projetista'), const DispositivoDetalhesScreen(id: 'd1'), tamanho: _alto);
      expect(find.byTooltip('Editar'), findsOneWidget);
      expect(find.byTooltip('Excluir dispositivo'), findsNothing);
      expect(find.text('Nova Reutilização'), findsOneWidget);
      expect(find.byTooltip('Excluir reutilização'), findsNothing);
    });

    testWidgets('engenharia não vê Editar/Excluir e vê Solicitar', (tester) async {
      await pumpTela(tester, _backend('engenharia'), const DispositivoDetalhesScreen(id: 'd1'), tamanho: _alto);
      expect(find.byTooltip('Editar'), findsNothing);
      expect(find.byTooltip('Excluir dispositivo'), findsNothing);
      expect(find.text('Nova Reutilização'), findsNothing);
      expect(find.text('Solicitar Reutilização'), findsOneWidget);
    });

    testWidgets('gerência só consulta', (tester) async {
      await pumpTela(tester, _backend('gerencia'), const DispositivoDetalhesScreen(id: 'd1'), tamanho: _alto);
      expect(find.byTooltip('Editar'), findsNothing);
      expect(find.byTooltip('Excluir dispositivo'), findsNothing);
      expect(find.text('Solicitar Reutilização'), findsNothing);
      expect(find.text('Nova Reutilização'), findsNothing);
      expect(find.text('Gabarito de Furação Lateral'), findsWidgets);
    });
  });

  testWidgets('excluir confirma, remove dispositivo e reutilizações e audita', (tester) async {
    final b = _backend('admin');
    await pumpTela(tester, b, const DispositivoDetalhesScreen(id: 'd1'));

    await tocar(tester, find.byTooltip('Excluir dispositivo'));
    expect(find.text('Excluir dispositivo'), findsOneWidget); // título do diálogo
    await tocar(tester, find.text('Cancelar'));
    expect(b.dispositivos.itens.containsKey('d1'), isTrue);

    await tocar(tester, find.byTooltip('Excluir dispositivo'));
    await tocar(tester, find.text('Excluir'));

    expect(b.dispositivos.itens.containsKey('d1'), isFalse);
    expect(b.reutilizacoes.itens.values.where((r) => r.dispositivoId == 'd1'), isEmpty);
    final log = b.audit.registros.lastWhere((l) => l.acao == AuditLogAcao.exclusao);
    expect(log.tipoEntidade, AuditLogTipoEntidade.dispositivo);
    expect(log.entidadeId, 'd1');
  });

  testWidgets('excluir reutilização do histórico (admin)', (tester) async {
    final b = _backend('admin');
    await pumpTela(tester, b, const DispositivoDetalhesScreen(id: 'd1'), tamanho: _alto);
    await tocar(tester, find.byTooltip('Excluir reutilização').last);
    expect(find.text('Apagar esta reutilização?'), findsOneWidget);
    await tocar(tester, find.text('Excluir'));
    expect(b.reutilizacoes.itens.containsKey('r2'), isFalse);
    expect(b.reutilizacoes.itens.containsKey('r1'), isTrue);
  });

  testWidgets('dispositivo inexistente mostra estado vazio com voltar', (tester) async {
    await pumpTela(tester, _backend('admin'), const DispositivoDetalhesScreen(id: 'nao-existe'));
    expect(find.text('Dispositivo não encontrado'), findsOneWidget);
    expect(find.text('Voltar'), findsOneWidget);
  });

  testWidgets('mostra carregamento enquanto os dispositivos não chegam', (tester) async {
    final b = FakeBackend()..semearDadosFabris(); // sem sessão: controller não assina
    await pumpTela(tester, b, const DispositivoDetalhesScreen(id: 'd1'));
    expect(find.text('Carregando dispositivo...'), findsOneWidget);
  });

  testWidgets('anexo PDF abre no app externo', (tester) async {
    final b = _backend('engenharia');
    b.dispositivos.seed(const [
      Dispositivo(
        id: 'd9',
        nome: 'Com Manual',
        anexos: [
          FileAttachment(
            id: 'f1',
            originalName: 'manual.pdf',
            fileName: 'f1_manual.pdf',
            contentType: 'application/pdf',
            size: 2048,
            storagePath: 'retool/dispositivos/d9/documento_pdf/f1_manual.pdf',
            downloadURL: 'https://fake.storage/manual.pdf',
            uploadedAt: '2026-02-01T10:00:00.000Z',
            categoria: CategoriaAnexo.documentoPdf,
          ),
        ],
      ),
    ]);
    final abertas = <String>[];
    final original = abrirUrlExterna;
    abrirUrlExterna = (u) async {
      abertas.add(u);
      return true;
    };
    addTearDown(() => abrirUrlExterna = original);

    await pumpTela(tester, b, const DispositivoDetalhesScreen(id: 'd9'));
    expect(find.text('manual.pdf'), findsOneWidget);
    expect(find.text('2 KB • 01/02/2026'), findsOneWidget);
    await tocar(tester, find.text('Abrir'));
    expect(abertas, ['https://fake.storage/manual.pdf']);
  });

  testWidgets('imagens abrem em tela cheia com zoom', (tester) async {
    final b = _backend('engenharia');
    b.dispositivos.seed(const [Dispositivo(id: 'd8', nome: 'Com Foto', imagemPeca: 'https://fake.storage/peca.jpg')]);
    await pumpTela(tester, b, const DispositivoDetalhesScreen(id: 'd8'));
    expect(find.text('IMAGEM PEÇA'), findsOneWidget);
    expect(find.text('Imagem dispositivo'), findsNothing);
    await tocar(tester, find.descendant(of: find.byType(CartaoImagem), matching: find.byType(InkWell)));
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tocar(tester, find.byTooltip('Fechar'));
    expect(find.byType(InteractiveViewer), findsNothing);
  });

  testWidgets('sem overflow em 360px', (tester) async {
    await pumpTela(tester, _backend('admin'), const DispositivoDetalhesScreen(id: 'd1'), tamanho: const Size(360, 740));
    expect(tester.takeException(), isNull);
    await pumpTela(
      tester,
      _backend('admin'),
      const DispositivoDetalhesScreen(id: 'd1'),
      tamanho: const Size(360, 2600),
    );
    await tocar(tester, find.text('PC-5501'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('fluxo no app: lista → detalhes → editar → salvar volta aos detalhes', (tester) async {
    final b = FakeBackend()..semearDadosFabris();
    b.criarUsuario('adm', perfil: 'admin', logar: true);
    await pumpApp(tester, b);

    GoRouter.of(tester.element(find.byType(NavigationBar))).go('/dispositivos/d1');
    await assentar(tester);
    expect(find.text('Dados da Peça e Dispositivo'), findsOneWidget);

    await tocar(tester, find.byTooltip('Editar'));
    expect(find.text('Editar dispositivo'), findsOneWidget);
    final nome = find.descendant(of: find.byKey(const Key('campo_nome')), matching: find.byType(TextFormField));
    await tester.enterText(nome, 'Gabarito Revisado');
    await tocar(tester, find.text('Salvar alterações'));

    expect(find.text('Editar dispositivo'), findsNothing);
    expect(find.text('Gabarito Revisado'), findsWidgets);
    expect(b.dispositivos.itens['d1']!.nome, 'Gabarito Revisado');
  });
}
