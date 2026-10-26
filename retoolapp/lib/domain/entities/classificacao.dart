/// Categorias, Famílias e Produtos compartilham a mesma forma no Firestore:
/// `{ id, nome, ativo }`. O tipo de classificação define a coleção.
enum TipoClassificacao {
  categoria('categorias', 'Categoria', 'Categorias'),
  familia('familias', 'Família', 'Famílias'),
  produto('produtos', 'Produto', 'Produtos');

  final String colecao;
  final String rotulo;
  final String rotuloPlural;
  const TipoClassificacao(this.colecao, this.rotulo, this.rotuloPlural);
}

class Classificacao {
  final String id;
  final String nome;

  /// Ausente no acervo legado = ativo.
  final bool ativo;

  const Classificacao({required this.id, required this.nome, this.ativo = true});

  factory Classificacao.fromMap(String id, Map<String, dynamic> m) => Classificacao(
        id: id,
        nome: (m['nome'] ?? '').toString(),
        ativo: m['ativo'] != false,
      );

  Map<String, dynamic> toMap() => {'id': id, 'nome': nome, 'ativo': ativo};

  Classificacao copyWith({String? nome, bool? ativo}) =>
      Classificacao(id: id, nome: nome ?? this.nome, ativo: ativo ?? this.ativo);

  @override
  bool operator ==(Object other) =>
      other is Classificacao && other.id == id && other.nome == nome && other.ativo == ativo;

  @override
  int get hashCode => Object.hash(id, nome, ativo);
}

typedef Categoria = Classificacao;
typedef Familia = Classificacao;
typedef Produto = Classificacao;

/// Ordenação alfabética pt-BR tolerante a acentos e caixa.
int compararNomes(String a, String b) => _chaveOrdenacao(a).compareTo(_chaveOrdenacao(b));

String _chaveOrdenacao(String s) => removerAcentos(s).toLowerCase();

const _acentos = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n',
  'Á': 'A', 'À': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A',
  'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E',
  'Í': 'I', 'Ì': 'I', 'Î': 'I', 'Ï': 'I',
  'Ó': 'O', 'Ò': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O',
  'Ú': 'U', 'Ù': 'U', 'Û': 'U', 'Ü': 'U',
  'Ç': 'C', 'Ñ': 'N',
};

/// Equivalente ao `normalize('NFD').replace(/[̀-ͯ]/g, '')` do desktop
/// para o alfabeto usado em pt-BR.
String removerAcentos(String s) {
  final sb = StringBuffer();
  for (final rune in s.runes) {
    final ch = String.fromCharCode(rune);
    // Marcas combinantes soltas (texto já decomposto).
    if (rune >= 0x0300 && rune <= 0x036F) continue;
    sb.write(_acentos[ch] ?? ch);
  }
  return sb.toString();
}
