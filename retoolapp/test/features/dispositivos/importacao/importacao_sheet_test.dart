import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retoolapp/domain/entities/audit_log.dart';
import 'package:retoolapp/domain/entities/classificacao.dart';
import 'package:retoolapp/features/dispositivos/importacao/importacao_sheet.dart';
import 'package:retoolapp/features/dispositivos/importacao/planilha_dispositivos.dart';

import '../../../support/fakes.dart';
import '../../../support/harness.dart';

Uint8List bytesDe(String s) => Uint8List.fromList(utf8.encode(s));

/// Mesma lógica do isolate, mas síncrona (o FakeAsync do widget test não espera isolates).
Future<PreVisualizacaoImportacao> processarDireto(EntradaImportacao e) async => prepararImportacao(e);

class _Abridor extends StatelessWidget {
  final SelecionarArquivoPlanilha selecionar;
  final ProcessarPlanilha processar;
  const _Abridor(this.selecionar, {this.processar = processarDireto});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => mostrarImportacaoPlanilha(ctx, selecionarArquivo: selecionar, processar: processar),
              child: const Text('Abrir importação'),
            ),
          ),
        ),
      );
}

const _csv = 'Código;Dispositivo;Peso (Kg);Tipo de Dispositivo;Família\n'
    'GAB-0042;Gabarito de Furação Lateral;15,2;Gabaritos;Preparo de Solo\n'
    'NOVO-1;Dispositivo Novo;2,5;Fixadores;Nova Família\n'
    'novo-1 ; DISPOSITIVO NOVO ;3;Fixadores;Nova Família\n'
    ';;;;\n'
    ';;1;;\n';

Future<FakeBackend> _backend(String perfil) async {
  final b = FakeBackend();
  b.criarUsuario('u1', perfil: perfil, logar: true);
  b.semearDadosFabris();
  return b;
}

Future<ControladoresTeste> _abrir(WidgetTester tester, FakeBackend b, SelecionarArquivoPlanilha selecionar,
    {ProcessarPlanilha processar = processarDireto}) async {
  final c = await pumpTela(tester, b, _Abridor(selecionar, processar: processar));
  await tocar(tester, find.text('Abrir importação'));
  return c;
}

