import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../application/usecases/acessos_comum.dart';
import '../../application/usecases/acessos_usecases.dart';
import '../../core/config/app_dependencies.dart';
import '../../domain/entities/audit_log.dart';
import '../../domain/entities/notificacao.dart';
import '../../domain/entities/solicitacao_cargo.dart';
import '../../domain/entities/user.dart';
import '../../domain/errors.dart';
import '../../domain/repositories/repositories.dart';

enum EstadoSincronizacao { carregando, pronto, erro }

/// Sessão, RBAC, usuários, solicitações de cargo e notificações
/// (equivalente ao `AuthContext` do desktop).
class AuthController extends ChangeNotifier {
  final AppDependencies deps;

  AuthController(this.deps)
      : _solicitarCadastro = SolicitarCadastroUseCase(deps.users, deps.audit, deps.notifications),
        _decidirCadastro = DecidirCadastroUseCase(deps.users, deps.audit, deps.notifications),
        _concluirTrocaSenha = ConcluirTrocaSenhaUseCase(deps.users, deps.audit, deps.auth.atualizarSenha),
        _solicitarCargo =
            SolicitarAlteracaoCargoUseCase(deps.solicitacoesCargo, deps.users, deps.audit, deps.notifications),
        _decidirCargo = DecidirSolicitacaoCargoUseCase(deps.solicitacoesCargo, deps.users, deps.audit, deps.notifications) {
    _criarConta = CriarContaAdministrativaUseCase(deps.users, deps.audit, deps.auth.criarContaSecundaria);
    _authSub = deps.auth.authStateChanges().listen(_aoMudarAutenticacao);
  }

  final SolicitarCadastroUseCase _solicitarCadastro;
  final DecidirCadastroUseCase _decidirCadastro;
  late final CriarContaAdministrativaUseCase _criarConta;
  final ConcluirTrocaSenhaUseCase _concluirTrocaSenha;
  final SolicitarAlteracaoCargoUseCase _solicitarCargo;
  final DecidirSolicitacaoCargoUseCase _decidirCargo;

  StreamSubscription? _authSub;
  StreamSubscription? _perfilSub;
  StreamSubscription? _usersSub;
  StreamSubscription? _cargoSub;
  StreamSubscription? _notifSub;

  UserProfile? _userProfile;
  bool _loading = true;
  List<UserProfile> _users = const [];
  EstadoSincronizacao _estadoUsuarios = EstadoSincronizacao.carregando;
  List<SolicitacaoCargo> _solicitacoesCargo = const [];
  EstadoSincronizacao _estadoSolicitacoesCargo = EstadoSincronizacao.carregando;
  List<Notificacao> _notifications = const [];

  // register()/login() conduzem a própria sessão; o listener não interfere.
  bool _registrando = false;
  bool _loginEmAndamento = false;
  bool _disposed = false;

  UserProfile? get userProfile => _userProfile;
  bool get loading => _loading;
  List<UserProfile> get users => _users;
  EstadoSincronizacao get estadoUsuarios => _estadoUsuarios;
  List<SolicitacaoCargo> get solicitacoesCargo => _solicitacoesCargo;
  EstadoSincronizacao get estadoSolicitacoesCargo => _estadoSolicitacoesCargo;
  List<Notificacao> get notifications => _notifications;
  int get notificacoesNaoLidas => _notifications.where((n) => !n.lida).length;

  /// Conta ativa, aprovada e sem troca de senha pendente.
  bool get isOperacional => isContaOperacional(_userProfile);
  bool get isAdmin => isAdministrador(_userProfile);
  TelaDaSessao get tela => telaDaSessao(_userProfile);

  /// Perfil efetivo: sem conta operacional, menor privilégio (Convidado).
  PerfilUsuario get currentRole => isOperacional ? _userProfile!.perfil : perfilConvidado;
  RoleConfig get roleConfig => configDoPerfil(currentRole);

