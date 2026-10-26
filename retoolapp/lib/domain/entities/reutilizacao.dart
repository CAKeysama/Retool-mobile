import 'package:flutter/painting.dart';

import 'user.dart';

/// Máquina de estados do fluxo de reutilização. `valor` é o texto persistido.
enum ReutilizacaoStatus {
  emAnaliseEngenharia('Em análise (Engenharia)', 'Análise Engenharia'),
  emAnaliseProjetista('Em análise (Projetista)', 'Em análise'),
  aprovada('Reutilização aprovada', 'Aprovada'),
  naoAprovada('Reutilização não aprovada', 'Não aprovada'),
  liberadoFabricacao('Liberado para fabricação (novo dispositivo)', 'Liberado p/ fabricação'),
  aguardandoNovoFiltro('Aguardando novo filtro (Projetista)', 'Novo filtro');

  final String valor;

  /// Rótulo compacto para chips/tabelas.
  final String rotuloCurto;
  const ReutilizacaoStatus(this.valor, this.rotuloCurto);
}

/// Compatibilidade com registros antigos (pendente/aprovado/rejeitado/Em andamento - OS).
ReutilizacaoStatus normalizarStatusReutilizacao(String? status) {
  switch (status) {
    case 'pendente':
      return ReutilizacaoStatus.emAnaliseProjetista;
    case 'aprovado':
      return ReutilizacaoStatus.aprovada;
    case 'rejeitado':
      return ReutilizacaoStatus.naoAprovada;
    // Estado descontinuado (geração de OS removida): tratados como aprovados.
    case 'Em andamento - OS':
      return ReutilizacaoStatus.aprovada;
  }
  for (final s in ReutilizacaoStatus.values) {
    if (s.valor == status) return s;
  }
  return ReutilizacaoStatus.emAnaliseProjetista;
}

/// Transições permitidas por perfil (espelhadas em firestore.rules do desktop).
const Map<UserRole, Map<ReutilizacaoStatus, List<ReutilizacaoStatus>>> transicoesReutilizacao = {
  UserRole.admin: {
    ReutilizacaoStatus.emAnaliseEngenharia: [ReutilizacaoStatus.emAnaliseProjetista],
    ReutilizacaoStatus.emAnaliseProjetista: [ReutilizacaoStatus.aprovada, ReutilizacaoStatus.naoAprovada],
    ReutilizacaoStatus.naoAprovada: [ReutilizacaoStatus.aguardandoNovoFiltro],
    ReutilizacaoStatus.aguardandoNovoFiltro: [ReutilizacaoStatus.emAnaliseProjetista, ReutilizacaoStatus.liberadoFabricacao],
  },
  UserRole.projetista: {
    ReutilizacaoStatus.emAnaliseProjetista: [ReutilizacaoStatus.aprovada, ReutilizacaoStatus.naoAprovada],
    ReutilizacaoStatus.aguardandoNovoFiltro: [ReutilizacaoStatus.emAnaliseProjetista, ReutilizacaoStatus.liberadoFabricacao],
  },
  UserRole.engenharia: {
    ReutilizacaoStatus.emAnaliseEngenharia: [ReutilizacaoStatus.emAnaliseProjetista],
    ReutilizacaoStatus.naoAprovada: [ReutilizacaoStatus.aguardandoNovoFiltro],
  },
  UserRole.gerencia: {},
};

bool transicaoReutilizacaoPermitida(PerfilUsuario perfil, ReutilizacaoStatus de, ReutilizacaoStatus para) {
  final role = userRoleFromString(perfil);
  if (role == null) return false;
  return transicoesReutilizacao[role]?[de]?.contains(para) ?? false;
}

/// Transições que o perfil pode executar a partir do status atual.
List<ReutilizacaoStatus> transicoesDisponiveis(PerfilUsuario perfil, ReutilizacaoStatus de) {
  final role = userRoleFromString(perfil);
  if (role == null) return const [];
  return transicoesReutilizacao[role]?[de] ?? const [];
}

