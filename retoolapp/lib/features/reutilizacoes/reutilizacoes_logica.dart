import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/utils/busca.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/entities/dispositivo.dart';
import '../../domain/entities/reutilizacao.dart';
import '../../domain/entities/user.dart';

/// Regras puras da tela de Reutilizações (espelham `pages/Reutilizacoes.tsx` do desktop).

/// Status que compõem a Fila do Projetista.
const filaProjetistaStatus = {ReutilizacaoStatus.emAnaliseProjetista, ReutilizacaoStatus.aguardandoNovoFiltro};

/// Status que compõem a Fila da Engenharia.
const filaEngenhariaStatus = {
  ReutilizacaoStatus.emAnaliseEngenharia,
  ReutilizacaoStatus.aprovada,
  ReutilizacaoStatus.naoAprovada,
};

enum AbaReutilizacoes {
  filaProjetista('Fila do Projetista'),
  filaEngenharia('Fila da Engenharia'),
  historico('Histórico Geral');

  final String rotulo;
  const AbaReutilizacoes(this.rotulo);

  bool get ehFila => this != historico;
}

/// Abas visíveis por perfil, na ordem do desktop.
List<AbaReutilizacoes> abasDoPerfil(PerfilUsuario perfil) => [
      if (perfil == 'projetista' || perfil == 'admin') AbaReutilizacoes.filaProjetista,
      if (perfil == 'engenharia' || perfil == 'admin') AbaReutilizacoes.filaEngenharia,
      AbaReutilizacoes.historico,
    ];

/// Aba aberta ao chegar de uma notificação (mesma regra do `useEffect` do desktop).
AbaReutilizacoes abaParaDestaque(PerfilUsuario perfil, ReutilizacaoStatus status) {
  final admin = perfil == 'admin';
  if (filaProjetistaStatus.contains(status) && (perfil == 'projetista' || admin)) {
    return AbaReutilizacoes.filaProjetista;
  }
  if (filaEngenhariaStatus.contains(status) && (perfil == 'engenharia' || admin)) {
    return AbaReutilizacoes.filaEngenharia;
  }
  return AbaReutilizacoes.historico;
}

/// Botão de etapa do fluxo (rótulo, ícone e cor idênticos ao desktop).
class AcaoFluxo {
  final ReutilizacaoStatus para;
  final String rotulo;
  final IconData icone;
  final AppButtonVariant variante;

  /// "Não Aprovar" exige o motivo.
  final bool exigeMotivo;

  const AcaoFluxo(this.para, this.rotulo, this.icone, this.variante, {this.exigeMotivo = false});
}

AcaoFluxo? _acaoPara(ReutilizacaoStatus de, ReutilizacaoStatus para) {
  switch ((de, para)) {
    case (ReutilizacaoStatus.emAnaliseEngenharia, ReutilizacaoStatus.emAnaliseProjetista):
      return AcaoFluxo(para, 'Solicitar Análise (1º Filtro)', LucideIcons.send, AppButtonVariant.primary);
    case (ReutilizacaoStatus.emAnaliseProjetista, ReutilizacaoStatus.aprovada):
      return AcaoFluxo(para, 'Aprovar', LucideIcons.check, AppButtonVariant.success);
    case (ReutilizacaoStatus.emAnaliseProjetista, ReutilizacaoStatus.naoAprovada):
      return AcaoFluxo(para, 'Não Aprovar', LucideIcons.x, AppButtonVariant.danger, exigeMotivo: true);
    case (ReutilizacaoStatus.naoAprovada, ReutilizacaoStatus.aguardandoNovoFiltro):
      return AcaoFluxo(para, 'Solicitar Dispositivo Novo', LucideIcons.factory, AppButtonVariant.primary);
    case (ReutilizacaoStatus.aguardandoNovoFiltro, ReutilizacaoStatus.emAnaliseProjetista):
      return AcaoFluxo(para, 'Similar Encontrado', LucideIcons.wrench, AppButtonVariant.primary);
    case (ReutilizacaoStatus.aguardandoNovoFiltro, ReutilizacaoStatus.liberadoFabricacao):
      return AcaoFluxo(para, 'Liberar Fabricação', LucideIcons.factory, AppButtonVariant.success);
    default:
      return null;
  }
}

