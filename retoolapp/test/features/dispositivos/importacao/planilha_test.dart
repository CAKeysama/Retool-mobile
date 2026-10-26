import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:retoolapp/domain/entities/classificacao.dart';
import 'package:retoolapp/domain/entities/dispositivo.dart';
import 'package:retoolapp/features/dispositivos/importacao/leitura/formato_excel.dart';
import 'package:retoolapp/features/dispositivos/importacao/planilha_dispositivos.dart';

import 'xlsx_teste.dart';

/// Porte de `src/tests/application/importacao/planilhaDispositivos.test.ts` do desktop
/// + casos do leitor mobile (CSV `;`/`,`, .xls, formatos numéricos, planilha real).

const ctxVazio = ContextoProcessamento();

AbaPlanilha aba(List<List<CelulaPlanilha>> linhas,
        [List<String> cabecalhos = const ['Código', 'Dispositivo'], String nome = 'DADOS']) =>
    AbaPlanilha(nome: nome, cabecalhos: cabecalhos, linhas: linhas);

ResultadoProcessamento processar(List<List<CelulaPlanilha>> linhas, [List<String>? cabecalhos]) =>
    processarPlanilhaDispositivos([cabecalhos == null ? aba(linhas) : aba(linhas, cabecalhos)], ctxVazio);

List<List<Object?>> pares(ResultadoProcessamento r) => r.dispositivos.map((d) => [d['codigo'], d['nome']]).toList();

