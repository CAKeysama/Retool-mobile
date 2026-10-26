import 'dart:async';
import 'dart:typed_data';

import 'package:retoolapp/application/usecases/acessos_comum.dart';
import 'package:retoolapp/core/config/app_dependencies.dart';
import 'package:retoolapp/domain/entities/audit_log.dart';
import 'package:retoolapp/domain/entities/classificacao.dart';
import 'package:retoolapp/domain/entities/dispositivo.dart';
import 'package:retoolapp/domain/entities/file_attachment.dart';
import 'package:retoolapp/domain/entities/notificacao.dart';
import 'package:retoolapp/domain/entities/reutilizacao.dart';
import 'package:retoolapp/domain/entities/solicitacao_cargo.dart';
import 'package:retoolapp/domain/entities/user.dart';
import 'package:retoolapp/domain/errors.dart';
import 'package:retoolapp/domain/repositories/repositories.dart';
import 'package:retoolapp/domain/services/file_validators.dart';

/// Fakes em memória de todos os contratos da camada de dados.
/// Streams emitem o estado atual na assinatura e a cada mudança (como `onSnapshot`).

class _Colecao<T> {
  final Map<String, T> itens = {};
  final _ctrl = StreamController<List<T>>.broadcast();

  void emitir() => _ctrl.add(itens.values.toList());

  Stream<List<T>> watch() async* {
    yield itens.values.toList();
    yield* _ctrl.stream;
  }
}

class FakeAuthGateway implements AuthGateway {
  final _ctrl = StreamController<AuthUser?>.broadcast();
  AuthUser? _atual;

  /// email -> (senha, uid)
  final Map<String, ({String senha, String uid})> contas = {};
  final List<String> contasSecundariasCriadas = [];
  int _seq = 0;

  /// Força erro (ex.: `ErroAmigavel('E-mail ou senha incorretos.')`) no próximo signIn.
  Object? erroNoLogin;

  void registrarConta(String email, String senha, String uid) => contas[email] = (senha: senha, uid: uid);

  /// Simula uma sessão já autenticada (app reaberto).
  void entrarComo(AuthUser? user) {
    _atual = user;
    _ctrl.add(user);
  }

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield _atual;
    yield* _ctrl.stream;
  }

  @override
  AuthUser? get currentUser => _atual;

  @override
  Future<AuthUser> signIn(String email, String senha) async {
    if (erroNoLogin != null) {
      final e = erroNoLogin!;
      erroNoLogin = null;
      throw e;
    }
    final c = contas[email];
    if (c == null || c.senha != senha) throw const ErroAmigavel('E-mail ou senha incorretos.', codigo: 'invalid-credential');
    final u = AuthUser(uid: c.uid, email: email);
    entrarComo(u);
    return u;
  }

  @override
  Future<AuthUser> createUser(String email, String senha) async {
    if (contas.containsKey(email)) {
      throw const ErroAmigavel('Este e-mail já está cadastrado no sistema.', codigo: 'email-already-in-use');
    }
    final uid = 'uid-${++_seq}';
    registrarConta(email, senha, uid);
    final u = AuthUser(uid: uid, email: email);
    entrarComo(u);
    return u;
  }

  @override
  Future<void> deleteCurrentUser() async {
    contas.removeWhere((_, c) => c.uid == _atual?.uid);
    entrarComo(null);
  }

  @override
  Future<void> signOut() async => entrarComo(null);

  @override
  Future<void> atualizarSenha(String senhaAtual, String novaSenha) async {
    final email = _atual?.email;
    final c = email == null ? null : contas[email];
    if (c == null || c.senha != senhaAtual) {
      throw const ErroAmigavel('E-mail ou senha incorretos.', codigo: 'invalid-credential');
    }
    contas[email!] = (senha: novaSenha, uid: c.uid);
  }

  @override
  Future<ContaAuthCriada> criarContaSecundaria(String email, String senha) async {
    if (contas.containsKey(email)) {
      throw const ErroAmigavel('Este e-mail já está cadastrado no sistema.', codigo: 'email-already-in-use');
    }
    final uid = 'uid-sec-${++_seq}';
    registrarConta(email, senha, uid);
    contasSecundariasCriadas.add(email);
    return ContaAuthCriada(uid: uid, desfazer: () async => contas.remove(email), finalizar: () async {});
  }
}