/// Ações de fluxo que o perfil executa a partir do status atual.
List<AcaoFluxo> acoesDeFluxo(PerfilUsuario perfil, ReutilizacaoStatus status) => [
      for (final para in transicoesDisponiveis(perfil, status)) ?_acaoPara(status, para),
    ];

enum PeriodoFiltro {
  todos('Todo o período', null),
  dias30('Últimos 30 dias', 30),
  dias90('Últimos 90 dias', 90),
  meses12('Últimos 12 meses', 365);

  final String rotulo;
  final int? dias;
  const PeriodoFiltro(this.rotulo, this.dias);
}

/// Filtros do Histórico Geral (busca + status + dispositivo do desktop; produto e período no mobile).
@immutable
class FiltrosHistorico {
  final String texto;
  final ReutilizacaoStatus? status;
  final String? dispositivoId;
  final String? produtoId;
  final PeriodoFiltro periodo;

  const FiltrosHistorico({
    this.texto = '',
    this.status,
    this.dispositivoId,
    this.produtoId,
    this.periodo = PeriodoFiltro.todos,
  });

  /// Quantidade de filtros (exceto a busca) ativos.
  int get ativos =>
      (status != null ? 1 : 0) +
      (dispositivoId != null ? 1 : 0) +
      (produtoId != null ? 1 : 0) +
      (periodo != PeriodoFiltro.todos ? 1 : 0);

  bool get vazio => ativos == 0 && texto.trim().isEmpty;

  FiltrosHistorico copyWith({
    String? texto,
    ReutilizacaoStatus? Function()? status,
    String? Function()? dispositivoId,
    String? Function()? produtoId,
    PeriodoFiltro? periodo,
  }) =>
      FiltrosHistorico(
        texto: texto ?? this.texto,
        status: status != null ? status() : this.status,
        dispositivoId: dispositivoId != null ? dispositivoId() : this.dispositivoId,
        produtoId: produtoId != null ? produtoId() : this.produtoId,
        periodo: periodo ?? this.periodo,
      );

  FiltrosHistorico semFiltros() => FiltrosHistorico(texto: texto);

  @override
  bool operator ==(Object other) =>
      other is FiltrosHistorico &&
      other.texto == texto &&
      other.status == status &&
      other.dispositivoId == dispositivoId &&
      other.produtoId == produtoId &&
      other.periodo == periodo;

  @override
  int get hashCode => Object.hash(texto, status, dispositivoId, produtoId, periodo);
}

/// Data de referência do registro (`data`, senão `dataCriacao`).
DateTime? dataDeReferencia(Reutilizacao r) {
  final bruto = r.data.isNotEmpty ? r.data : (r.dataCriacao ?? '');
  if (bruto.isEmpty) return null;
  return DateTime.tryParse(bruto);
}

String _chaveOrdenacao(Reutilizacao r) => r.dataCriacao ?? r.data;

/// Listas por aba pré-computadas e memoizadas: só recalculam quando o snapshot
/// (identidade da lista do controller) ou os filtros mudam — nunca a cada build.
class ListasReutilizacoes {
  List<Reutilizacao>? _fonte;
  List<Dispositivo>? _fonteDisp;
  Dispositivo? Function(String?)? _resolver;

  List<Reutilizacao> _todas = const [];
  List<Reutilizacao> _filaProjetista = const [];
  List<Reutilizacao> _filaEngenharia = const [];
  Map<String, String> _textoBusca = const {};
  List<String> _dispositivosReferenciados = const [];

  FiltrosHistorico? _filtrosCache;
  DateTime? _agoraCache;
  List<Reutilizacao> _historico = const [];

  /// Quantas vezes as listas por aba foram recalculadas (usado nos testes de desempenho).
  int recalculos = 0;

  List<Reutilizacao> get todas => _todas;
  List<Reutilizacao> get filaProjetista => _filaProjetista;
  List<Reutilizacao> get filaEngenharia => _filaEngenharia;