/// Cores de exibição por status (padrão visual do desktop).
({Color fundo, Color texto}) corDoStatusReutilizacao(ReutilizacaoStatus status) {
  switch (status) {
    case ReutilizacaoStatus.emAnaliseEngenharia:
      return (fundo: const Color(0xFFE0E7FF), texto: const Color(0xFF3730A3));
    case ReutilizacaoStatus.emAnaliseProjetista:
      return (fundo: const Color(0x26F5A32B), texto: const Color(0xFFB45309));
    case ReutilizacaoStatus.aguardandoNovoFiltro:
      return (fundo: const Color(0x26785994), texto: const Color(0xFF785994));
    case ReutilizacaoStatus.aprovada:
    case ReutilizacaoStatus.liberadoFabricacao:
      return (fundo: const Color(0xFFDCFCE7), texto: const Color(0xFF00762E));
    case ReutilizacaoStatus.naoAprovada:
      return (fundo: const Color(0xFFFEE2E2), texto: const Color(0xFFE40D2C));
  }
}

class Reutilizacao {
  final String id;
  final String dispositivoId;
  final String data;
  final String codigoPeca;
  final String descricaoPeca;
  final String produtoId;
  final double pesoPeca;
  final double hardSaving;
  final String responsavel;
  final String numeroOs;
  final String descricaoAlteracao;
  final String? dataCriacao;
  final ReutilizacaoStatus status;
  final String? solicitanteId;
  final String? solicitanteNome;
  final String? aprovadorId;
  final String? aprovadorNome;
  final String? dataAprovacao;
  final String? motivoRejeicao;

  const Reutilizacao({
    required this.id,
    required this.dispositivoId,
    this.data = '',
    this.codigoPeca = '',
    this.descricaoPeca = '',
    this.produtoId = '',
    this.pesoPeca = 0,
    this.hardSaving = 0,
    this.responsavel = '',
    this.numeroOs = '',
    this.descricaoAlteracao = '',
    this.dataCriacao,
    this.status = ReutilizacaoStatus.emAnaliseProjetista,
    this.solicitanteId,
    this.solicitanteNome,
    this.aprovadorId,
    this.aprovadorNome,
    this.dataAprovacao,
    this.motivoRejeicao,
  });

  factory Reutilizacao.fromMap(String id, Map<String, dynamic> m) => Reutilizacao(
        id: id,
        dispositivoId: (m['dispositivoId'] ?? '').toString(),
        data: (m['data'] ?? '').toString(),
        codigoPeca: (m['codigoPeca'] ?? '').toString(),
        descricaoPeca: (m['descricaoPeca'] ?? '').toString(),
        produtoId: (m['produtoId'] ?? '').toString(),
        pesoPeca: _num(m['pesoPeca']),
        hardSaving: _num(m['hardSaving']),
        responsavel: (m['responsavel'] ?? '').toString(),
        numeroOs: (m['numeroOs'] ?? '').toString(),
        descricaoAlteracao: (m['descricaoAlteracao'] ?? '').toString(),
        dataCriacao: m['dataCriacao'] as String?,
        status: normalizarStatusReutilizacao(m['status'] as String?),
        solicitanteId: m['solicitanteId'] as String?,
        solicitanteNome: m['solicitanteNome'] as String?,
        aprovadorId: m['aprovadorId'] as String?,
        aprovadorNome: m['aprovadorNome'] as String?,
        dataAprovacao: m['dataAprovacao'] as String?,
        motivoRejeicao: m['motivoRejeicao'] as String?,
      );

  Map<String, dynamic> toMap() => Map.fromEntries({
        'id': id,
        'dispositivoId': dispositivoId,
        'data': data,
        'codigoPeca': codigoPeca,
        'descricaoPeca': descricaoPeca,
        'produtoId': produtoId,
        'pesoPeca': pesoPeca,
        'hardSaving': hardSaving,
        'responsavel': responsavel,
        'numeroOs': numeroOs,
        'descricaoAlteracao': descricaoAlteracao,
        'dataCriacao': dataCriacao,
        'status': status.valor,
        'solicitanteId': solicitanteId,
        'solicitanteNome': solicitanteNome,
        'aprovadorId': aprovadorId,
        'aprovadorNome': aprovadorNome,
        'dataAprovacao': dataAprovacao,
        'motivoRejeicao': motivoRejeicao,
      }.entries.where((e) => e.value != null));
}

double _num(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0;
  return 0;
}
