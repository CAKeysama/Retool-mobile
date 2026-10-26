/// Ações auditáveis (tokens de máquina estáveis, iguais aos do desktop).
enum AuditLogAcao {
  criacao('criacao', 'Criação'),
  edicao('edicao', 'Edição'),
  exclusao('exclusao', 'Exclusão'),
  transicao('transicao', 'Transição de fluxo'),
  importacao('importacao', 'Importação'),
  aprovacao('aprovacao', 'Aprovação'),
  rejeicao('rejeicao', 'Rejeição'),
  alteracaoPerfil('alteracao_perfil', 'Alteração de cargo'),
  bloqueioUsuario('bloqueio_usuario', 'Bloqueio de usuário'),
  desbloqueioUsuario('desbloqueio_usuario', 'Desbloqueio de usuário'),
  login('login', 'Login'),
  logout('logout', 'Logout'),
  cadastro('cadastro', 'Cadastro'),
  aprovacaoUsuario('aprovacao_usuario', 'Aprovação de usuário'),
  rejeicaoUsuario('rejeicao_usuario', 'Rejeição de usuário'),
  criacaoUsuario('criacao_usuario', 'Criação de usuário'),
  trocaSenha('troca_senha', 'Troca de senha'),
  redefinicaoSenha('redefinicao_senha', 'Redefinição de senha'),
  solicitacaoCargo('solicitacao_cargo', 'Solicitação de cargo'),
  aprovacaoCargo('aprovacao_cargo', 'Aprovação de cargo'),
  rejeicaoCargo('rejeicao_cargo', 'Rejeição de cargo');

  final String valor;
  final String rotulo;
  const AuditLogAcao(this.valor, this.rotulo);

  static AuditLogAcao fromValor(String? v) =>
      AuditLogAcao.values.firstWhere((a) => a.valor == v, orElse: () => AuditLogAcao.edicao);
}

/// Agrupamento das ações para filtros da tela de histórico.
enum AuditLogCategoria {
  autenticacao('autenticacao', 'Autenticação'),
  usuarios('usuarios', 'Usuários e cargos'),
  dados('dados', 'Alteração de dados'),
  fluxo('fluxo', 'Fluxo de reutilização');

  final String valor;
  final String rotulo;
  const AuditLogCategoria(this.valor, this.rotulo);

  static AuditLogCategoria? fromValor(String? v) {
    for (final c in AuditLogCategoria.values) {
      if (c.valor == v) return c;
    }
    return null;
  }
}

enum AuditLogResultado {
  sucesso,
  falha,
  negado;

  static AuditLogResultado fromValor(String? v) =>
      AuditLogResultado.values.firstWhere((r) => r.name == v, orElse: () => AuditLogResultado.sucesso);
}

enum AuditLogTipoEntidade {
  dispositivo('dispositivo', 'Dispositivo'),
  categoria('categoria', 'Categoria'),
  tipo('tipo', 'Tipo'),
  familia('familia', 'Família'),
  produto('produto', 'Produto'),
  reutilizacao('reutilizacao', 'Reutilização'),
  usuario('usuario', 'Usuário'),
  solicitacaoCargo('solicitacao_cargo', 'Solicitação de cargo'),
  sessao('sessao', 'Sessão');

  final String valor;
  final String rotulo;
  const AuditLogTipoEntidade(this.valor, this.rotulo);

  static AuditLogTipoEntidade fromValor(String? v) =>
      AuditLogTipoEntidade.values.firstWhere((t) => t.valor == v, orElse: () => AuditLogTipoEntidade.dispositivo);
}

const Map<AuditLogCategoria, List<AuditLogAcao>> acoesPorCategoria = {
  AuditLogCategoria.autenticacao: [AuditLogAcao.login, AuditLogAcao.logout, AuditLogAcao.cadastro, AuditLogAcao.trocaSenha],
  AuditLogCategoria.usuarios: [
    AuditLogAcao.aprovacaoUsuario,
    AuditLogAcao.rejeicaoUsuario,
    AuditLogAcao.criacaoUsuario,
    AuditLogAcao.redefinicaoSenha,
    AuditLogAcao.alteracaoPerfil,
    AuditLogAcao.bloqueioUsuario,
    AuditLogAcao.desbloqueioUsuario,
    AuditLogAcao.solicitacaoCargo,
    AuditLogAcao.aprovacaoCargo,
    AuditLogAcao.rejeicaoCargo,
  ],
  AuditLogCategoria.dados: [AuditLogAcao.criacao, AuditLogAcao.edicao, AuditLogAcao.exclusao, AuditLogAcao.importacao],
  AuditLogCategoria.fluxo: [AuditLogAcao.transicao, AuditLogAcao.aprovacao, AuditLogAcao.rejeicao],
};

AuditLogCategoria categoriaDaAcao(AuditLogAcao acao) {
  for (final e in acoesPorCategoria.entries) {
    if (e.value.contains(acao)) return e.key;
  }
  return AuditLogCategoria.dados;
}

class AuditLog {
  final String id;

  /// ISO — campo usado na ordenação.
  final String dataHora;
  final String usuarioUid;
  final String usuarioNome;
  final String usuarioEmail;
  final String usuarioPerfil;
  final AuditLogAcao acao;
  final AuditLogCategoria categoria;
  final AuditLogResultado resultado;
  final String? acaoDescricao;
  final AuditLogTipoEntidade tipoEntidade;
  final String entidadeId;
  final String? entidadeNome;
  final String? detalhes;
  final Map<String, dynamic>? conteudo;
  final Map<String, dynamic>? dadosAnteriores;

