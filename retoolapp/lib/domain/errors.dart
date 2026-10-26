/// Operação recusada por falta de permissão (validada também nas regras do Firestore).
class ErroPermissao implements Exception {
  final String mensagem;
  const ErroPermissao([this.mensagem = 'Acesso negado: operação exclusiva da Administração.']);
  @override
  String toString() => mensagem;
}

/// Regra de negócio violada (dados inválidos, estado inconsistente).
class ErroValidacao implements Exception {
  final String mensagem;
  const ErroValidacao(this.mensagem);
  @override
  String toString() => mensagem;
}

/// Erro de autenticação/infra já traduzido para o usuário.
class ErroAmigavel implements Exception {
  final String mensagem;
  final String? codigo;
  const ErroAmigavel(this.mensagem, {this.codigo});
  @override
  String toString() => mensagem;
}

/// Mensagem legível de qualquer erro lançado pelas camadas do app.
String mensagemDoErro(Object erro) {
  if (erro is ErroPermissao) return erro.mensagem;
  if (erro is ErroValidacao) return erro.mensagem;
  if (erro is ErroAmigavel) return erro.mensagem;
  final texto = erro.toString();
  return texto.startsWith('Exception: ') ? texto.substring(11) : texto;
}
