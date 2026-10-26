import 'dart:ui';

/// Cargos operacionais — os únicos que a Administração pode atribuir.
enum UserRole { admin, projetista, engenharia, gerencia }

/// Perfil efetivo: um cargo operacional ou `convidado`
/// (autocadastro aguardando a decisão da Administração, sem permissões).
/// Persistido como string (`'admin'`, `'projetista'`, ..., `'convidado'`).
typedef PerfilUsuario = String;

const String perfilConvidado = 'convidado';

/// Situação do cadastro em relação à aprovação da Administração.
enum StatusAprovacao { pendente, aprovado, rejeitado }

UserRole? userRoleFromString(String? valor) {
  for (final r in UserRole.values) {
    if (r.name == valor) return r;
  }
  return null;
}

StatusAprovacao? _statusAprovacaoFromString(String? valor) {
  for (final s in StatusAprovacao.values) {
    if (s.name == valor) return s;
  }
  return null;
}

class UserProfile {
  final String uid;
  final String email;
  final String nome;
  final PerfilUsuario perfil;
  final bool ativo;
  final String? criadoEm;
  final String? atualizadoEm;

  /// Ausente em contas legadas (tratadas por [situacaoDoUsuario]).
  final StatusAprovacao? statusAprovacao;

  /// Conta criada pela Administração com senha temporária: troca obrigatória no 1º acesso.
  final bool trocaSenhaObrigatoria;
  final String? senhaAlteradaEm;
  final String? senhaRedefinidaEm;
  final String? senhaRedefinidaPorUid;
  final String? criadoPorUid;
  final String? aprovadoPorUid;
  final String? aprovadoEm;
  final String? rejeitadoPorUid;
  final String? rejeitadoEm;
  final String? motivoRejeicao;

  /// Legado: tier escolhido no antigo formulário de cadastro.
  final String? perfilSolicitado;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.nome,
    required this.perfil,
    required this.ativo,
    this.criadoEm,
    this.atualizadoEm,
    this.statusAprovacao,
    this.trocaSenhaObrigatoria = false,
    this.senhaAlteradaEm,
    this.senhaRedefinidaEm,
    this.senhaRedefinidaPorUid,
    this.criadoPorUid,
    this.aprovadoPorUid,
    this.aprovadoEm,
    this.rejeitadoPorUid,
    this.rejeitadoEm,
    this.motivoRejeicao,
    this.perfilSolicitado,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> m) => UserProfile(
        uid: uid,
        email: (m['email'] ?? '') as String,
        nome: (m['nome'] ?? '') as String,
        perfil: (m['perfil'] ?? perfilConvidado) as String,
        ativo: m['ativo'] == true,
        criadoEm: m['criadoEm'] as String?,
        atualizadoEm: m['atualizadoEm'] as String?,
        statusAprovacao: _statusAprovacaoFromString(m['statusAprovacao'] as String?),
        trocaSenhaObrigatoria: m['trocaSenhaObrigatoria'] == true,
        senhaAlteradaEm: m['senhaAlteradaEm'] as String?,
        senhaRedefinidaEm: m['senhaRedefinidaEm'] as String?,
        senhaRedefinidaPorUid: m['senhaRedefinidaPorUid'] as String?,
        criadoPorUid: m['criadoPorUid'] as String?,
        aprovadoPorUid: m['aprovadoPorUid'] as String?,
        aprovadoEm: m['aprovadoEm'] as String?,
        rejeitadoPorUid: m['rejeitadoPorUid'] as String?,
        rejeitadoEm: m['rejeitadoEm'] as String?,
        motivoRejeicao: m['motivoRejeicao'] as String?,
        perfilSolicitado: m['perfilSolicitado'] as String?,
      );

  /// Mapa para o Firestore, sem chaves nulas (o desktop grava sem `undefined`).
  Map<String, dynamic> toMap() => _semNulos({
        'uid': uid,
        'email': email,
        'nome': nome,
        'perfil': perfil,
        'ativo': ativo,
        'criadoEm': criadoEm,
        'atualizadoEm': atualizadoEm,
        'statusAprovacao': statusAprovacao?.name,
        'trocaSenhaObrigatoria': trocaSenhaObrigatoria ? true : null,
        'senhaAlteradaEm': senhaAlteradaEm,
        'senhaRedefinidaEm': senhaRedefinidaEm,
        'senhaRedefinidaPorUid': senhaRedefinidaPorUid,
        'criadoPorUid': criadoPorUid,
        'aprovadoPorUid': aprovadoPorUid,
        'aprovadoEm': aprovadoEm,
        'rejeitadoPorUid': rejeitadoPorUid,
        'rejeitadoEm': rejeitadoEm,
        'motivoRejeicao': motivoRejeicao,
        'perfilSolicitado': perfilSolicitado,
      });

  UserProfile copyWith({
    String? nome,
    PerfilUsuario? perfil,
    bool? ativo,
    StatusAprovacao? statusAprovacao,
    bool? trocaSenhaObrigatoria,
    String? atualizadoEm,
    String? motivoRejeicao,
  }) =>
      UserProfile(
        uid: uid,
        email: email,
        nome: nome ?? this.nome,
        perfil: perfil ?? this.perfil,
        ativo: ativo ?? this.ativo,
        criadoEm: criadoEm,
        atualizadoEm: atualizadoEm ?? this.atualizadoEm,
        statusAprovacao: statusAprovacao ?? this.statusAprovacao,
        trocaSenhaObrigatoria: trocaSenhaObrigatoria ?? this.trocaSenhaObrigatoria,
        senhaAlteradaEm: senhaAlteradaEm,
        senhaRedefinidaEm: senhaRedefinidaEm,
        senhaRedefinidaPorUid: senhaRedefinidaPorUid,
        criadoPorUid: criadoPorUid,
        aprovadoPorUid: aprovadoPorUid,
        aprovadoEm: aprovadoEm,
        rejeitadoPorUid: rejeitadoPorUid,
        rejeitadoEm: rejeitadoEm,
        motivoRejeicao: motivoRejeicao ?? this.motivoRejeicao,
        perfilSolicitado: perfilSolicitado,
      );
}