  const AuditLog({
    required this.id,
    required this.dataHora,
    required this.usuarioUid,
    required this.usuarioNome,
    required this.usuarioEmail,
    required this.usuarioPerfil,
    required this.acao,
    required this.categoria,
    this.resultado = AuditLogResultado.sucesso,
    this.acaoDescricao,
    required this.tipoEntidade,
    required this.entidadeId,
    this.entidadeNome,
    this.detalhes,
    this.conteudo,
    this.dadosAnteriores,
  });

  factory AuditLog.fromMap(String id, Map<String, dynamic> m, {required String dataHora}) {
    final acao = AuditLogAcao.fromValor(m['acao'] as String?);
    return AuditLog(
      id: id,
      dataHora: dataHora,
      usuarioUid: (m['usuarioUid'] ?? '').toString(),
      usuarioNome: (m['usuarioNome'] ?? '').toString(),
      usuarioEmail: (m['usuarioEmail'] ?? '').toString(),
      usuarioPerfil: (m['usuarioPerfil'] ?? '').toString(),
      acao: acao,
      categoria: AuditLogCategoria.fromValor(m['categoria'] as String?) ?? categoriaDaAcao(acao),
      resultado: AuditLogResultado.fromValor(m['resultado'] as String?),
      acaoDescricao: m['acaoDescricao'] as String?,
      tipoEntidade: AuditLogTipoEntidade.fromValor(m['tipoEntidade'] as String?),
      entidadeId: (m['entidadeId'] ?? '').toString(),
      entidadeNome: m['entidadeNome'] as String?,
      detalhes: m['detalhes'] as String?,
      conteudo: m['conteudo'] is Map ? Map<String, dynamic>.from(m['conteudo'] as Map) : null,
      dadosAnteriores: m['dadosAnteriores'] is Map ? Map<String, dynamic>.from(m['dadosAnteriores'] as Map) : null,
    );
  }
}

/// Dados de entrada para registrar um log (id e carimbos são gerados pelo repositório).
class AuditLogInput {
  final String usuarioUid;
  final String usuarioNome;
  final String usuarioEmail;
  final String usuarioPerfil;
  final AuditLogAcao acao;
  final AuditLogResultado resultado;
  final String? acaoDescricao;
  final AuditLogTipoEntidade tipoEntidade;
  final String entidadeId;
  final String? entidadeNome;
  final String? detalhes;
  final Map<String, dynamic>? conteudo;
  final Map<String, dynamic>? dadosAnteriores;

  const AuditLogInput({
    required this.usuarioUid,
    required this.usuarioNome,
    required this.usuarioEmail,
    required this.usuarioPerfil,
    required this.acao,
    this.resultado = AuditLogResultado.sucesso,
    this.acaoDescricao,
    required this.tipoEntidade,
    required this.entidadeId,
    this.entidadeNome,
    this.detalhes,
    this.conteudo,
    this.dadosAnteriores,
  });

  /// Mapa persistido (sem segredos e sem nulos), exceto id/carimbos.
  Map<String, dynamic> toMap() => sanitizarDadosAuditoria(Map<String, dynamic>.fromEntries({
        'usuarioUid': usuarioUid,
        'usuarioNome': usuarioNome,
        'usuarioEmail': usuarioEmail,
        'usuarioPerfil': usuarioPerfil,
        'acao': acao.valor,
        'categoria': categoriaDaAcao(acao).valor,
        'resultado': resultado.name,
        'acaoDescricao': acaoDescricao,
        'tipoEntidade': tipoEntidade.valor,
        'entidadeId': entidadeId,
        'entidadeNome': entidadeNome,
        'detalhes': detalhes,
        'conteudo': conteudo,
        'dadosAnteriores': dadosAnteriores,
      }.entries.where((e) => e.value != null))) as Map<String, dynamic>;
}

const _palavrasSensiveis = ['senha', 'password', 'passwd', 'pwd', 'token', 'secret', 'segredo', 'hash', 'credential', 'credencial'];
const _termosSensiveis = ['password', 'passwd', 'apikey', 'privatekey', 'credential', 'credencial', 'segredo'];

List<String> _palavrasDoCampo(String campo) => campo
    .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}')
    .split(RegExp(r'[\s_\-.]+'))
    .map((p) => p.toLowerCase())
    .where((p) => p.isNotEmpty)
    .toList();

bool isCampoSensivel(String campo) {
  final palavras = _palavrasDoCampo(campo);
  final junto = palavras.join();
  return palavras.any(_palavrasSensiveis.contains) || _termosSensiveis.any(junto.contains);
}

/// Remove recursivamente campos com segredos (flags booleanas são preservadas).
Object? sanitizarDadosAuditoria(Object? valor) {
  if (valor is List) return valor.map(sanitizarDadosAuditoria).toList();
  if (valor is Map) {
    final limpo = <String, dynamic>{};
    valor.forEach((k, v) {
      if (v == null) return;
      final campo = k.toString();
      if (isCampoSensivel(campo) && v is! bool) return;
      limpo[campo] = sanitizarDadosAuditoria(v);
    });
    return limpo;
  }
  return valor;
}
