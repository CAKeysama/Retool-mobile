import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../application/usecases/acessos_comum.dart' show agoraIso, isoDe;
import '../../domain/entities/audit_log.dart';
import '../../domain/entities/classificacao.dart';
import '../../domain/entities/dispositivo.dart';
import '../../domain/entities/notificacao.dart';
import '../../domain/entities/reutilizacao.dart';
import '../../domain/entities/solicitacao_cargo.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/repositories.dart';

const _uuid = Uuid();

/// Remove chaves nulas (o desktop nunca grava `undefined`).
Map<String, dynamic> semNulos(Map<String, dynamic> m) =>
    Map.fromEntries(m.entries.where((e) => e.value != null));

class FirestoreUsersRepository implements UsersRepository {
  final FirebaseFirestore db;
  FirestoreUsersRepository(this.db);

  CollectionReference<Map<String, dynamic>> get _col => db.collection('users');

  @override
  Future<UserProfile?> getProfile(String uid) async {
    final snap = await _col.doc(uid).get();
    return snap.exists ? UserProfile.fromMap(snap.id, snap.data()!) : null;
  }

  @override
  Future<void> setProfile(UserProfile profile) => _col.doc(profile.uid).set(profile.toMap());

  @override
  Future<void> updateProfile(String uid, Map<String, dynamic> data) => _col.doc(uid).update(semNulos(data));

  @override
  Future<void> updateRole(String uid, UserRole perfil) =>
      _col.doc(uid).update({'perfil': perfil.name, 'atualizadoEm': agoraIso()});

  @override
  Future<void> updateStatus(String uid, bool ativo) =>
      _col.doc(uid).update({'ativo': ativo, 'atualizadoEm': agoraIso()});

  @override
  Future<void> deleteProfile(String uid) => _col.doc(uid).delete();

  @override
  Future<List<UserProfile>> listarAdministradoresAtivos() async {
    // Filtra por `perfil == 'admin'`: único recorte que as regras liberam para convidados.
    final snap = await _col.where('perfil', isEqualTo: 'admin').get();
    return snap.docs.map((d) => UserProfile.fromMap(d.id, d.data())).where((u) => u.ativo).toList();
  }

  @override
  Stream<List<UserProfile>> watchAll() =>
      _col.snapshots().map((s) => s.docs.map((d) => UserProfile.fromMap(d.id, d.data())).toList());

  @override
  Stream<UserProfile?> watchProfile(String uid) => _col
      .doc(uid)
      .snapshots(includeMetadataChanges: true)
      // Escrita local pendente (ex.: troca de senha) não libera permissões antes do servidor.
      .where((s) => !s.metadata.hasPendingWrites)
      .map((s) => s.exists ? UserProfile.fromMap(s.id, s.data()!) : null);
}

/// Converte Timestamp/ISO legado em string ISO.
String normalizarDataHora(Object? raw) {
  if (raw is Timestamp) return isoDe(raw.toDate());
  if (raw is DateTime) return isoDe(raw);
  if (raw is String) return raw;
  return agoraIso();
}

AuditLog mapearLog(DocumentSnapshot<Map<String, dynamic>> d) {
  final dados = d.data() ?? const {};
  final dataHora = dados['dataHoraServidor'] != null
      ? normalizarDataHora(dados['dataHoraServidor'])
      : normalizarDataHora(dados['dataHora']);
  return AuditLog.fromMap(d.id, dados, dataHora: dataHora);
}

class FirestoreAuditLogRepository implements AuditLogRepository {
  final FirebaseFirestore db;
  FirestoreAuditLogRepository(this.db);

  CollectionReference<Map<String, dynamic>> get _col => db.collection('audit_logs');

  @override
  Future<String> registrarLog(AuditLogInput input) async {
    final id = _uuid.v4();
    // `dataHora` como ISO (ordenação homogênea com o acervo legado);
    // `dataHoraServidor` é o carimbo autoritativo do servidor.
    await _col.doc(id).set({
      ...input.toMap(),
      'id': id,
      'dataHora': agoraIso(),
      'dataHoraServidor': FieldValue.serverTimestamp(),
    });
    return id;
  }

  @override
  Stream<List<AuditLog>> watchLogs({int max = 100}) =>
      _col.orderBy('dataHora', descending: true).limit(max).snapshots().map((s) {
        final list = s.docs.map(mapearLog).toList()..sort((a, b) => b.dataHora.compareTo(a.dataHora));
        return list;
      });