Map<String, dynamic> _semNulos(Map<String, dynamic> m) =>
    Map.fromEntries(m.entries.where((e) => e.value != null));

class RoleConfig {
  final PerfilUsuario id;
  final String titulo;

  /// Rótulo compacto para pills/áreas estreitas.
  final String tituloCurto;
  final String descricao;
  final Color badgeBg;
  final Color badgeText;
  final Color borderColor;
  final Color iconColor;
  final bool canConsultar;
  final bool canCadastrar;
  final bool canEditar;
  final bool canExcluir;
  final bool canAprovar;
  final bool canSolicitar;
  final bool canGerenciarUsuarios;
  final bool canVerLogs;

  const RoleConfig({
    required this.id,
    required this.titulo,
    required this.tituloCurto,
    required this.descricao,
    required this.badgeBg,
    required this.badgeText,
    required this.borderColor,
    required this.iconColor,
    required this.canConsultar,
    required this.canCadastrar,
    required this.canEditar,
    required this.canExcluir,
    required this.canAprovar,
    required this.canSolicitar,
    required this.canGerenciarUsuarios,
    required this.canVerLogs,
  });
}

const Map<UserRole, RoleConfig> rolesConfig = {
  UserRole.admin: RoleConfig(
    id: 'admin',
    titulo: 'Programadora / Administradora',
    tituloCurto: 'Administração',
    descricao:
        'Responsável pelo sistema: cria e bloqueia usuários, define perfis de acesso, cadastra, edita e exclui registros, aprova solicitações e administra permissões. Todas as exclusões são registradas em histórico/log.',
    badgeBg: Color(0xFFF3E8FF),
    badgeText: Color(0xFF6B21A8),
    borderColor: Color(0xFFA855F7),
    iconColor: Color(0xFF7C3AED),
    canConsultar: true,
    canCadastrar: true,
    canEditar: true,
    canExcluir: true,
    canAprovar: true,
    canSolicitar: true,
    canGerenciarUsuarios: true,
    canVerLogs: true,
  ),
  UserRole.projetista: RoleConfig(
    id: 'projetista',
    titulo: 'Projetista – Ferramentaria',
    tituloCurto: 'Projetista',
    descricao:
        'Atua na análise e aprovação das solicitações: consulta dispositivos e projetos, cadastra e edita informações, aprova solicitações de reutilização e atualiza status e andamento. Não pode excluir registros.',
    badgeBg: Color(0xFFDCFCE7),
    badgeText: Color(0xFF15803D),
    borderColor: Color(0xFF22C55E),
    iconColor: Color(0xFF16A34A),
    canConsultar: true,
    canCadastrar: true,
    canEditar: true,
    canExcluir: false,
    canAprovar: true,
    canSolicitar: true,
    canGerenciarUsuarios: false,
    canVerLogs: false,
  ),
  UserRole.engenharia: RoleConfig(
    id: 'engenharia',
    titulo: 'Engenharia de Processo / Industrial',
    tituloCurto: 'Engenharia',
    descricao:
        'Faz a consulta e solicita reutilização de dispositivos: consulta dispositivos existentes, verifica possibilidade de reutilização, solicita reutilização e acompanha o status da solicitação. Não pode cadastrar, editar ou excluir registros.',
    badgeBg: Color(0xFFFFEDD5),
    badgeText: Color(0xFFC2410C),
    borderColor: Color(0xFFF97316),
    iconColor: Color(0xFFEA580C),
    canConsultar: true,
    canCadastrar: false,
    canEditar: false,
    canExcluir: false,
    canAprovar: false,
    canSolicitar: true,
    canGerenciarUsuarios: false,
    canVerLogs: false,
  ),
  UserRole.gerencia: RoleConfig(
    id: 'gerencia',
    titulo: 'Gerência',
    tituloCurto: 'Gerência',
    descricao:
        'Acompanha e consulta as informações do sistema: consulta projetos, dispositivos e reutilizações, acompanha indicadores e resultados e visualiza histórico e movimentações. Não pode cadastrar, editar, excluir ou aprovar.',
    badgeBg: Color(0xFFDBEAFE),
    badgeText: Color(0xFF1E40AF),
    borderColor: Color(0xFF3B82F6),
    iconColor: Color(0xFF2563EB),
    canConsultar: true,
    canCadastrar: false,
    canEditar: false,
    canExcluir: false,
    canAprovar: false,
    canSolicitar: false,
    canGerenciarUsuarios: false,
    // Auditoria é exclusiva da Administração; Gerência segue somente leitura nos dados.
    canVerLogs: false,
  ),
};