  bool get canConsultar => roleConfig.canConsultar;
  bool get canCadastrar => roleConfig.canCadastrar;
  bool get canEditar => roleConfig.canEditar;
  bool get canExcluir => roleConfig.canExcluir;
  bool get canAprovar => roleConfig.canAprovar;
  bool get canSolicitar => roleConfig.canSolicitar;
  bool get canGerenciarUsuarios => roleConfig.canGerenciarUsuarios;
  bool get canVerLogs => roleConfig.canVerLogs;

  /// Pendências administrativas (cadastros + solicitações de cargo) exibidas no menu.
  int get pendenciasAdmin => canGerenciarUsuarios
      ? _users.where((u) => situacaoDoUsuario(u) == SituacaoUsuario.pendente).length +
          _solicitacoesCargo.where((s) => s.status == SolicitacaoCargoStatus.pendente).length
      : 0;

  void _notificar() {
    if (!_disposed) notifyListeners();
  }

  void _setPerfil(UserProfile? p) {
    final eraOperacional = isOperacional;
    final uidAnterior = _userProfile?.uid;
    final eraAdmin = isAdmin;
    _userProfile = p;
    if (eraOperacional != isOperacional || uidAnterior != p?.uid || eraAdmin != isAdmin) {
      _reassinarColecoes();
    }
    _notificar();
  }

  void _reassinarColecoes() {
    _usersSub?.cancel();
    _cargoSub?.cancel();
    _notifSub?.cancel();
    _usersSub = _cargoSub = _notifSub = null;

    final perfil = _userProfile;
    if (perfil != null) {
      _notifSub = deps.notifications.watchParaUsuario(perfil.uid).listen((l) {
        _notifications = l;
        _notificar();
      }, onError: (_) {
        _notifications = const [];
        _notificar();
      });
    } else {
      _notifications = const [];
    }

    if (!isOperacional) {
      _users = const [];
      _solicitacoesCargo = const [];
      _estadoUsuarios = EstadoSincronizacao.carregando;
      _estadoSolicitacoesCargo = EstadoSincronizacao.carregando;
      return;
    }

    // Lista de usuários: apenas contas operacionais (convidados não enxergam colegas).
    _estadoUsuarios = EstadoSincronizacao.carregando;
    _usersSub = deps.users.watchAll().listen((l) {
      _users = l;
      _estadoUsuarios = EstadoSincronizacao.pronto;
      _notificar();
    }, onError: (_) {
      _users = const [];
      _estadoUsuarios = EstadoSincronizacao.erro;
      _notificar();
    });

    // Solicitações de cargo: Administração vê todas; os demais, só as próprias.
    _estadoSolicitacoesCargo = EstadoSincronizacao.carregando;
    final stream = isAdmin ? deps.solicitacoesCargo.watchTodas() : deps.solicitacoesCargo.watchDoUsuario(perfil!.uid);
    _cargoSub = stream.listen((l) {
      _solicitacoesCargo = l;
      _estadoSolicitacoesCargo = EstadoSincronizacao.pronto;
      _notificar();
    }, onError: (_) {
      _solicitacoesCargo = const [];
      _estadoSolicitacoesCargo = EstadoSincronizacao.erro;
      _notificar();
    });
  }

  void _encerrarAssinaturaPerfil() {
    _perfilSub?.cancel();
    _perfilSub = null;
  }

  /// Perfil em tempo real: aprovação, troca de cargo, bloqueio ou exclusão refletem na hora.
  void _acompanharPerfil(String uid) {
    _encerrarAssinaturaPerfil();
    _perfilSub = deps.users.watchProfile(uid).listen((atualizado) {
      if (!podeManterSessao(atualizado)) {
        _encerrarAssinaturaPerfil();
        deps.auth.signOut().catchError((_) {});
        _setPerfil(null);
        return;
      }
      _setPerfil(atualizado);
    }, onError: (e) => debugPrint('Falha ao acompanhar o perfil do usuário: $e'));
  }