  Query<Map<String, dynamic>> _comFiltros(FiltrosAuditoria f) {
    Query<Map<String, dynamic>> q = _col;
    if (f.acao != null) {
      q = q.where('acao', isEqualTo: f.acao!.valor);
    } else if (f.categoria != null) {
      q = q.where('acao', whereIn: acoesPorCategoria[f.categoria]!.map((a) => a.valor).toList());
    }
    if (f.usuarioUid != null) q = q.where('usuarioUid', isEqualTo: f.usuarioUid);
    if (f.tipoEntidade != null) q = q.where('tipoEntidade', isEqualTo: f.tipoEntidade!.valor);
    if (f.somenteFalhas) q = q.where('resultado', whereIn: ['falha', 'negado']);
    if (f.de != null) q = q.where('dataHora', isGreaterThanOrEqualTo: f.de);
    if (f.ate != null) q = q.where('dataHora', isLessThanOrEqualTo: f.ate);
    return q;
  }

  @override
  Future<PaginaAuditoria> listarPagina(FiltrosAuditoria filtros, int tamanho, {Object? apos}) async {
    var q = _comFiltros(filtros).orderBy('dataHora', descending: true);
    if (apos is DocumentSnapshot) q = q.startAfterDocument(apos);
    final snap = await q.limit(tamanho + 1).get();
    final docs = snap.docs.take(tamanho).toList();
    return PaginaAuditoria(
      logs: docs.map(mapearLog).toList(),
      cursor: docs.isNotEmpty ? docs.last : null,
      temMais: snap.docs.length > tamanho,
    );
  }

  @override
  Future<int> contar(FiltrosAuditoria filtros) async {
    final snap = await _comFiltros(filtros).count().get();
    return snap.count ?? 0;
  }
}

class FirestoreNotificationsRepository implements NotificationsRepository {
  final FirebaseFirestore db;
  FirestoreNotificationsRepository(this.db);

  CollectionReference<Map<String, dynamic>> get _col => db.collection('notifications');

  @override
  Future<void> criar(Notificacao n) => _col.doc(n.id).set(n.toMap());

  @override
  Future<void> marcarLida(String id, bool lida) => _col.doc(id).update({'lida': lida});

  @override
  Future<void> marcarResolvida(String id, bool resolvida) => _col.doc(id).update({'resolvida': resolvida});

  @override
  Stream<List<Notificacao>> watchParaUsuario(String uid) => _col
      .where('destinatarioUid', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map((d) => Notificacao.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => b.dataHora.compareTo(a.dataHora)))
      .handleError((Object e) => debugPrint('Falha ao sincronizar notificações: $e'));
}

class FirestoreSolicitacoesCargoRepository implements SolicitacoesCargoRepository {
  final FirebaseFirestore db;
  FirestoreSolicitacoesCargoRepository(this.db);

  static const _colecao = 'solicitacoes_cargo';

  /// Trava `pendencias_cargo/{uid}`: uma única solicitação pendente por usuário.
  static const _travas = 'pendencias_cargo';

  List<SolicitacaoCargo> _ordenar(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs.map((d) => SolicitacaoCargo.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => b.dataSolicitacao.compareTo(a.dataSolicitacao));

  @override
  Future<SolicitacaoCargo?> obter(String id) async {
    final snap = await db.collection(_colecao).doc(id).get();
    return snap.exists ? SolicitacaoCargo.fromMap(snap.id, snap.data()!) : null;
  }

  @override
  Future<SolicitacaoCargo?> obterPendenteDoUsuario(String uid) async {
    final trava = await db.collection(_travas).doc(uid).get();
    if (!trava.exists) return null;
    final s = await obter(trava.data()!['solicitacaoId'] as String);
    return s != null && s.status == SolicitacaoCargoStatus.pendente ? s : null;
  }

  @override
  Future<void> criar(SolicitacaoCargo s) async {
    final batch = db.batch();
    batch.set(db.collection(_colecao).doc(s.id), s.toMap());
    batch.set(db.collection(_travas).doc(s.usuarioUid), {'solicitacaoId': s.id, 'criadoEm': s.dataSolicitacao});
    await batch.commit();
  }

  @override
  Future<void> decidir(SolicitacaoCargo s, DecisaoSolicitacaoCargo decisao) async {
    final batch = db.batch();
    batch.update(db.collection(_colecao).doc(s.id), decisao.toMap());
    if (decisao.status == SolicitacaoCargoStatus.aprovada) {
      // A troca efetiva do cargo acontece somente aqui, na aprovação.
      batch.update(db.collection('users').doc(s.usuarioUid),
          {'perfil': s.perfilSolicitado.name, 'atualizadoEm': decisao.dataDecisao});
    }
    batch.delete(db.collection(_travas).doc(s.usuarioUid));
    await batch.commit();
  }

  @override
  Stream<List<SolicitacaoCargo>> watchTodas() => db.collection(_colecao).snapshots().map(_ordenar);

  @override
  Stream<List<SolicitacaoCargo>> watchDoUsuario(String uid) =>
      db.collection(_colecao).where('usuarioUid', isEqualTo: uid).snapshots().map(_ordenar);
}

class FirestoreClassificacoesRepository implements ClassificacoesRepository {
  final FirebaseFirestore db;
  FirestoreClassificacoesRepository(this.db);