class FakeUsersRepository implements UsersRepository {
  final _c = _Colecao<UserProfile>();
  final Map<String, StreamController<UserProfile?>> _perfis = {};

  Map<String, UserProfile> get itens => _c.itens;

  void seed(List<UserProfile> users) {
    for (final u in users) {
      _c.itens[u.uid] = u;
    }
    _c.emitir();
  }

  void _mudou(String uid) {
    _c.emitir();
    _perfis[uid]?.add(_c.itens[uid]);
  }

  @override
  Future<UserProfile?> getProfile(String uid) async => _c.itens[uid];

  @override
  Future<void> setProfile(UserProfile profile) async {
    _c.itens[profile.uid] = profile;
    _mudou(profile.uid);
  }

  @override
  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    final atual = _c.itens[uid];
    if (atual == null) throw StateError('not-found: users/$uid');
    _c.itens[uid] = UserProfile.fromMap(uid, {...atual.toMap(), ...data});
    _mudou(uid);
  }

  @override
  Future<void> updateRole(String uid, UserRole perfil) => updateProfile(uid, {'perfil': perfil.name, 'atualizadoEm': agoraIso()});

  @override
  Future<void> updateStatus(String uid, bool ativo) => updateProfile(uid, {'ativo': ativo, 'atualizadoEm': agoraIso()});

  @override
  Future<void> deleteProfile(String uid) async {
    _c.itens.remove(uid);
    _mudou(uid);
  }

  @override
  Future<List<UserProfile>> listarAdministradoresAtivos() async =>
      _c.itens.values.where((u) => u.perfil == 'admin' && u.ativo).toList();

  @override
  Stream<List<UserProfile>> watchAll() => _c.watch();

  @override
  Stream<UserProfile?> watchProfile(String uid) async* {
    final ctrl = _perfis.putIfAbsent(uid, () => StreamController<UserProfile?>.broadcast());
    yield _c.itens[uid];
    yield* ctrl.stream;
  }
}

class FakeAuditLogRepository implements AuditLogRepository {
  final List<AuditLogInput> registros = [];
  final _ctrl = StreamController<List<AuditLog>>.broadcast();
  int _seq = 0;

  AuditLog _paraLog(int i, AuditLogInput e) => AuditLog.fromMap('log-$i', e.toMap(), dataHora: agoraIso());

  List<AuditLog> get logs => [for (var i = registros.length - 1; i >= 0; i--) _paraLog(i, registros[i])];

  @override
  Future<String> registrarLog(AuditLogInput input) async {
    registros.add(input);
    _ctrl.add(logs);
    return 'log-${_seq++}';
  }

  @override
  Stream<List<AuditLog>> watchLogs({int max = 100}) async* {
    yield logs.take(max).toList();
    yield* _ctrl.stream.map((l) => l.take(max).toList());
  }

  bool _casa(AuditLog l, FiltrosAuditoria f) {
    if (f.acao != null && l.acao != f.acao) return false;
    if (f.acao == null && f.categoria != null && !acoesPorCategoria[f.categoria]!.contains(l.acao)) return false;
    if (f.usuarioUid != null && l.usuarioUid != f.usuarioUid) return false;
    if (f.tipoEntidade != null && l.tipoEntidade != f.tipoEntidade) return false;
    if (f.somenteFalhas && l.resultado == AuditLogResultado.sucesso) return false;
    if (f.de != null && l.dataHora.compareTo(f.de!) < 0) return false;
    if (f.ate != null && l.dataHora.compareTo(f.ate!) > 0) return false;
    return true;
  }