/// Convidado: cadastro público aguardando aprovação — nenhuma permissão.
const RoleConfig convidadoConfig = RoleConfig(
  id: perfilConvidado,
  titulo: 'Convidado',
  tituloCurto: 'Convidado',
  descricao:
      'Cadastro realizado pelo próprio colaborador e aguardando a análise da Administração. Não consulta nem altera dados até que um cargo seja definido na aprovação.',
  badgeBg: Color(0xFFF3F4F6),
  badgeText: Color(0xFF4B5563),
  borderColor: Color(0xFF9CA3AF),
  iconColor: Color(0xFF6B7280),
  canConsultar: false,
  canCadastrar: false,
  canEditar: false,
  canExcluir: false,
  canAprovar: false,
  canSolicitar: false,
  canGerenciarUsuarios: false,
  canVerLogs: false,
);

/// Cargos que a Administração pode atribuir.
const List<UserRole> perfisAtribuiveis = UserRole.values;

bool isPerfilAtribuivel(Object? perfil) =>
    perfil is String && userRoleFromString(perfil) != null;

/// Configuração do perfil; valores desconhecidos caem no menor privilégio.
RoleConfig configDoPerfil(String? perfil) {
  final role = userRoleFromString(perfil);
  return role == null ? convidadoConfig : rolesConfig[role]!;
}

/// Situação de acesso derivada do perfil persistido.
enum SituacaoUsuario { pendente, ativo, bloqueado, rejeitado }

SituacaoUsuario situacaoDoUsuario(UserProfile u) {
  if (u.statusAprovacao == StatusAprovacao.rejeitado) return SituacaoUsuario.rejeitado;
  if (u.statusAprovacao == StatusAprovacao.pendente) return SituacaoUsuario.pendente;
  if (u.ativo) {
    return isPerfilAtribuivel(u.perfil) ? SituacaoUsuario.ativo : SituacaoUsuario.pendente;
  }
  // Legado: o autocadastro antigo gravava `perfilSolicitado` numa conta Gerência inativa.
  if (u.statusAprovacao == null && u.perfil == 'gerencia' && u.perfilSolicitado != null) {
    return SituacaoUsuario.pendente;
  }
  return SituacaoUsuario.bloqueado;
}

/// Conta liberada para operar no sistema com as permissões do seu cargo.
bool isContaOperacional(UserProfile? u) =>
    u != null && situacaoDoUsuario(u) == SituacaoUsuario.ativo && !u.trocaSenhaObrigatoria;

/// Sessões que podem permanecer abertas: operacionais e convidados em análise.
bool podeManterSessao(UserProfile? u) {
  if (u == null) return false;
  final s = situacaoDoUsuario(u);
  return s == SituacaoUsuario.ativo || s == SituacaoUsuario.pendente;
}

/// Para onde a sessão autenticada deve ir.
enum TelaDaSessao { login, aguardandoAprovacao, trocaSenha, sistema }

TelaDaSessao telaDaSessao(UserProfile? u) {
  if (!podeManterSessao(u)) return TelaDaSessao.login;
  if (situacaoDoUsuario(u!) == SituacaoUsuario.pendente) return TelaDaSessao.aguardandoAprovacao;
  if (u.trocaSenhaObrigatoria) return TelaDaSessao.trocaSenha;
  return TelaDaSessao.sistema;
}

bool isAdministrador(UserProfile? u) => isContaOperacional(u) && u!.perfil == 'admin';

/// Mensagem exibida quando uma conta não pode iniciar sessão.
String mensagemAcessoNegado(UserProfile u) {
  if (situacaoDoUsuario(u) == SituacaoUsuario.rejeitado) {
    final motivo = u.motivoRejeicao;
    return 'Sua solicitação de cadastro foi recusada pela Administração.${motivo != null && motivo.isNotEmpty ? ' Motivo: $motivo' : ''}';
  }
  return 'Este usuário foi desativado pela Administradora. Contate o suporte.';
}