  @override
  Stream<List<Classificacao>> watchAll(TipoClassificacao tipo) =>
      db.collection(tipo.colecao).snapshots().map((s) => s.docs
          .map((d) => Classificacao.fromMap(d.id, d.data()))
          .toList()
        ..sort((a, b) => compararNomes(a.nome, b.nome)));

  @override
  Future<String> add(TipoClassificacao tipo, {required String nome, bool ativo = true}) async {
    final id = _uuid.v4();
    await db.collection(tipo.colecao).doc(id).set({'id': id, 'nome': nome, 'ativo': ativo});
    return id;
  }

  @override
  Future<void> update(TipoClassificacao tipo, String id, Map<String, dynamic> data) =>
      db.collection(tipo.colecao).doc(id).update(semNulos(data));

  @override
  Future<void> delete(TipoClassificacao tipo, String id) => db.collection(tipo.colecao).doc(id).delete();
}

class FirestoreReutilizacoesRepository implements ReutilizacoesRepository {
  final FirebaseFirestore db;
  FirestoreReutilizacoesRepository(this.db);

  CollectionReference<Map<String, dynamic>> get _col => db.collection('reutilizacoes');

  @override
  Stream<List<Reutilizacao>> watchAll() =>
      _col.snapshots().map((s) => s.docs.map((d) => Reutilizacao.fromMap(d.id, d.data())).toList());

  @override
  Future<String> add(Map<String, dynamic> data) async {
    final id = _uuid.v4();
    await _col.doc(id).set({...semNulos(data), 'id': id, 'dataCriacao': agoraIso()});
    return id;
  }

  @override
  Future<void> update(String id, Map<String, dynamic> data) => _col.doc(id).update(semNulos(data));

  @override
  Future<void> delete(String id) => _col.doc(id).delete();
}

class FirestoreDispositivosRepository implements DispositivosRepository {
  final FirebaseFirestore db;
  final StorageService? storage;
  FirestoreDispositivosRepository(this.db, {this.storage});

  CollectionReference<Map<String, dynamic>> get _col => db.collection('dispositivos');

  @override
  Stream<List<Dispositivo>> watchAll() =>
      _col.snapshots().map((s) => s.docs.map((d) => Dispositivo.fromMap(d.id, d.data())).toList());

  @override
  Future<String> add(Map<String, dynamic> data, {String? id}) async {
    final novoId = id ?? (data['id'] as String?) ?? _uuid.v4();
    await _col.doc(novoId).set({...semNulos(data), 'id': novoId, 'dataCriacao': agoraIso()});
    return novoId;
  }

  @override
  Future<void> update(String id, Map<String, dynamic> data) => _col.doc(id).update(semNulos(data));

  @override
  Future<void> delete(String id) async {
    await _col.doc(id).delete();
    await storage?.deleteFolder('retool/dispositivos/$id');
  }

  /// Cria classificações ausentes (sem duplicar por caixa/espaços). Retorna nome -> id.
  Future<Map<String, String>> _criarClassificacoes(
      TipoClassificacao tipo, List<String> nomes, List<Classificacao> existentes) async {
    final criados = <String, String>{};
    String chave(String s) => s.toLowerCase().trim();
    var batch = db.batch();
    var count = 0;
    for (final nome in nomes) {
      final existente = existentes.where((c) => chave(c.nome) == chave(nome)).firstOrNull;
      if (existente != null) {
        criados[nome] = existente.id;
        continue;
      }
      final jaCriado = criados.entries.where((e) => chave(e.key) == chave(nome)).firstOrNull;
      if (jaCriado != null) {
        criados[nome] = jaCriado.value;
        continue;
      }
      final id = _uuid.v4();
      batch.set(db.collection(tipo.colecao).doc(id), {'id': id, 'nome': nome, 'ativo': true});
      criados[nome] = id;
      count++;
      if (count == 500) {
        await batch.commit();
        batch = db.batch();
        count = 0;
      }
    }
    if (count > 0) await batch.commit();
    return criados;
  }