  @override
  Future<PaginaAuditoria> listarPagina(FiltrosAuditoria filtros, int tamanho, {Object? apos}) async {
    final todos = logs.where((l) => _casa(l, filtros)).toList();
    final inicio = apos is int ? apos : 0;
    final pagina = todos.skip(inicio).take(tamanho).toList();
    final fim = inicio + pagina.length;
    return PaginaAuditoria(logs: pagina, cursor: fim, temMais: fim < todos.length);
  }

  @override
  Future<int> contar(FiltrosAuditoria filtros) async => logs.where((l) => _casa(l, filtros)).length;
}

class FakeNotificationsRepository implements NotificationsRepository {
  final _c = _Colecao<Notificacao>();
  Map<String, Notificacao> get itens => _c.itens;

  @override
  Future<void> criar(Notificacao n) async {
    _c.itens[n.id] = n;
    _c.emitir();
  }

  Notificacao _com(Notificacao n, {bool? lida, bool? resolvida}) => Notificacao.fromMap(n.id, {
        ...n.toMap(),
        'lida': lida ?? n.lida,
        'resolvida': resolvida ?? n.resolvida,
      });

  @override
  Future<void> marcarLida(String id, bool lida) async {
    final n = _c.itens[id];
    if (n == null) throw StateError('not-found: notifications/$id');
    _c.itens[id] = _com(n, lida: lida);
    _c.emitir();
  }

  @override
  Future<void> marcarResolvida(String id, bool resolvida) async {
    final n = _c.itens[id];
    if (n == null) throw StateError('not-found: notifications/$id');
    _c.itens[id] = _com(n, resolvida: resolvida);
    _c.emitir();
  }

  @override
  Stream<List<Notificacao>> watchParaUsuario(String uid) =>
      _c.watch().map((l) => l.where((n) => n.destinatarioUid == uid).toList()..sort((a, b) => b.dataHora.compareTo(a.dataHora)));
}

class FakeSolicitacoesCargoRepository implements SolicitacoesCargoRepository {
  final _c = _Colecao<SolicitacaoCargo>();
  final Map<String, String> travas = {};
  final FakeUsersRepository users;
  FakeSolicitacoesCargoRepository(this.users);

  Map<String, SolicitacaoCargo> get itens => _c.itens;

  @override
  Future<SolicitacaoCargo?> obter(String id) async => _c.itens[id];

  @override
  Future<SolicitacaoCargo?> obterPendenteDoUsuario(String uid) async {
    final id = travas[uid];
    final s = id == null ? null : _c.itens[id];
    return s != null && s.status == SolicitacaoCargoStatus.pendente ? s : null;
  }

  @override
  Future<void> criar(SolicitacaoCargo s) async {
    _c.itens[s.id] = s;
    travas[s.usuarioUid] = s.id;
    _c.emitir();
  }

  @override
  Future<void> decidir(SolicitacaoCargo s, DecisaoSolicitacaoCargo decisao) async {
    _c.itens[s.id] = SolicitacaoCargo.fromMap(s.id, {...s.toMap(), ...decisao.toMap()});
    if (decisao.status == SolicitacaoCargoStatus.aprovada) {
      await users.updateProfile(s.usuarioUid, {'perfil': s.perfilSolicitado.name, 'atualizadoEm': decisao.dataDecisao});
    }
    travas.remove(s.usuarioUid);
    _c.emitir();
  }

  @override
  Stream<List<SolicitacaoCargo>> watchTodas() => _c.watch();

  @override
  Stream<List<SolicitacaoCargo>> watchDoUsuario(String uid) =>
      _c.watch().map((l) => l.where((s) => s.usuarioUid == uid).toList());
}

class FakeClassificacoesRepository implements ClassificacoesRepository {
  final Map<TipoClassificacao, _Colecao<Classificacao>> _cols = {
    for (final t in TipoClassificacao.values) t: _Colecao<Classificacao>(),
  };
  int _seq = 0;

