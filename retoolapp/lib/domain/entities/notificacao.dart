enum NotificacaoTipo {
  /// Nova solicitação de reutilização aguardando análise.
  reutilizacaoNova('reutilizacao_nova'),

  /// Solicitação de reutilização aprovada/rejeitada.
  reutilizacaoDecidida('reutilizacao_decidida'),

  /// Novo cadastro (Convidado) aguardando aprovação -> Administração.
  contaNova('conta_nova'),

  /// Cadastro aprovado/recusado -> solicitante.
  contaDecidida('conta_decidida'),

  /// Solicitação de alteração de cargo -> Administração.
  cargoSolicitado('cargo_solicitado'),

  /// Alteração de cargo aprovada/rejeitada -> solicitante.
  cargoDecidido('cargo_decidido');

  final String valor;
  const NotificacaoTipo(this.valor);

  static NotificacaoTipo fromValor(String? v) =>
      NotificacaoTipo.values.firstWhere((t) => t.valor == v, orElse: () => NotificacaoTipo.reutilizacaoNova);
}

class Notificacao {
  final String id;
  final NotificacaoTipo tipo;
  final String destinatarioUid;
  final String remetenteUid;
  final String titulo;
  final String descricao;
  final String dataHora;
  final bool lida;
  final bool resolvida;

  /// Id da reutilização, uid do usuário ou id da solicitação de cargo, conforme o tipo.
  final String? entidadeId;

  /// Para navegação direta à tela relacionada.
  final String? dispositivoId;
  final String? perfilSolicitado;

  /// 'aprovada' | 'rejeitada' | 'recusada'
  final String? decisao;

  const Notificacao({
    required this.id,
    required this.tipo,
    required this.destinatarioUid,
    required this.remetenteUid,
    required this.titulo,
    required this.descricao,
    required this.dataHora,
    this.lida = false,
    this.resolvida = false,
    this.entidadeId,
    this.dispositivoId,
    this.perfilSolicitado,
    this.decisao,
  });

  factory Notificacao.fromMap(String id, Map<String, dynamic> m) => Notificacao(
        id: id,
        tipo: NotificacaoTipo.fromValor(m['tipo'] as String?),
        destinatarioUid: (m['destinatarioUid'] ?? '').toString(),
        remetenteUid: (m['remetenteUid'] ?? '').toString(),
        titulo: (m['titulo'] ?? '').toString(),
        descricao: (m['descricao'] ?? '').toString(),
        dataHora: (m['dataHora'] ?? '').toString(),
        lida: m['lida'] == true,
        resolvida: m['resolvida'] == true,
        entidadeId: m['entidadeId'] as String?,
        dispositivoId: m['dispositivoId'] as String?,
        perfilSolicitado: m['perfilSolicitado'] as String?,
        decisao: m['decisao'] as String?,
      );

  Map<String, dynamic> toMap() => Map.fromEntries({
        'id': id,
        'tipo': tipo.valor,
        'destinatarioUid': destinatarioUid,
        'remetenteUid': remetenteUid,
        'titulo': titulo,
        'descricao': descricao,
        'dataHora': dataHora,
        'lida': lida,
        // `resolvida` só existe depois de uma decisão (igual ao desktop).
        'resolvida': resolvida ? true : null,
        'entidadeId': entidadeId,
        'dispositivoId': dispositivoId,
        'perfilSolicitado': perfilSolicitado,
        'decisao': decisao,
      }.entries.where((e) => e.value != null));

  /// Exige ação do destinatário (aprovação pendente para a Administração/Projetista).
  bool get exigeAcao =>
      !resolvida &&
      (tipo == NotificacaoTipo.reutilizacaoNova ||
          tipo == NotificacaoTipo.contaNova ||
          tipo == NotificacaoTipo.cargoSolicitado);
}

/// Id determinístico: impede notificações duplicadas para o mesmo evento.
String idNotificacao(NotificacaoTipo tipo, String entidadeId, String destinatarioUid) =>
    '${tipo.valor}_${entidadeId}_$destinatarioUid';