  @override
  Future<ResultadoImportacaoLote> importarLote({
    required List<Map<String, dynamic>> novosDispositivos,
    required List<String> novasCategorias,
    required List<String> novasFamilias,
    required List<String> novosProdutos,
    required List<Classificacao> categoriasExistentes,
    required List<Classificacao> familiasExistentes,
    required List<Classificacao> produtosExistentes,
  }) async {
    final categorias = await _criarClassificacoes(TipoClassificacao.categoria, novasCategorias, categoriasExistentes);
    final familias = await _criarClassificacoes(TipoClassificacao.familia, novasFamilias, familiasExistentes);
    final produtos = await _criarClassificacoes(TipoClassificacao.produto, novosProdutos, produtosExistentes);

    // Identidade = Código + Dispositivo: mesma combinação atualiza; outra cria documento novo.
    final snap = await _col.get();
    final idPorChave = <String, String>{};
    for (final d in snap.docs) {
      idPorChave.putIfAbsent(chaveCodigoDispositivo(d.data()['codigo'], d.data()['nome']), () => d.id);
    }

    String? resolver(String? valor, Map<String, String> criados) {
      if (valor == null || valor.isEmpty) return valor;
      if (criados.containsKey(valor)) return criados[valor];
      for (final e in criados.entries) {
        if (e.key.toLowerCase().trim() == valor.toLowerCase().trim()) return e.value;
      }
      return valor;
    }

    var batch = db.batch();
    var pendentes = <bool>[];
    var inseridos = 0, atualizados = 0, erros = 0;
    final falhas = <String>[];
    final criadosNestaImportacao = <String>{};

    Future<void> commitLote() async {
      if (pendentes.isEmpty) return;
      final lote = pendentes;
      final atual = batch;
      pendentes = [];
      batch = db.batch();
      try {
        await atual.commit();
        for (final novo in lote) {
          novo ? inseridos++ : atualizados++;
        }
      } catch (e) {
        erros += lote.length;
        falhas.add(e.toString());
      }
    }

    for (final original in novosDispositivos) {
      final disp = Map<String, dynamic>.from(original);
      if (disp['categoriaId'] != null) disp['categoriaId'] = resolver(disp['categoriaId'] as String?, categorias);
      if (disp['familiaId'] != null) disp['familiaId'] = resolver(disp['familiaId'] as String?, familias);
      if (disp['produtoId'] != null) disp['produtoId'] = resolver(disp['produtoId'] as String?, produtos);

      final chave = chaveCodigoDispositivo(disp['codigo'], disp['nome']);
      final existenteId = idPorChave[chave];
      final id = existenteId ?? _uuid.v4();
      idPorChave[chave] = id;
      if (existenteId == null) criadosNestaImportacao.add(id);

      Map<String, dynamic> dados;
      if (existenteId != null && !criadosNestaImportacao.contains(existenteId)) {
        // A planilha não traz imagens: campos vazios não apagam imagens existentes.
        dados = semNulos(disp);
        for (final campo in CampoImagemDispositivo.values) {
          final v = dados[campo.campo];
          if (v == null || (v is String && v.isEmpty)) dados.remove(campo.campo);
        }
      } else {
        dados = {...semNulos(disp), 'id': id, 'dataCriacao': agoraIso()};
      }
      batch.set(_col.doc(id), dados, SetOptions(merge: true));
      pendentes.add(existenteId == null);
      if (pendentes.length == 500) await commitLote();
    }
    await commitLote();

    return ResultadoImportacaoLote(
      sucesso: inseridos + atualizados,
      erros: erros,
      inseridos: inseridos,
      atualizados: atualizados,
      falhas: falhas,
    );
  }

  @override
  Future<ResultadoExclusaoLote> excluirEmLote(List<String> ids) async {
    var excluidos = 0, erros = 0;
    final falhas = <String>[];
    for (var i = 0; i < ids.length; i += 500) {
      final lote = ids.sublist(i, i + 500 > ids.length ? ids.length : i + 500);
      final batch = db.batch();
      for (final id in lote) {
        batch.delete(_col.doc(id));
      }
      try {
        await batch.commit();
        excluidos += lote.length;
      } catch (e) {
        erros += lote.length;
        falhas.add(e.toString());
      }
    }
    return ResultadoExclusaoLote(excluidos: excluidos, erros: erros, falhas: falhas);
  }
}