  Map<String, Classificacao> itens(TipoClassificacao t) => _cols[t]!.itens;

  void seed(TipoClassificacao tipo, List<Classificacao> lista) {
    for (final c in lista) {
      _cols[tipo]!.itens[c.id] = c;
    }
    _cols[tipo]!.emitir();
  }

  @override
  Stream<List<Classificacao>> watchAll(TipoClassificacao tipo) =>
      _cols[tipo]!.watch().map((l) => l..sort((a, b) => compararNomes(a.nome, b.nome)));

  @override
  Future<String> add(TipoClassificacao tipo, {required String nome, bool ativo = true}) async {
    final id = '${tipo.name}-${++_seq}';
    _cols[tipo]!.itens[id] = Classificacao(id: id, nome: nome, ativo: ativo);
    _cols[tipo]!.emitir();
    return id;
  }

  @override
  Future<void> update(TipoClassificacao tipo, String id, Map<String, dynamic> data) async {
    final atual = _cols[tipo]!.itens[id];
    if (atual == null) throw StateError('not-found: ${tipo.colecao}/$id');
    _cols[tipo]!.itens[id] = Classificacao.fromMap(id, {...atual.toMap(), ...data});
    _cols[tipo]!.emitir();
  }

  @override
  Future<void> delete(TipoClassificacao tipo, String id) async {
    _cols[tipo]!.itens.remove(id);
    _cols[tipo]!.emitir();
  }
}

class FakeReutilizacoesRepository implements ReutilizacoesRepository {
  final _c = _Colecao<Reutilizacao>();
  int _seq = 0;
  Map<String, Reutilizacao> get itens => _c.itens;

  void seed(List<Reutilizacao> lista) {
    for (final r in lista) {
      _c.itens[r.id] = r;
    }
    _c.emitir();
  }

  @override
  Stream<List<Reutilizacao>> watchAll() => _c.watch();

  @override
  Future<String> add(Map<String, dynamic> data) async {
    final id = 'reu-${++_seq}';
    _c.itens[id] = Reutilizacao.fromMap(id, {...data, 'id': id, 'dataCriacao': agoraIso()});
    _c.emitir();
    return id;
  }

  @override
  Future<void> update(String id, Map<String, dynamic> data) async {
    final atual = _c.itens[id];
    if (atual == null) throw StateError('not-found: reutilizacoes/$id');
    _c.itens[id] = Reutilizacao.fromMap(id, {...atual.toMap(), ...data});
    _c.emitir();
  }

  @override
  Future<void> delete(String id) async {
    _c.itens.remove(id);
    _c.emitir();
  }
}

class FakeDispositivosRepository implements DispositivosRepository {
  final _c = _Colecao<Dispositivo>();
  int _seq = 0;
  Map<String, Dispositivo> get itens => _c.itens;
  final List<String> pastasExcluidas = [];

  void seed(List<Dispositivo> lista) {
    for (final d in lista) {
      _c.itens[d.id] = d;
    }
    _c.emitir();
  }

  @override
  Stream<List<Dispositivo>> watchAll() => _c.watch();

  @override
  Future<String> add(Map<String, dynamic> data, {String? id}) async {
    final novoId = id ?? (data['id'] as String?) ?? 'disp-${++_seq}';
    _c.itens[novoId] = Dispositivo.fromMap(novoId, {...data, 'id': novoId, 'dataCriacao': agoraIso()});
    _c.emitir();
    return novoId;
  }

  @override
  Future<void> update(String id, Map<String, dynamic> data) async {
    final atual = _c.itens[id];
    if (atual == null) throw StateError('not-found: dispositivos/$id');
    _c.itens[id] = Dispositivo.fromMap(id, {...atual.toMap(), ...data});
    _c.emitir();
  }

  @override
  Future<void> delete(String id) async {
    _c.itens.remove(id);
    pastasExcluidas.add('retool/dispositivos/$id');
    _c.emitir();
  }

