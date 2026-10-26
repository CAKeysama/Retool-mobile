import 'user.dart';

enum SolicitacaoCargoStatus {
  pendente('Pendente'),
  aprovada('Aprovada'),
  rejeitada('Rejeitada');

  final String rotulo;
  const SolicitacaoCargoStatus(this.rotulo);

  static SolicitacaoCargoStatus fromValor(String? v) =>
      SolicitacaoCargoStatus.values.firstWhere((s) => s.name == v, orElse: () => SolicitacaoCargoStatus.pendente);
}

/// Pedido do próprio usuário para mudar de cargo; só a Administração decide.
class SolicitacaoCargo {
  final String id;
  final String usuarioUid;
  final String usuarioNome;
  final String usuarioEmail;
  final UserRole perfilAtual;
  final UserRole perfilSolicitado;
  final String? justificativa;
  final SolicitacaoCargoStatus status;
  final String dataSolicitacao;
  final String? decididoPorUid;
  final String? decididoPorNome;
  final String? dataDecisao;
  final String? motivoDecisao;

  const SolicitacaoCargo({
    required this.id,
    required this.usuarioUid,
    required this.usuarioNome,
    required this.usuarioEmail,
    required this.perfilAtual,
    required this.perfilSolicitado,
    this.justificativa,
    this.status = SolicitacaoCargoStatus.pendente,
    required this.dataSolicitacao,
    this.decididoPorUid,
    this.decididoPorNome,
    this.dataDecisao,
    this.motivoDecisao,
  });

  factory SolicitacaoCargo.fromMap(String id, Map<String, dynamic> m) => SolicitacaoCargo(
        id: id,
        usuarioUid: (m['usuarioUid'] ?? '').toString(),
        usuarioNome: (m['usuarioNome'] ?? '').toString(),
        usuarioEmail: (m['usuarioEmail'] ?? '').toString(),
        perfilAtual: userRoleFromString(m['perfilAtual'] as String?) ?? UserRole.gerencia,
        perfilSolicitado: userRoleFromString(m['perfilSolicitado'] as String?) ?? UserRole.gerencia,
        justificativa: m['justificativa'] as String?,
        status: SolicitacaoCargoStatus.fromValor(m['status'] as String?),
        dataSolicitacao: (m['dataSolicitacao'] ?? '').toString(),
        decididoPorUid: m['decididoPorUid'] as String?,
        decididoPorNome: m['decididoPorNome'] as String?,
        dataDecisao: m['dataDecisao'] as String?,
        motivoDecisao: m['motivoDecisao'] as String?,
      );

  Map<String, dynamic> toMap() => Map.fromEntries({
        'id': id,
        'usuarioUid': usuarioUid,
        'usuarioNome': usuarioNome,
        'usuarioEmail': usuarioEmail,
        'perfilAtual': perfilAtual.name,
        'perfilSolicitado': perfilSolicitado.name,
        'justificativa': justificativa,
        'status': status.name,
        'dataSolicitacao': dataSolicitacao,
        'decididoPorUid': decididoPorUid,
        'decididoPorNome': decididoPorNome,
        'dataDecisao': dataDecisao,
        'motivoDecisao': motivoDecisao,
      }.entries.where((e) => e.value != null));
}

const int justificativaMax = 500;

/// Quem pode pedir alteração de cargo: contas operacionais fora da Administração.
bool podeSolicitarAlteracaoCargo(UserProfile? usuario) =>
    isContaOperacional(usuario) && usuario!.perfil != 'admin';

/// Valida uma nova solicitação; retorna a mensagem de erro ou null.
String? validarNovaSolicitacaoCargo(
  UserProfile? usuario,
  Object? perfilSolicitado,
  SolicitacaoCargo? pendenteExistente, [
  String? justificativa,
]) {
  if (!podeSolicitarAlteracaoCargo(usuario)) return 'Sua conta não pode solicitar alteração de cargo.';
  if (!isPerfilAtribuivel(perfilSolicitado)) return 'Selecione um cargo válido.';
  if (perfilSolicitado == usuario!.perfil) return 'O cargo solicitado deve ser diferente do cargo atual.';
  if (pendenteExistente != null) return 'Você já possui uma solicitação de alteração de cargo pendente.';
  if (justificativa != null && justificativa.length > justificativaMax) {
    return 'A justificativa deve ter no máximo $justificativaMax caracteres.';
  }
  return null;
}