  Future<void> _aoMudarAutenticacao(AuthUser? fbUser) async {
    _encerrarAssinaturaPerfil();
    if (fbUser == null) {
      _loading = false;
      _setPerfil(null);
      return;
    }
    if (_registrando) return;

    _loading = true;
    _notificar();
    try {
      var profile = await deps.users.getProfile(fbUser.uid);
      // Autenticado sem perfil (conta criada fora do app ou cadastro interrompido):
      // entra como Convidado aguardando aprovação.
      profile ??= await _solicitarCadastro.execute(
        uid: fbUser.uid,
        email: fbUser.email ?? '',
        nome: fbUser.displayName ?? (fbUser.email?.split('@').first ?? 'Usuário'),
      );
      if (!podeManterSessao(profile)) {
        // Bloqueado/recusado: login() exibe o motivo e encerra a sessão.
        if (!_loginEmAndamento) await deps.auth.signOut();
        _loading = false;
        _setPerfil(null);
        return;
      }
      _loading = false;
      _setPerfil(profile);
      _acompanharPerfil(profile.uid);
    } catch (e) {
      debugPrint('Erro ao sincronizar perfil do usuário: $e');
      await deps.auth.signOut().catchError((_) {});
      _loading = false;
      _setPerfil(null);
    }
  }

  /// Lança [ErroAmigavel] com a mensagem pronta para a tela.
  Future<void> login(String email, String senha) async {
    final normalizado = email.trim().toLowerCase();
    _loginEmAndamento = true;
    try {
      final AuthUser cred;
      try {
        cred = await deps.auth.signIn(normalizado, senha);
      } catch (e) {
        throw ErroAmigavel(deps.traduzirErro(e));
      }
      UserProfile? profile;
      try {
        profile = await deps.users.getProfile(cred.uid);
      } catch (_) {}

      if (profile != null && !podeManterSessao(profile)) {
        await registrarAuditoriaSemFalhar(
            deps.audit,
            logDe(profile,
                acao: AuditLogAcao.login,
                resultado: AuditLogResultado.negado,
                acaoDescricao: situacaoDoUsuario(profile) == SituacaoUsuario.rejeitado
                    ? 'Acesso recusado: cadastro rejeitado pela Administração'
                    : 'Acesso recusado: conta bloqueada',
                tipoEntidade: AuditLogTipoEntidade.sessao,
                entidadeId: profile.uid,
                entidadeNome: profile.nome));
        await deps.auth.signOut();
        throw ErroAmigavel(mensagemAcessoNegado(profile));
      }

      final situacao = profile != null ? situacaoDoUsuario(profile) : SituacaoUsuario.pendente;
      await registrarAuditoriaSemFalhar(
          deps.audit,
          AuditLogInput(
            usuarioUid: cred.uid,
            usuarioNome: profile?.nome ?? normalizado,
            usuarioEmail: normalizado,
            usuarioPerfil: profile?.perfil ?? perfilConvidado,
            acao: AuditLogAcao.login,
            acaoDescricao: (profile?.trocaSenhaObrigatoria ?? false)
                ? 'Entrou com senha temporária (troca obrigatória pendente)'
                : situacao == SituacaoUsuario.pendente
                    ? 'Entrou como Convidado (cadastro aguardando aprovação)'
                    : 'Entrou no sistema',
            tipoEntidade: AuditLogTipoEntidade.sessao,
            entidadeId: cred.uid,
            entidadeNome: profile?.nome ?? normalizado,
            conteudo: {'situacao': situacao.name, 'trocaSenhaObrigatoria': profile?.trocaSenhaObrigatoria ?? false},
          ));
    } finally {
      _loginEmAndamento = false;
    }
  }