  /// Ids dos dispositivos que possuem reutilizações (opções do filtro de dispositivo).
  List<String> get dispositivosReferenciados => _dispositivosReferenciados;

  List<Reutilizacao> fila(AbaReutilizacoes aba) => switch (aba) {
        AbaReutilizacoes.filaProjetista => _filaProjetista,
        AbaReutilizacoes.filaEngenharia => _filaEngenharia,
        AbaReutilizacoes.historico => _historico,
      };

  /// Sincroniza com o snapshot atual (barato quando nada mudou).
  void atualizar(
    List<Reutilizacao> fonte,
    List<Dispositivo> dispositivos,
    Dispositivo? Function(String?) dispositivo,
  ) {
    if (identical(fonte, _fonte) && identical(dispositivos, _fonteDisp)) return;
    final mudouReu = !identical(fonte, _fonte);
    _fonte = fonte;
    _fonteDisp = dispositivos;
    _resolver = dispositivo;
    recalculos++;
    if (mudouReu) {
      final ordenadas = [...fonte]..sort((a, b) => _chaveOrdenacao(b).compareTo(_chaveOrdenacao(a)));
      _todas = List.unmodifiable(ordenadas);
      _filaProjetista = List.unmodifiable(ordenadas.where((r) => filaProjetistaStatus.contains(r.status)));
      _filaEngenharia = List.unmodifiable(ordenadas.where((r) => filaEngenhariaStatus.contains(r.status)));
    }
    _textoBusca = {for (final r in _todas) r.id: _texto(r)};
    final vistos = <String>{};
    _dispositivosReferenciados = [
      for (final r in _todas)
        if (r.dispositivoId.isNotEmpty && vistos.add(r.dispositivoId)) r.dispositivoId,
    ]..sort((a, b) => (dispositivo(a)?.nome ?? a).toLowerCase().compareTo((dispositivo(b)?.nome ?? b).toLowerCase()));
    _filtrosCache = null;
    _pendentes.clear();
  }

  String _texto(Reutilizacao r) {
    final d = _resolver?.call(r.dispositivoId);
    return [
      r.descricaoAlteracao,
      r.responsavel,
      r.solicitanteNome,
      r.codigoPeca,
      r.numeroOs,
      r.descricaoPeca,
      d?.nome,
      d?.codigo,
    ].map(normalizarBusca).join('\u0000');
  }

  /// Texto de busca normalizado do registro (descrição, peça, solicitante, OS, dispositivo).
  String textoBusca(String id) => _textoBusca[id] ?? '';

  /// Histórico filtrado (memoizado pelos filtros).
  List<Reutilizacao> historico(FiltrosHistorico f, {DateTime? agora}) {
    final hoje = agora ?? DateTime.now();
    final dia = DateTime(hoje.year, hoje.month, hoje.day);
    if (_filtrosCache == f && _agoraCache == dia) return _historico;
    _filtrosCache = f;
    _agoraCache = dia;
    final q = normalizarBusca(f.texto).trim();
    final limite = f.periodo.dias == null ? null : dia.subtract(Duration(days: f.periodo.dias!));
    _historico = List.unmodifiable(_todas.where((r) {
      if (f.status != null && r.status != f.status) return false;
      if (f.dispositivoId != null && r.dispositivoId != f.dispositivoId) return false;
      if (f.produtoId != null && r.produtoId != f.produtoId) return false;
      if (limite != null) {
        final d = dataDeReferencia(r);
        if (d == null || d.isBefore(limite)) return false;
      }
      if (q.isNotEmpty && !(_textoBusca[r.id] ?? '').contains(q)) return false;
      return true;
    }));
    return _historico;
  }

  /// Itens da fila em que o perfil tem alguma ação pendente (banner de pendências).
  int pendentes(AbaReutilizacoes aba, PerfilUsuario perfil) {
    if (!aba.ehFila) return 0;
    return _pendentes.putIfAbsent(
        '${aba.name}|$perfil', () => fila(aba).where((r) => transicoesDisponiveis(perfil, r.status).isNotEmpty).length);
  }

  final Map<String, int> _pendentes = {};
}