Uint8List bytesDe(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  group('chave Código + Dispositivo', () {
    test('mesma combinação gera a mesma chave; Dispositivo diferente gera outra', () {
      expect(chaveCodigoDispositivo('ABC', 'D01'), chaveCodigoDispositivo('ABC', 'D01'));
      expect(chaveCodigoDispositivo('ABC', 'D01'), isNot(chaveCodigoDispositivo('ABC', 'D02')));
      expect(chaveCodigoDispositivo('ABC', 'D01'), isNot(chaveCodigoDispositivo('XYZ', 'D01')));
    });

    test('separador não colide entre campos', () {
      expect(chaveCodigoDispositivo('A|B', 'C'), isNot(chaveCodigoDispositivo('A', 'B|C')));
      expect(chaveCodigoDispositivo('A', ''), isNot(chaveCodigoDispositivo('', 'A')));
    });

    test('normalização: espaços, invisíveis, NBSP, Unicode e caixa são equivalentes', () {
      expect(normalizarValorChave('  abc  '), 'abc');
      expect(normalizarValorChave('A  B\tC'), 'a b c');
      expect(normalizarValorChave('A B'), 'a b');
      expect(normalizarValorChave('AB​C﻿'), 'abc');
      // NFD x NFC: a fundação (normalizarValorChave) não compõe; a importação usa chaveImportacao (com NFC).
      expect(chaveImportacao('PEÇA', 'x'), chaveImportacao('PEÇA', 'x'));
      expect(normalizarValorChave('daf00041'), normalizarValorChave('DAF00041'));
    });

    test('normalização NÃO funde valores semanticamente diferentes', () {
      expect(normalizarValorChave('0041'), isNot(normalizarValorChave('41')));
      expect(normalizarValorChave('1.10'), isNot(normalizarValorChave('1.1')));
      expect(normalizarValorChave('PEÇA'), isNot(normalizarValorChave('PECA')));
      expect(chaveImportacao('PEÇA', 'x'), isNot(chaveImportacao('PECA', 'x')));
      expect(normalizarValorChave(123), normalizarValorChave('123'));
      expect(normalizarValorChave(0), '0');
      expect(normalizarValorChave(null), '');
    });
  });

  group('processarPlanilhaDispositivos — regra de unicidade', () {
    test('duas linhas exatamente iguais → uma ocorrência', () {
      final r = processar([
        ['ABC', 'D01'],
        ['ABC', 'D01'],
      ]);
      expect(pares(r), [
        ['ABC', 'D01'],
      ]);
      expect([r.resumo.linhasLidas, r.resumo.combinacoesUnicas, r.resumo.duplicadasRemovidas], [2, 1, 1]);
    });

    test('mesmo Código com Dispositivo diferente → duas ocorrências', () {
      final r = processar([
        ['ABC', 'D01'],
        ['ABC', 'D02'],
      ]);
      expect(pares(r), [
        ['ABC', 'D01'],
        ['ABC', 'D02'],
      ]);
    });

    test('Código diferente com mesmo Dispositivo → duas ocorrências', () {
      final r = processar([
        ['ABC', 'D01'],
        ['XYZ', 'D01'],
      ]);
      expect(pares(r), [
        ['ABC', 'D01'],
        ['XYZ', 'D01'],
      ]);
    });

    test('múltiplas duplicatas misturadas', () {
      final r = processar([
        ['A', '1'], ['A', '2'], ['A', '1'], ['B', '1'], ['A', '2'], ['B', '1'], ['A', '1'], ['C', '3'], //
      ]);
      expect([r.resumo.linhasLidas, r.resumo.combinacoesUnicas, r.resumo.duplicadasRemovidas], [8, 4, 4]);
      expect(r.resumo.linhasLidas, r.resumo.combinacoesUnicas + r.resumo.duplicadasRemovidas);
    });

    test('valores com espaços e diferença de capitalização são a mesma combinação', () {
      final r = processar([
        ['ABC', 'D01'],
        ['  abc ', 'd01  '],
        ['A B C', 'D01'],
        ['A  B  C', 'D01'],
      ]);
      expect(pares(r), [
        ['ABC', 'D01'],
        ['A B C', 'D01'],
      ]);
    });

    test('valores numéricos e com zeros à esquerda são preservados', () {
      final r = processar([
        [const CelulaNumero('123', 123), 'D1'],
        ['123', 'D1'], // texto "123" = número 123
        ['00123', 'D1'], // zeros à esquerda → outra combinação
        ['0123', 'D1'],
        [const CelulaNumero('0', 0), 'D1'], // zero não pode virar vazio
      ]);
      expect(pares(r), [
        ['123', 'D1'],
        ['00123', 'D1'],
        ['0123', 'D1'],
        ['0', 'D1'],
      ]);
    });

    test('arquivo vazio e aba só com cabeçalho', () {
      expect(processarPlanilhaDispositivos([], ctxVazio).dispositivos, isEmpty);
      final r = processar([]);
      expect(r.dispositivos, isEmpty);
      expect(r.resumo.linhasLidas, 0);
    });

    test('linhas totalmente vazias não contam; linhas sem chave são contadas e avisadas', () {
      final r = processarPlanilhaDispositivos([
        aba([
          ['', '', ''],
          ['ABC', 'D01', 'x'],
          ['', '', 'só descrição'],
        ], [
          'Código',
          'Dispositivo',
          'Descrição'
        ])
      ], ctxVazio);
      expect([r.resumo.linhasLidas, r.resumo.linhasSemChave, r.resumo.combinacoesUnicas], [2, 1, 1]);
      expect(r.resumo.avisos.join(' '), contains('sem Código e sem Dispositivo'));
    });

    test('cabeçalhos com acento/caixa/pontuação diferentes são reconhecidos', () {
      expect(normalizarCabecalho(' CÓDIGO '), 'codigo');
      expect(normalizarCabecalho('Nº Dispositivo'), 'n dispositivo');
      expect(normalizarCabecalho('Familia_do_Produto'), 'familia do produto');
      final r = processar([
        ['ABC', 'D01'],
      ], [
        'codigo',
        'DISPOSITIVO'
      ]);
      expect(pares(r), [
        ['ABC', 'D01'],
      ]);
      expect(
          processar([
            ['ABC', 'D01'],
          ], [
            'Código Peça',
            'Nº Dispositivo'
          ]).dispositivos,
          hasLength(1));
    });

    test('variações do cabeçalho Peso são reconhecidas', () {
      for (final cab in ['Peso', 'Peso ', 'PESO', 'Peso (Kg)', 'Peso Dispositivo (Kg)', 'peso_kg']) {
        final r = processar([
          ['A', '1', '3,25'],
        ], [
          'Código',
          'Dispositivo',
          cab
        ]);
        expect(r.dispositivos.single['peso'], '3.25', reason: cab);
      }
    });

    test('coluna Código ausente gera aviso explícito (não reduz em silêncio ao Dispositivo)', () {
      final r = processar([
        ['D01'],
        ['D02'],
      ], [
        'Dispositivo'
      ]);
      expect(r.resumo.avisos.join(' '), contains('coluna Código não encontrada'));
      expect(r.resumo.linhasSemCodigo, 2);
    });

    test('abas sem colunas-chave são ignoradas e as demais somam', () {
      final r = processarPlanilhaDispositivos([
        aba([
          ['x', 'y'],
        ], [
          'Família',
          'P'
        ], 'FAMILIAS'),
        aba([
          ['A', '1'],
          ['A', '2'],
        ], [
          'Código',
          'Dispositivo'
        ], 'ABA1'),
        aba([
          ['A', '1'],
          ['B', '1'],
        ], [
          'Código',
          'Dispositivo'
        ], 'ABA2'),
      ], ctxVazio);
      expect(r.resumo.abas.firstWhere((a) => a.nome == 'FAMILIAS').ignorada, isTrue);
      expect([r.resumo.linhasLidas, r.resumo.combinacoesUnicas, r.resumo.duplicadasRemovidas], [4, 3, 1]);
    });

    test('duplicata mantém Código/Dispositivo da 1ª ocorrência e demais campos da última', () {
      final r = processarPlanilhaDispositivos([
        aba([
          ['ABC', 'D01', '1'],
          ['abc', 'd01', '2,5'],
        ], [
          'Código',
          'Dispositivo',
          'Peso'
        ])
      ], ctxVazio);
      expect(r.dispositivos, hasLength(1));
      expect(r.dispositivos.single, containsPair('codigo', 'ABC'));
      expect(r.dispositivos.single, containsPair('nome', 'D01'));
      expect(r.dispositivos.single, containsPair('peso', '2.5'));
    });

    test('classificações: reaproveita existentes e lista novas sem repetir (caixa/espaços)', () {
      final r = processarPlanilhaDispositivos([
        aba([
          ['A', '1', 'gabarito', 'Nova Fam'],
          ['B', '2', 'Novo Tipo', 'nova fam '],
          ['C', '3', 'novo tipo', ''],
        ], [
          'Código',
          'Dispositivo',
          'Tipo de Dispositivo',
          'Familia'
        ])
      ], const ContextoProcessamento(categorias: [Classificacao(id: 'cat1', nome: 'GABARITO')], defaultCategoriaId: 'padrao'));
      expect(r.dispositivos.map((d) => d['categoriaId']), ['cat1', 'Novo Tipo', 'Novo Tipo']);
      expect(r.novasCategorias, ['Novo Tipo']);
      expect(r.novasFamilias, ['Nova Fam']);
      expect(r.dispositivos[2]['familiaId'], '');
    });

    test('categoria padrão só vale para linhas sem categoria', () {
      final r = processarPlanilhaDispositivos([
        aba([
          ['A', '1', ''],
          ['B', '2', 'GABARITO'],
        ], [
          'Código',
          'Dispositivo',
          'Categoria'
        ])
      ], const ContextoProcessamento(categorias: [Classificacao(id: 'cat1', nome: 'GABARITO')], defaultCategoriaId: 'padrao'));
      expect(r.dispositivos.map((d) => d['categoriaId']), ['padrao', 'cat1']);
    });

    test('arquivo grande: contagem exata de combinações sem perdas', () {
      // 6.000 combinações (300 códigos × 20 dispositivos), cada uma repetida
      // de 1 a 4 vezes com variações de caixa/espaço, embaralhadas.
      final linhas = <List<CelulaPlanilha>>[];
      var esperadasDuplicadas = 0;
      for (var c = 0; c < 300; c++) {
        for (var d = 0; d < 20; d++) {
          final codigo = c.toString().padLeft(6, '0');
          final disp = 'DAF${d.toString().padLeft(5, '0')}';
          final reps = 1 + ((c * 20 + d) % 4);
          esperadasDuplicadas += reps - 1;
          for (var k = 0; k < reps; k++) {
            linhas.add([k.isOdd ? ' $codigo ' : codigo, k == 2 ? disp.toLowerCase() : disp]);
          }
        }
      }
      for (var i = linhas.length - 1; i > 0; i--) {
        final j = (i * 7919) % (i + 1);
        final t = linhas[i];
        linhas[i] = linhas[j];
        linhas[j] = t;
      }
      final r = processar(linhas);
      expect(r.resumo.linhasLidas, linhas.length);
      expect(r.resumo.combinacoesUnicas, 6000);
      expect(r.resumo.duplicadasRemovidas, esperadasDuplicadas);
    });

    test('reprocessar o mesmo arquivo dá o mesmo resultado', () {
      final linhas = <List<CelulaPlanilha>>[
        ['A', '1'],
        ['A', '2'],
        ['a', '1'],
      ];
      expect(pares(processar(linhas)), pares(processar(linhas)));
    });

    test('formato gravado é o mesmo do desktop (campos, peso texto, palavras-chave)', () {
      final r = processarPlanilhaDispositivos([
        aba([
          ['GAB-1', 'Gabarito X', '', 'Corte', 'Colheita', 'SPE 5500', 'Desc', 'furo, chapa ,,  aço'],
          ['GAB-2', 'Gabarito Y', 'abc', '', '', '', '', ''],
        ], [
          'Código',
          'Dispositivo',
          'Peso',
          'Categoria',
          'Família',
          'Produto',
          'Descrição',
          'Palavras-chave'
        ])
      ], const ContextoProcessamento(produtos: [Classificacao(id: 'prod-1', nome: 'spe 5500')]));
      expect(r.dispositivos.first, {
        'familiaId': 'Colheita',
        'produtoId': 'prod-1',
        'categoriaId': 'Corte',
        'codigo': 'GAB-1',
        'descricao': 'Desc',
        'nome': 'Gabarito X',
        'peso': '0', // sem peso → 0, como o desktop
        'palavrasChave': ['furo', 'chapa', 'aço'],
        'imagemPeca': '',
        'imagemDispositivo': '',
      });
      expect(r.dispositivos[1]['peso'], ''); // texto não numérico → vazio (NaN no desktop)
      expect(r.novosProdutos, isEmpty);
      expect(r.novasFamilias, ['Colheita']);
    });
  });

  group('lerPlanilha — leitura sem perda de representação', () {
    test('CSV UTF-8 sem BOM: cabeçalho "Código" reconhecido e zeros à esquerda preservados', () {
      const csv = 'Código;Dispositivo\n0041;D1\n041;D1\n41;D1\n1.10;D3\n1.1;D3\n';
      final abas = lerPlanilha(bytesDe(csv), 'base.csv');
      expect(abas[0].cabecalhos, ['Código', 'Dispositivo']);
      final r = processarPlanilhaDispositivos(abas, ctxVazio);
      expect(pares(r), [
        ['0041', 'D1'],
        ['041', 'D1'],
        ['41', 'D1'],
        ['1.10', 'D3'],
        ['1.1', 'D3'],
      ]);
    });

    test('CSV Windows-1252 (Excel pt-BR) também é decodificado', () {
      final bytes = Uint8List.fromList([
        ...'C'.codeUnits, 0xf3, ...'digo,Dispositivo\nABC,PE'.codeUnits, 0xc7, ...'A\n'.codeUnits, //
      ]);
      expect(decodificarTexto(bytes), 'Código,Dispositivo\nABC,PEÇA\n');
      final r = processarPlanilhaDispositivos(lerPlanilha(bytes, 'base.CSV'), ctxVazio);
      expect(pares(r), [
        ['ABC', 'PEÇA'],
      ]);
    });

    test('CSV com vírgula, BOM, CRLF, aspas e vírgula decimal no peso', () {
      const csv = '﻿Código,Dispositivo,Peso,Descrição\r\n"0041","Gabarito, lateral","2,5","diz ""oi"""\r\n'
          'X1,D2,,"linha\nquebrada"\r\n';
      final r = processarPlanilhaDispositivos(lerPlanilha(bytesDe(csv), 'base.csv'), ctxVazio);
      expect(pares(r), [
        ['0041', 'Gabarito, lateral'],
        ['X1', 'D2'],
      ]);
      expect(r.dispositivos[0]['peso'], '2.5');
      expect(r.dispositivos[0]['descricao'], 'diz "oi"');
      expect(r.dispositivos[1]['descricao'], 'linha quebrada');
    });

    test('CSV com ponto e vírgula e peso com vírgula decimal', () {
      const csv = 'Codigo;Dispositivo;Peso (Kg);Tipo de Dispositivo\n0041;Gabarito, lateral;2,5;Gabarito\n';
      final r = processarPlanilhaDispositivos(lerPlanilha(bytesDe(csv), 'base.csv'), ctxVazio);
      expect(pares(r), [
        ['0041', 'Gabarito, lateral'],
      ]);
      expect(r.dispositivos.single['peso'], '2.5');
      expect(r.novasCategorias, ['Gabarito']);
    });

    test('separador é adivinhado como no SheetJS (mais frequente; empate favorece vírgula) e aceita "sep="', () {
      expect(adivinharSeparador('a;b;c\n1;2;3'), ';');
      expect(adivinharSeparador('a,b;c'), ',');
      expect(adivinharSeparador('a\tb\tc'), '\t');
      expect(adivinharSeparador('"a;b",c'), ',');
      final abas = lerPlanilha(bytesDe('sep=|\nCódigo|Dispositivo\nA|1\n'), 'x.csv');
      expect(abas.single.cabecalhos, ['Código', 'Dispositivo']);
    });

    test('xlsx: número formatado usa o texto exibido; número Geral usa o valor completo', () {
      final bytes = xlsxDe({
        'A1': txt('Código'), 'B1': txt('Dispositivo'), 'C1': txt('Peso'),
        'A2': num_(41, '00000'), 'B2': txt('X'),
        'A3': num_(41, '0000'), 'B3': txt('X'),
        'A4': num_(50400111380123), 'B4': txt('Y'), 'C4': num_(4.988, '0.00'),
        'A5': num_(50400111380124), 'B5': txt('Y'),
        'A6': txt('00041'), 'B6': txt('X'), // texto igual ao exibido em A2
      });
      final r = processarPlanilhaDispositivos(lerPlanilha(bytes, 'base.xlsx'), ctxVazio);
      expect(pares(r), [
        ['00041', 'X'],
        ['0041', 'X'],
        ['50400111380123', 'Y'],
        ['50400111380124', 'Y'],
      ]);
      expect(r.dispositivos[2]['peso'], '4.988'); // peso bruto, não o arredondado "4.99"
      expect(r.resumo.duplicadasRemovidas, 1);
    });

    test('xlsx com dimensão (<dimension>) desatualizada não perde as últimas linhas', () {
      final bytes = xlsxDe({
        'A1': txt('Código'), 'B1': txt('Dispositivo'),
        'A2': txt('A'), 'B2': txt('1'),
        'A3': txt('B'), 'B3': txt('2'),
        'A4': txt('C'), 'B4': txt('3'),
      }, dimensao: 'A1:B2');
      final r = processarPlanilhaDispositivos(lerPlanilha(bytes, 'x.xlsx'), ctxVazio);
      expect(r.resumo.combinacoesUnicas, 3);
    });

    test('xlsx sem compressão, com texto inline, várias abas e intervalo deslocado', () {
      final bytes = xlsxDe(
        {'C3': txt('Código'), 'D3': txt('Dispositivo'), 'C4': txt('A & B <1>'), 'D4': num_(7)},
        comprimir: false,
        compartilhadas: false,
        outrasAbas: {
          'FAMILIAS': {'A1': txt('Família'), 'A2': txt('Colheita')},
        },
      );
      final abas = lerPlanilha(bytes, 'x.xlsx');
      expect(abas.map((a) => a.nome), ['DADOS', 'FAMILIAS']);
      expect(abas.first.cabecalhos, ['Código', 'Dispositivo']);
      final r = processarPlanilhaDispositivos(abas, ctxVazio);
      expect(pares(r), [
        ['A & B <1>', '7'],
      ]);
      expect(r.resumo.abas.last.ignorada, isTrue);
    });

    test('.xls binário (Excel 97-2003) gera mensagem amigável pedindo .xlsx/.csv', () {
      final cfb = Uint8List.fromList([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1, 0, 0, 0, 0]);
      expect(
        () => lerPlanilha(cfb, 'antiga.xls'),
        throwsA(isA<ErroLeituraPlanilha>().having((e) => e.mensagem, 'mensagem', contains('.xlsx ou .csv'))),
      );
      // .xls que na verdade é .xlsx (renomeado) é lido normalmente.
      final xlsx = xlsxDe({'A1': txt('Código'), 'B1': txt('Dispositivo'), 'A2': txt('A'), 'B2': txt('1')});
      expect(processarPlanilhaDispositivos(lerPlanilha(xlsx, 'renomeado.xls'), ctxVazio).dispositivos, hasLength(1));
    });

    test('arquivo corrompido gera erro amigável', () {
      expect(() => lerPlanilha(Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 1, 2, 3]), 'x.xlsx'),
          throwsA(isA<ErroLeituraPlanilha>()));
      expect(() => lerPlanilha(bytesDe('qualquer coisa'), 'x.pdf'), throwsA(isA<ErroLeituraPlanilha>()));
    });

    test('arquivo vazio', () {
      expect(lerPlanilha(Uint8List(0), 'x.csv')[0].linhas, isEmpty);
    });

    test('textoDaCelula cobre vazios, booleanos, erros e datas', () {
      expect(textoDaCelula(null), '');
      expect(textoDaCelula(const CelulaXlsx('z')), '');
      expect(textoDaCelula(const CelulaXlsx('b', v: true)), 'true');
      expect(textoDaCelula(const CelulaXlsx('e', v: 7, w: '#DIV/0!')), '#DIV/0!');
      expect(textoDaCelula(CelulaXlsx('d', v: DateTime.utc(2026, 1, 2))), '2026-01-02T00:00:00.000Z');
      expect(textoDaCelula(const CelulaXlsx('n', v: 7, z: '@')), '7');
    });

    test('planilha de exemplo do repositório (docs/RETOOL import test.xlsx)', () {
      final bytes = File('test/fixtures/RETOOL import test.xlsx').readAsBytesSync();
      final r = processarPlanilhaDispositivos(lerPlanilha(bytes, 'RETOOL import test.xlsx'), ctxVazio);
      expect(r.resumo.abas.where((a) => !a.ignorada).map((a) => a.nome), ['DADOS']);
      expect(pares(r), [
        ['50400111380', 'DAF00041'],
        ['50400111399', 'DAF00041'],
        ['51070100111', 'DAF00040'],
        ['51360261798', 'DAF00040'],
      ]);
    });
  });

  group('formatos numéricos do Excel', () {
    test('zeros à esquerda, casas decimais, milhar, porcentagem e literais', () {
      expect(formatarNumeroExcel(41, '00000'), '00041');
      expect(formatarNumeroExcel(4.988, '0.00'), '4.99');
      expect(formatarNumeroExcel(1234567.891, '#,##0.00'), '1,234,567.89');
      expect(formatarNumeroExcel(0.256, '0.0%'), '25.6%');
      expect(formatarNumeroExcel(12345678, '00000-000'), '12345-678');
      expect(formatarNumeroExcel(5, '0 "kg"'), '5 kg');
      expect(formatarNumeroExcel(1.5, '0.0#'), '1.5');
      expect(formatarNumeroExcel(-3, '0.0'), '-3.0');
      expect(formatarNumeroExcel(-3, '0.0;(0.0)'), '(3.0)');
      expect(formatarNumeroExcel(12345, '0.00E+00'), '1.23E+04');
      expect(formatarNumeroExcel(7, 'General'), '7');
    });

    test('datas no sistema 1900 do Excel', () {
      expect(formatarNumeroExcel(46024, 'dd/mm/yyyy'), '02/01/2026');
      expect(formatarNumeroExcel(46024, 'm/d/yy'), '1/2/26');
      expect(formatarNumeroExcel(46024.5, 'hh:mm'), '12:00');
    });

    test('String(n) do JavaScript', () {
      expect(numeroParaTextoJs(50400111380123.0), '50400111380123');
      expect(numeroParaTextoJs(4.988), '4.988');
      expect(numeroParaTextoJs(-0.0), '0');
      expect(parseFloatJs('2.5 kg'), 2.5);
      expect(parseFloatJs('abc').isNaN, isTrue);
    });
  });

  group('pré-visualização', () {
    test('conta novos × atualizados contra o acervo e devolve os mapas prontos', () {
      const csv = 'Código;Dispositivo\nGAB-0042;Gabarito de Furação Lateral\nNOVO-1;Outro\n gab-0042 ;GABARITO DE FURAÇÃO LATERAL\n';
      final p = prepararImportacao(EntradaImportacao(
        bytes: bytesDe(csv),
        nomeArquivo: 'x.csv',
        contexto: ctxVazio,
        existentes: const [('GAB-0042', 'Gabarito de Furação Lateral'), ('VAL-1', 'Válvula')],
      ));
      expect(p.total, 2);
      expect(p.atualizados, 1);
      expect(p.novos, 1);
      expect(p.resultado.resumo.duplicadasRemovidas, 1);
    });
  });
}