  /// Autocadastro: sempre Convidado aguardando aprovação (sem escolha de cargo).
  Future<void> register(String email, String senha, String nome) async {
    final normalizado = email.trim().toLowerCase();
    if (nome.trim().isEmpty) throw const ErroValidacao('Por favor, informe seu nome completo.');
    _registrando = true;
    var criado = false;
    try {
      final u = await deps.auth.createUser(normalizado, senha);
      criado = true;
      final profile = await _solicitarCadastro.execute(uid: u.uid, email: normalizado, nome: nome);
      // A sessão continua aberta como Convidado: o app mostra "aguardando aprovação".
      _loading = false;
      _setPerfil(profile);
      _acompanharPerfil(u.uid);
    } catch (e) {
      // Cadastro incompleto não deixa conta de autenticação órfã.
      if (criado) {
        await deps.auth.deleteCurrentUser().catchError((_) => deps.auth.signOut().catchError((_) {}));
      }
      if (e is ErroValidacao || e is ErroAmigavel) rethrow;
      throw ErroAmigavel(deps.traduzirErro(e));
    } finally {
      _registrando = false;
      _loading = false;
      _notificar();
    }
  }

  Future<void> logout() async {
    final perfil = _userProfile;
    if (perfil != null) {
      await registrarAuditoriaSemFalhar(
          deps.audit,
          logDe(perfil,
              acao: AuditLogAcao.logout,
              acaoDescricao: 'Saiu do sistema',
              tipoEntidade: AuditLogTipoEntidade.sessao,
              entidadeId: perfil.uid,
              entidadeNome: perfil.nome));
    }
    _encerrarAssinaturaPerfil();
    try {
      await deps.auth.signOut();
    } catch (e) {
      debugPrint('Erro ao deslogar: $e');
    }
    _setPerfil(null);
  }

  void _exigirAdministracao() {
    if (!isAdmin) throw const ErroPermissao();
  }

  Future<void> decidirCadastro(String uid, bool aprovar, {UserRole? perfil, String? motivo}) =>
      _decidirCadastro.execute(admin: _userProfile, alvoUid: uid, aprovar: aprovar, perfil: perfil, motivo: motivo);

  /// Exclusivo da Administração: cria a conta com senha temporária (retornada uma única vez).
  Future<ContaCriada> criarContaComSenhaTemporaria(String nome, String email, UserRole? perfil) async {
    try {
      return await _criarConta.execute(admin: _userProfile, nome: nome, email: email, perfil: perfil);
    } catch (e) {
      if (e is ErroValidacao || e is ErroPermissao) rethrow;
      throw ErroAmigavel(deps.traduzirErro(e));
    }
  }

  Future<void> concluirTrocaSenha(String senhaAtual, String novaSenha, String confirmacao) async {
    final perfil = _userProfile;
    if (perfil == null) throw const ErroAmigavel('Sua sessão expirou. Entre novamente.');
    await _concluirTrocaSenha.execute(
        usuario: perfil, senhaAtual: senhaAtual, novaSenha: novaSenha, confirmacao: confirmacao);
    _setPerfil(perfil.copyWith(trocaSenhaObrigatoria: false));
  }

  /// Exclusivo da Administração (Cloud Function): nova senha temporária, devolvida uma única vez.
  Future<String> redefinirSenhaTemporaria(String uid) async {
    _exigirAdministracao();
    if (uid == _userProfile!.uid) throw const ErroPermissao('A própria senha não é redefinida por aqui.');
    try {
      return await deps.contas.redefinirSenhaTemporaria(uid);
    } catch (e) {
      throw ErroAmigavel(deps.traduzirErro(e));
    }
  }

  Future<void> solicitarAlteracaoCargo(UserRole perfil, {String? justificativa}) =>
      _solicitarCargo.execute(usuario: _userProfile, perfilSolicitado: perfil, justificativa: justificativa);

  Future<void> decidirSolicitacaoCargo(String id, bool aprovar, {String? motivo}) =>
      _decidirCargo.execute(admin: _userProfile, solicitacaoId: id, aprovar: aprovar, motivo: motivo);

