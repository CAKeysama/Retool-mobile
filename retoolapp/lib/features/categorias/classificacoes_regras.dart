import '../../core/utils/busca.dart';
import '../../domain/entities/classificacao.dart';
import '../../domain/entities/dispositivo.dart';

/// Filtro de situação dos painéis de classificação.
enum FiltroSituacao {
  todos('Todos'),
  ativos('Ativos'),
  inativos('Inativos');

  final String rotulo;
  const FiltroSituacao(this.rotulo);
}

/// Textos de cada painel (copiados de `Categorias.tsx`) e concordância de gênero.
extension TextosClassificacao on TipoClassificacao {
  bool get feminino => this != TipoClassificacao.produto;

  /// "categoria", "família", "produto".
  String get rotuloMin => rotulo.toLowerCase();

  /// "categorias", "famílias", "produtos".
  String get pluralMin => rotuloPlural.toLowerCase();

  String get tituloPainel => switch (this) {
    TipoClassificacao.categoria => 'Categorias',
    TipoClassificacao.familia => 'Famílias de Produto',
    TipoClassificacao.produto => 'Produtos',
  };

  String get infoAria => switch (this) {
    TipoClassificacao.categoria => 'O que são categorias?',
    TipoClassificacao.familia => 'O que são famílias de produto?',
    TipoClassificacao.produto => 'O que são produtos?',
  };

  /// Trecho em negrito da explicação conceitual.
  String get infoDestaque => switch (this) {
    TipoClassificacao.categoria => 'Grupos macro',
    TipoClassificacao.familia => 'Grupo de manufatura',
    TipoClassificacao.produto => 'Nome comercial ou modelo',
  };

  String get infoResto => switch (this) {
    TipoClassificacao.categoria => ' para classificar os dispositivos de forma geral.',
    TipoClassificacao.familia => ' da peça.',
    TipoClassificacao.produto => ' do produto associado.',
  };

  String get infoExemplos => switch (this) {
    TipoClassificacao.categoria => 'Exemplos: Ferramentas de Corte, EPIs, Gabaritos.',
    TipoClassificacao.familia => 'Exemplos: Preparo de Solo, Colheita, Transporte.',
    TipoClassificacao.produto => 'Exemplos: AVOLA 2500, Semeadeira XP.',
  };

  String get tituloNovo => '${feminino ? 'Nova' : 'Novo'} $rotulo';
  String get tituloEditar => 'Editar $rotulo';
  String get rotuloCampoNome => 'Nome d${feminino ? 'a' : 'o'} $rotulo';

  /// "a categoria", "o produto".
  String get comArtigo => '${feminino ? 'a' : 'o'} $rotuloMin';

  /// Particípio concordando com gênero e número ("desativadas", "excluído").
  String participio(String raiz, int n) => '$raiz${feminino ? 'a' : 'o'}${n == 1 ? '' : 's'}';

  /// "3 categorias", "1 produto".
  String contagem(int n) => '$n ${n == 1 ? rotuloMin : pluralMin}';
}

/// Chave de comparação de nomes: sem acentos, sem diferença de caixa e com
/// espaços colapsados ("  Ferramentas  de CÓRTE " == "ferramentas de corte").
String chaveNomeClassificacao(String nome) => removerAcentos(nome).toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

/// Nome limpo para gravação (sem espaços nas pontas nem repetidos).
String limparNomeClassificacao(String nome) => nome.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Classificação já existente com o mesmo nome (ignorando caixa, espaços e acentos).
/// [ignorarId] exclui o próprio registro durante a edição.
Classificacao? classificacaoComMesmoNome(Iterable<Classificacao> lista, String nome, {String? ignorarId}) {
  final chave = chaveNomeClassificacao(nome);
  if (chave.isEmpty) return null;
  for (final c in lista) {
    if (c.id != ignorarId && chaveNomeClassificacao(c.nome) == chave) return c;
  }
  return null;
}

/// Mensagem de validação do nome (null = válido).
String? validarNomeClassificacao(
  TipoClassificacao tipo,
  Iterable<Classificacao> lista,
  String nome, {
  String? ignorarId,
}) {
  if (limparNomeClassificacao(nome).isEmpty) return 'Informe o nome d${tipo.comArtigo}.';
  final existente = classificacaoComMesmoNome(lista, nome, ignorarId: ignorarId);
  if (existente == null) return null;
  final artigo = tipo.feminino ? 'uma' : 'um';
  return existente.ativo
      ? 'Já existe $artigo ${tipo.rotuloMin} com este nome: "${existente.nome}".'
      : 'Já existe $artigo ${tipo.rotuloMin} inativ${tipo.feminino ? 'a' : 'o'} com este nome: "${existente.nome}". Reative-${tipo.feminino ? 'a' : 'o'} na lista.';
}

/// Quantos dispositivos usam cada classificação (id → contagem), calculado
/// uma única vez por snapshot de dispositivos.
Map<String, int> contarDispositivosPorClassificacao(Iterable<Dispositivo> dispositivos, TipoClassificacao tipo) {
  final mapa = <String, int>{};
  for (final d in dispositivos) {
    final id = switch (tipo) {
      TipoClassificacao.categoria => d.categoriaId,
      TipoClassificacao.familia => d.familiaId,
      TipoClassificacao.produto => d.produtoId,
    };
    if (id == null || id.isEmpty) continue;
    mapa[id] = (mapa[id] ?? 0) + 1;
  }
  return mapa;
}

/// Busca (tolerante a acentos) + filtro de situação, preservando a ordem.
List<Classificacao> filtrarClassificacoes(List<Classificacao> lista, String busca, FiltroSituacao filtro) {
  final q = normalizarBusca(busca).trim();
  if (q.isEmpty && filtro == FiltroSituacao.todos) return lista;
  return [
    for (final c in lista)
      if ((filtro == FiltroSituacao.todos || (filtro == FiltroSituacao.ativos) == c.ativo) &&
          (q.isEmpty || normalizarBusca(c.nome).contains(q)))
        c,
  ];
}