void main() {
  testWidgets('admin: escolhe arquivo, vê a pré-visualização e importa no formato do desktop', (tester) async {
    final b = await _backend('admin');
    final c = await _abrir(tester, b, () async => ArquivoPlanilha('base.csv', bytesDe(_csv)));

    expect(find.text('Importação em Lote'), findsOneWidget);
    expect(find.text('Colunas aceitas'.toUpperCase()), findsOneWidget);
    await tocar(tester, find.text('Buscar Arquivo'));
    expect(find.text('Arquivo carregado: base.csv', findRichText: true), findsOneWidget);
    expect(find.text('Categoria Padrão (Opcional)'), findsOneWidget);

    await tocar(tester, find.text('Processar Planilha'));
    expect(find.text('2 combinações únicas Código + Dispositivo'), findsOneWidget);
    expect(find.bySemanticsLabel('Total: 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Novos: 1'), findsOneWidget);
    expect(find.bySemanticsLabel('Atualizados: 1'), findsOneWidget);
    expect(find.textContaining('4 linhas lidas · 1 repetições'), findsOneWidget);
    expect(find.textContaining('Aba "Sheet1": 4 linhas · Código = "Código"'), findsOneWidget);
    expect(find.textContaining('1 tipo(s) de dispositivo: Fixadores'), findsOneWidget);
    expect(find.textContaining('1 família(s): Nova Família'), findsOneWidget);
    expect(find.textContaining('1 linha(s) sem Código e sem Dispositivo foram ignoradas.'), findsOneWidget);
    expect(find.text('Gabarito de Furação Lateral'), findsOneWidget);
    expect(find.text('Categoria: Gabaritos'), findsOneWidget); // id existente exibido pelo nome

    await tocar(tester, find.text('Salvar Importação (2)'));

    final lote = b.dispositivos.ultimoLote!;
    expect(lote, hasLength(2));
    expect(lote[0], {
      'familiaId': 'fam-1',
      'produtoId': '',
      'categoriaId': 'cat-1',
      'codigo': 'GAB-0042',
      'descricao': '',
      'nome': 'Gabarito de Furação Lateral',
      'peso': '15.2',
      'palavrasChave': <String>[],
      'imagemPeca': '',
      'imagemDispositivo': '',
    });
    expect(lote[1]['codigo'], 'NOVO-1');
    expect(lote[1]['nome'], 'Dispositivo Novo');
    expect(lote[1]['peso'], '3'); // demais campos da última ocorrência
    expect(lote[1]['categoriaId'], 'Fixadores'); // nome: o repositório cria e troca pelo id
    expect(lote[1]['familiaId'], 'Nova Família');

    expect(find.text('Importação concluída!'), findsOneWidget);
    expect(find.textContaining('1 inseridos e 1 atualizados (2 de 2)'), findsOneWidget);
    expect(c.anuncios.last, contains('Importação concluída!'));
    expect(b.audit.registros.last.acao, AuditLogAcao.importacao);
    expect(b.dispositivos.itens['d1']!.peso, '15.2');

    await tocar(tester, find.text('Fechar'));
    expect(find.text('Importação em Lote'), findsNothing);
  });

  testWidgets('categoria padrão vale para linhas sem categoria', (tester) async {
    final b = await _backend('projetista');
    await _abrir(tester, b, () async => ArquivoPlanilha('x.csv', bytesDe('Código,Dispositivo\nA1,Disp A\n')));
    await tocar(tester, find.text('Buscar Arquivo'));
    await tocar(tester, find.text('-- Usar apenas da Planilha --'));
    await tocar(tester, find.text('Ferramentas de Corte').last);
    await tocar(tester, find.text('Processar Planilha'));
    expect(find.text('Categoria: Ferramentas de Corte'), findsOneWidget);
    await tocar(tester, find.text('Salvar Importação (1)'));
    expect(b.dispositivos.ultimoLote!.single['categoriaId'], 'cat-2');
  });

  testWidgets('planilha real (.xlsx) é lida e importada', (tester) async {
    final b = await _backend('admin');
    final bytes = File('test/fixtures/RETOOL import test.xlsx').readAsBytesSync();
    await _abrir(tester, b, () async => ArquivoPlanilha('RETOOL import test.xlsx', bytes));
    await tocar(tester, find.text('Buscar Arquivo'));
    await tocar(tester, find.text('Processar Planilha'));
    expect(find.text('4 combinações únicas Código + Dispositivo'), findsOneWidget);
    await tocar(tester, find.text('Salvar Importação (4)'));
    expect(b.dispositivos.ultimoLote!.map((d) => '${d['codigo']}/${d['nome']}'), [
      '50400111380/DAF00041',
      '50400111399/DAF00041',
      '51070100111/DAF00040',
      '51360261798/DAF00040',
    ]);
  });

  testWidgets('processamento padrão roda em isolate (compute)', (tester) async {
    final b = await _backend('admin');
    await _abrir(tester, b, () async => ArquivoPlanilha('x.csv', bytesDe('Código;Dispositivo\nA;1\nB;2\n')),
        processar: processarPlanilhaEmIsolate);
    await tocar(tester, find.text('Buscar Arquivo'));
    await tester.tap(find.text('Processar Planilha'));
    await tester.pump();
    expect(find.text('Processando planilha...'), findsOneWidget);
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await assentar(tester);
    expect(find.text('2 combinações únicas Código + Dispositivo'), findsOneWidget);
  });

  testWidgets('.xls antigo e formato inválido mostram mensagens amigáveis', (tester) async {
    final b = await _backend('admin');
    var arquivo = ArquivoPlanilha('antiga.xls', Uint8List.fromList([0xD0, 0xCF, 0x11, 0xE0, 0, 0, 0, 0]));
    await _abrir(tester, b, () async => arquivo);
    await tocar(tester, find.text('Buscar Arquivo'));
    await tocar(tester, find.text('Processar Planilha'));
    expect(find.textContaining('Arquivos .xls (Excel 97-2003)'), findsOneWidget);

    arquivo = ArquivoPlanilha('foto.png', Uint8List(4));
    await tocar(tester, find.text('Trocar Arquivo'));
    expect(find.text('Formato inválido. Por favor, envie um arquivo .csv ou .xlsx.'), findsOneWidget);
    expect(find.text('Processar Planilha'), findsNothing);

    arquivo = ArquivoPlanilha('vazia.csv', bytesDe('Família;Produto\nX;Y\n'));
    await tocar(tester, find.text('Buscar Arquivo'));
    await tocar(tester, find.text('Processar Planilha'));
    expect(find.textContaining('Nenhum registro válido encontrado'), findsOneWidget);
    expect(b.dispositivos.ultimoLote, isNull);
  });

  testWidgets('voltar e alterar descarta a pré-visualização', (tester) async {
    final b = await _backend('admin');
    await _abrir(tester, b, () async => ArquivoPlanilha('x.csv', bytesDe('Código;Dispositivo\nA;1\n')));
    await tocar(tester, find.text('Buscar Arquivo'));
    await tocar(tester, find.text('Processar Planilha'));
    await tocar(tester, find.text('Voltar e Alterar'));
    expect(find.text('Processar Planilha'), findsOneWidget);
    expect(b.dispositivos.ultimoLote, isNull);
  });

  testWidgets('amostra mostra 10 linhas e "E mais N registros..."', (tester) async {
    final b = await _backend('admin');
    final csv = StringBuffer('Código;Dispositivo\n');
    for (var i = 0; i < 25; i++) {
      csv.writeln('C$i;D$i');
    }
    await _abrir(tester, b, () async => ArquivoPlanilha('x.csv', bytesDe(csv.toString())));
    await tocar(tester, find.text('Buscar Arquivo'));
    await tocar(tester, find.text('Processar Planilha'));
    expect(find.text('E mais 15 registros...'), findsOneWidget);
    expect(find.text('D9'), findsOneWidget);
    expect(find.text('D10'), findsNothing);
  });

  testWidgets('engenharia vê aviso e não pode importar', (tester) async {
    final b = await _backend('engenharia');
    await _abrir(tester, b, () async => fail('não deveria abrir o seletor'));
    expect(find.text('Apenas Administradoras e Projetistas podem importar dispositivos.'), findsOneWidget);
    expect(find.text('Buscar Arquivo'), findsNothing);
  });

  testWidgets('classificação existente com caixa/espaço diferente não é recriada', (tester) async {
    final b = await _backend('admin');
    b.classificacoes.seed(TipoClassificacao.produto, const [Classificacao(id: 'p9', nome: 'Colhedora X')]);
    await _abrir(tester, b, () async => ArquivoPlanilha('x.csv', bytesDe('Código;Dispositivo;Produto\nA;1; colhedora x \n')));
    await tocar(tester, find.text('Buscar Arquivo'));
    await tocar(tester, find.text('Processar Planilha'));
    expect(find.text('Serão criadas'), findsNothing);
    await tocar(tester, find.text('Salvar Importação (1)'));
    expect(b.dispositivos.ultimoLote!.single['produtoId'], 'p9');
  });
}