  Future<void> _registrarAcaoAdministrativa({
    required AuditLogAcao acao,
    required String acaoDescricao,
    required String entidadeId,
    required String entidadeNome,
    String? detalhes,
    Map<String, dynamic>? conteudo,
    Map<String, dynamic>? dadosAnteriores,
  }) =>
      registrarAuditoriaSemFalhar(
          deps.audit,
          logDe(_userProfile!,
              acao: acao,
              acaoDescricao: acaoDescricao,
              tipoEntidade: AuditLogTipoEntidade.usuario,
              entidadeId: entidadeId,
              entidadeNome: entidadeNome,
              detalhes: detalhes,
              conteudo: conteudo,
              dadosAnteriores: dadosAnteriores));

  UserProfile? _usuario(String uid) => _users.where((u) => u.uid == uid).firstOrNull;

  Future<void> updateUserRole(String uid, UserRole perfil) async {
    _exigirAdministracao();
    if (uid == _userProfile!.uid) throw const ErroPermissao('A Administração não altera o próprio cargo.');
    final alvo = _usuario(uid);
    final nome = alvo?.nome ?? uid;
    await deps.users.updateRole(uid, perfil);
    await _registrarAcaoAdministrativa(
      acao: AuditLogAcao.alteracaoPerfil,
      acaoDescricao: 'Alterou o cargo de $nome para ${rolesConfig[perfil]!.titulo}',
      entidadeId: uid,
      entidadeNome: nome,
      detalhes: 'Perfil de $nome alterado para ${rolesConfig[perfil]!.titulo}',
      conteudo: {'perfilNovo': perfil.name},
      dadosAnteriores: alvo != null ? {'perfil': alvo.perfil} : null,
    );
  }

  Future<void> toggleUserStatus(String uid, bool ativo) async {
    _exigirAdministracao();
    if (uid == _userProfile!.uid) throw const ErroPermissao('A Administração não bloqueia a própria conta.');
    final alvo = _usuario(uid);
    if (alvo != null && situacaoDoUsuario(alvo) == SituacaoUsuario.pendente) {
      throw const ErroValidacao('Cadastros pendentes são liberados pela aprovação, com definição de cargo.');
    }
    final nome = alvo?.nome ?? uid;
    await deps.users.updateStatus(uid, ativo);
    await _registrarAcaoAdministrativa(
      acao: ativo ? AuditLogAcao.desbloqueioUsuario : AuditLogAcao.bloqueioUsuario,
      acaoDescricao: ativo ? 'Desbloqueou $nome' : 'Bloqueou $nome',
      entidadeId: uid,
      entidadeNome: nome,
      detalhes: ativo ? 'Usuário desbloqueado' : 'Usuário bloqueado no sistema',
      dadosAnteriores: alvo != null ? {'ativo': alvo.ativo} : null,
    );
  }

  Future<void> deleteUser(String uid) async {
    _exigirAdministracao();
    if (uid == _userProfile!.uid) throw const ErroPermissao('A própria conta não pode ser excluída.');
    final alvo = _usuario(uid);
    final nome = alvo?.nome ?? uid;
    await deps.users.deleteProfile(uid);
    await _registrarAcaoAdministrativa(
      acao: AuditLogAcao.exclusao,
      acaoDescricao: 'Excluiu o usuário $nome',
      entidadeId: uid,
      entidadeNome: nome,
      detalhes: 'Exclusão do registro [USUARIO]: $nome',
      dadosAnteriores: alvo != null
          ? {'nome': alvo.nome, 'email': alvo.email, 'perfil': alvo.perfil, 'ativo': alvo.ativo}
          : null,
    );
  }

  Future<void> criarNotificacao(Notificacao n) => deps.notifications.criar(n);
  Future<void> marcarNotificacaoLida(String id, bool lida) => deps.notifications.marcarLida(id, lida);
  Future<void> marcarNotificacaoResolvida(String id, bool resolvida) =>
      deps.notifications.marcarResolvida(id, resolvida);

  Future<void> marcarTodasComoLidas() async {
    for (final n in _notifications.where((n) => !n.lida)) {
      await deps.notifications.marcarLida(n.id, true);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _authSub?.cancel();
    _perfilSub?.cancel();
    _usersSub?.cancel();
    _cargoSub?.cancel();
    _notifSub?.cancel();
    super.dispose();
  }
}
