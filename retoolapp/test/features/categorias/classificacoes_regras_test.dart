import 'package:flutter_test/flutter_test.dart';
import 'package:retoolapp/domain/entities/classificacao.dart';
import 'package:retoolapp/domain/entities/dispositivo.dart';
import 'package:retoolapp/features/categorias/classificacoes_regras.dart';

void main() {
  const lista = [
    Classificacao(id: 'c1', nome: 'Ferramentas de Corte'),
    Classificacao(id: 'c2', nome: 'Gabaritos'),
    Classificacao(id: 'c3', nome: 'Calibração', ativo: false),
  ];

  group('duplicidade de nome', () {
    test('ignora caixa, espaços e acentos', () {
      expect(classificacaoComMesmoNome(lista, '  ferramentas   DE corte ')?.id, 'c1');
      expect(classificacaoComMesmoNome(lista, 'GABARÍTOS')?.id, 'c2');
      expect(classificacaoComMesmoNome(lista, 'calibracao')?.id, 'c3');
      expect(classificacaoComMesmoNome(lista, 'EPIs'), isNull);
    });

    test('na edição ignora o próprio registro', () {
      expect(classificacaoComMesmoNome(lista, 'gabaritos', ignorarId: 'c2'), isNull);
      expect(classificacaoComMesmoNome(lista, 'gabaritos', ignorarId: 'c1')?.id, 'c2');
    });

    test('mensagens de validação concordam com o tipo', () {
      expect(validarNomeClassificacao(TipoClassificacao.categoria, lista, '   '), 'Informe o nome da categoria.');
      expect(validarNomeClassificacao(TipoClassificacao.produto, lista, ''), 'Informe o nome do produto.');
      expect(
        validarNomeClassificacao(TipoClassificacao.categoria, lista, 'gabaritos'),
        'Já existe uma categoria com este nome: "Gabaritos".',
      );
      expect(validarNomeClassificacao(TipoClassificacao.categoria, lista, 'calibracao'), contains('inativa'));
      expect(validarNomeClassificacao(TipoClassificacao.categoria, lista, 'Nova'), isNull);
    });

    test('nome gravado sai sem espaços sobrando', () {
      expect(limparNomeClassificacao('  Preparo   de  Solo '), 'Preparo de Solo');
    });
  });

  test('conta dispositivos por classificação em uma passada', () {
    const disps = [
      Dispositivo(id: 'd1', nome: 'A', categoriaId: 'c1', familiaId: 'f1', produtoId: 'p1'),
      Dispositivo(id: 'd2', nome: 'B', categoriaId: 'c1', produtoId: 'p2'),
      Dispositivo(id: 'd3', nome: 'C', categoriaId: '', ativo: false),
    ];
    expect(contarDispositivosPorClassificacao(disps, TipoClassificacao.categoria), {'c1': 2});
    expect(contarDispositivosPorClassificacao(disps, TipoClassificacao.familia), {'f1': 1});
    expect(contarDispositivosPorClassificacao(disps, TipoClassificacao.produto), {'p1': 1, 'p2': 1});
  });

  group('filtro', () {
    test('sem busca nem filtro devolve a mesma lista (sem cópia)', () {
      expect(identical(filtrarClassificacoes(lista, '  ', FiltroSituacao.todos), lista), isTrue);
    });

    test('busca tolerante a acentos e filtro de situação', () {
      expect(filtrarClassificacoes(lista, 'calibracão', FiltroSituacao.todos).map((c) => c.id), ['c3']);
      expect(filtrarClassificacoes(lista, '', FiltroSituacao.inativos).map((c) => c.id), ['c3']);
      expect(filtrarClassificacoes(lista, '', FiltroSituacao.ativos).map((c) => c.id), ['c1', 'c2']);
      expect(filtrarClassificacoes(lista, 'gab', FiltroSituacao.inativos), isEmpty);
    });
  });

  test('textos e concordância', () {
    expect(TipoClassificacao.familia.tituloPainel, 'Famílias de Produto');
    expect(TipoClassificacao.produto.tituloNovo, 'Novo Produto');
    expect(TipoClassificacao.familia.rotuloCampoNome, 'Nome da Família');
    expect(TipoClassificacao.produto.participio('excluíd', 3), 'excluídos');
    expect(TipoClassificacao.categoria.participio('desativad', 1), 'desativada');
    expect(TipoClassificacao.categoria.contagem(2), '2 categorias');
  });
}
