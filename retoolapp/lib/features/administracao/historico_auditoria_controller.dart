import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/audit_log.dart';
import '../../domain/repositories/repositories.dart';

enum EstadoConsulta { carregando, pronto, erro }

/// Mensagens de erro da consulta ao histórico (iguais às do desktop).
String mensagemErroConsultaAuditoria(Object e) {
  final texto = e.toString();
  if (texto.contains('permission-denied')) {
    return 'Acesso negado: somente a Administração consulta o histórico de ações.';
  }
  if (texto.contains('failed-precondition')) {
    return 'Esta combinação de filtros precisa de um índice no Firestore. Publique os índices do projeto (npx firebase-tools deploy --only firestore:indexes) ou simplifique os filtros.';
  }
  return 'Não foi possível carregar o histórico. Verifique sua conexão e tente novamente.';
}

/// Estado da tela de histórico (`useHistoricoAuditoriaController` do desktop):
/// paginação por cursor no servidor ("Carregar mais" no mobile), total por
/// agregação e aviso em tempo real de novos registros.
class HistoricoAuditoriaController extends ChangeNotifier {
  final AuditLogRepository repo;
  HistoricoAuditoriaController(this.repo, [this._tamanhoPagina = 25]);

  FiltrosAuditoria _filtros = const FiltrosAuditoria();
  int _tamanhoPagina;
  List<AuditLog> _logs = const [];
  Object? _cursor;
  bool _temMais = false;
  EstadoConsulta _estado = EstadoConsulta.carregando;
  bool _carregandoMais = false;
  String _erro = '';
  String? _erroMais;
  int? _total;
  bool _haNovos = false;

  int _requisicao = 0;
  StreamSubscription<List<AuditLog>>? _novosSub;
  bool _disposed = false;

  FiltrosAuditoria get filtros => _filtros;
  int get tamanhoPagina => _tamanhoPagina;
  List<AuditLog> get logs => _logs;
  bool get temMais => _temMais;
  EstadoConsulta get estado => _estado;
  bool get carregandoMais => _carregandoMais;
  String get erro => _erro;
  String? get erroMais => _erroMais;
  int? get total => _total;
  bool get haNovos => _haNovos;

  bool get temFiltros {
    final f = _filtros;
    return f.categoria != null ||
        f.acao != null ||
        f.usuarioUid != null ||
        f.tipoEntidade != null ||
        f.somenteFalhas ||
        f.de != null ||
        f.ate != null;
  }

  /// Quantidade de filtros ativos (badge do botão "Filtros").
  int get quantidadeFiltros {
    final f = _filtros;
    return [f.categoria, f.acao, f.usuarioUid, f.tipoEntidade, f.de, f.ate].where((v) => v != null).length +
        (f.somenteFalhas ? 1 : 0);
  }

  void _notificar() {
    if (!_disposed) notifyListeners();
  }

  void aplicarFiltros(FiltrosAuditoria filtros) {
    _filtros = filtros;
    recarregar();
  }

  void setTamanhoPagina(int n) {
    if (n == _tamanhoPagina) return;
    _tamanhoPagina = n;
    recarregar();
  }

  /// Filtros, tamanho de página ou recarga: volta para a primeira página.
  Future<void> recarregar() async {
    final id = ++_requisicao;
    _logs = const [];
    _cursor = null;
    _temMais = false;
    _haNovos = false;
    _erro = '';
    _erroMais = null;
    _total = null;
    _carregandoMais = false;
    _estado = EstadoConsulta.carregando;
    _notificar();
    _assinarNovos();

    final filtros = _filtros;
    repo.contar(filtros).then((t) {
      if (id == _requisicao) {
        _total = t;
        _notificar();
      }
    }, onError: (_) {});

    try {
      final pagina = await repo.listarPagina(filtros, _tamanhoPagina);
      if (id != _requisicao) return; // resposta obsoleta
      _logs = pagina.logs;
      _cursor = pagina.cursor;
      _temMais = pagina.temMais;
      _estado = EstadoConsulta.pronto;
    } catch (e) {
      if (id != _requisicao) return;
      debugPrint('Falha ao consultar o histórico de ações: $e');
      _erro = mensagemErroConsultaAuditoria(e);
      _estado = EstadoConsulta.erro;
    }
    _notificar();
  }

  Future<void> carregarMais() async {
    if (!_temMais || _carregandoMais || _estado != EstadoConsulta.pronto) return;
    final id = _requisicao;
    _carregandoMais = true;
    _erroMais = null;
    _notificar();
    try {
      final pagina = await repo.listarPagina(_filtros, _tamanhoPagina, apos: _cursor);
      if (id != _requisicao) return;
      _logs = [..._logs, ...pagina.logs];
      _cursor = pagina.cursor;
      _temMais = pagina.temMais;
    } catch (e) {
      if (id != _requisicao) return;
      _erroMais = mensagemErroConsultaAuditoria(e);
    } finally {
      if (id == _requisicao) {
        _carregandoMais = false;
        _notificar();
      }
    }
  }

  /// Aviso de novos registros sem recarregar a lista em exibição.
  void _assinarNovos() {
    _novosSub?.cancel();
    String? referencia;
    var primeira = true;
    _novosSub = repo.watchLogs(max: 1).listen((lista) {
      final maisRecente = lista.isEmpty ? '' : lista.first.id;
      if (primeira) {
        primeira = false;
        referencia = maisRecente;
        return;
      }
      if (maisRecente.isNotEmpty && maisRecente != referencia && !_haNovos) {
        _haNovos = true;
        _notificar();
      }
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _disposed = true;
    _novosSub?.cancel();
    super.dispose();
  }
}