  List<Map<String, dynamic>>? ultimoLote;

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
    ultimoLote = novosDispositivos;
    var inseridos = 0, atualizados = 0;
    for (final d in novosDispositivos) {
      final chave = chaveCodigoDispositivo(d['codigo'], d['nome']);
      final existente = _c.itens.values.where((x) => chaveCodigoDispositivo(x.codigo, x.nome) == chave).firstOrNull;
      if (existente != null) {
        _c.itens[existente.id] = Dispositivo.fromMap(existente.id, {...existente.toMap(), ...d});
        atualizados++;
      } else {
        final id = 'disp-${++_seq}';
        _c.itens[id] = Dispositivo.fromMap(id, {...d, 'id': id});
        inseridos++;
      }
    }
    _c.emitir();
    return ResultadoImportacaoLote(
        sucesso: inseridos + atualizados, erros: 0, inseridos: inseridos, atualizados: atualizados);
  }

  @override
  Future<ResultadoExclusaoLote> excluirEmLote(List<String> ids) async {
    for (final id in ids) {
      _c.itens.remove(id);
    }
    _c.emitir();
    return ResultadoExclusaoLote(excluidos: ids.length, erros: 0);
  }
}

class FakeStorageService implements StorageService {
  final List<FileAttachment> enviados = [];
  final List<String> excluidos = [];

  @override
  Future<FileAttachment> uploadFile({
    required String baseStoragePath,
    required Uint8List bytes,
    required String nomeOriginal,
    required String contentType,
    required CategoriaAnexo categoria,
    void Function(int progresso)? onProgress,
  }) async {
    final erro = validarArquivo(contentType: contentType, size: bytes.length, categoria: categoria);
    if (erro != null) throw ErroValidacao(erro);
    onProgress?.call(50);
    onProgress?.call(100);
    final id = 'file-${enviados.length + 1}';
    final path = '$baseStoragePath/${categoria.valor}/${id}_${sanitizeFileName(nomeOriginal)}';
    final a = FileAttachment(
      id: id,
      originalName: nomeOriginal,
      fileName: '${id}_${sanitizeFileName(nomeOriginal)}',
      contentType: contentType,
      size: bytes.length,
      storagePath: path,
      downloadURL: 'https://fake.storage/$path',
      uploadedAt: agoraIso(),
      categoria: categoria,
    );
    enviados.add(a);
    return a;
  }

  @override
  Future<void> deleteFile(String storagePath) async => excluidos.add(storagePath);

  @override
  Future<void> deleteFolder(String folderPath) async => excluidos.add(folderPath);
}

class FakeContasService implements ContasService {
  final List<String> redefinidas = [];
  @override
  Future<String> redefinirSenhaTemporaria(String uid) async {
    redefinidas.add(uid);
    return 'Tmp-Senha-123!';
  }
}

/// Conjunto de fakes interligados + [AppDependencies] pronto para injetar.
class FakeBackend {
  final auth = FakeAuthGateway();
  final users = FakeUsersRepository();
  final audit = FakeAuditLogRepository();
  final notifications = FakeNotificationsRepository();
  late final solicitacoesCargo = FakeSolicitacoesCargoRepository(users);
  final dispositivos = FakeDispositivosRepository();
  final classificacoes = FakeClassificacoesRepository();
  final reutilizacoes = FakeReutilizacoesRepository();
  final storage = FakeStorageService();
  final contas = FakeContasService();

  late final AppDependencies deps = AppDependencies(
    auth: auth,
    users: users,
    audit: audit,
    notifications: notifications,
    solicitacoesCargo: solicitacoesCargo,
    dispositivos: dispositivos,
    classificacoes: classificacoes,
    reutilizacoes: reutilizacoes,
    storage: storage,
    contas: contas,
    traduzirErro: mensagemDoErro,
    urlFormularioBugs: 'https://example.com/bugs',
  );

  /// Cria um usuário ativo com o cargo e (opcional) já autentica a sessão.
  UserProfile criarUsuario(
    String uid, {
    String perfil = 'admin',
    String? nome,
    String? email,
    String senha = 'senha123',
    bool ativo = true,
    StatusAprovacao? status = StatusAprovacao.aprovado,
    bool trocaSenha = false,
    bool logar = false,
  }) {
    final u = UserProfile(
      uid: uid,
      email: email ?? '$uid@baldan.com.br',
      nome: nome ?? 'Usuário $uid',
      perfil: perfil,
      ativo: ativo,
      statusAprovacao: status,
      trocaSenhaObrigatoria: trocaSenha,
      criadoEm: '2026-01-10T12:00:00.000Z',
    );
    users.seed([u]);
    auth.registrarConta(u.email, senha, uid);
    if (logar) auth.entrarComo(AuthUser(uid: uid, email: u.email, displayName: u.nome));
    return u;
  }

  /// Dados de exemplo: 3 dispositivos, classificações e 2 reutilizações.
  void semearDadosFabris() {
    classificacoes.seed(TipoClassificacao.categoria, const [
      Classificacao(id: 'cat-1', nome: 'Gabaritos'),
      Classificacao(id: 'cat-2', nome: 'Ferramentas de Corte'),
    ]);
    classificacoes.seed(TipoClassificacao.familia, const [
      Classificacao(id: 'fam-1', nome: 'Preparo de Solo'),
      Classificacao(id: 'fam-2', nome: 'Colheita', ativo: false),
    ]);
    classificacoes.seed(TipoClassificacao.produto, const [
      Classificacao(id: 'prod-1', nome: 'SPE 5500'),
      Classificacao(id: 'prod-2', nome: 'AVOLA 2500'),
    ]);
    dispositivos.seed(const [
      Dispositivo(
        id: 'd1',
        nome: 'Gabarito de Furação Lateral',
        codigo: 'GAB-0042',
        categoriaId: 'cat-1',
        familiaId: 'fam-1',
        produtoId: 'prod-1',
        peso: '14.5',
        descricao: 'Dispositivo para furação em chapa 3/8',
        palavrasChave: ['gabarito', 'furacao'],
        dataCriacao: '2026-01-01T10:00:00.000Z',
      ),
      Dispositivo(
        id: 'd2',
        nome: 'Válvula de Alívio',
        codigo: 'VAL-0007',
        categoriaId: 'cat-2',
        produtoId: 'prod-2',
        dataCriacao: '2026-01-02T10:00:00.000Z',
      ),
      Dispositivo(id: 'd3', nome: 'Suporte Inativo', codigo: 'SUP-1', ativo: false, dataCriacao: '2026-01-03T10:00:00.000Z'),
    ]);
    reutilizacoes.seed(const [
      Reutilizacao(
        id: 'r1',
        dispositivoId: 'd1',
        data: '2026-02-10',
        codigoPeca: 'PC-5501',
        descricaoPeca: 'Suporte Direito',
        produtoId: 'prod-1',
        pesoPeca: 2.15,
        hardSaving: 18500,
        responsavel: 'Luiz Ramos',
        numeroOs: 'OS-1',
        descricaoAlteracao: 'Usinagem de 2 furos',
        status: ReutilizacaoStatus.emAnaliseProjetista,
        solicitanteId: 'eng1',
        solicitanteNome: 'Engenheiro',
        dataCriacao: '2026-02-10T10:00:00.000Z',
      ),
      Reutilizacao(
        id: 'r2',
        dispositivoId: 'd1',
        data: '2026-01-15',
        codigoPeca: 'PC-1000',
        descricaoPeca: 'Base',
        hardSaving: 1000,
        descricaoAlteracao: 'Ajuste',
        status: ReutilizacaoStatus.aprovada,
        dataCriacao: '2026-01-15T10:00:00.000Z',
      ),
    ]);
  }
}
