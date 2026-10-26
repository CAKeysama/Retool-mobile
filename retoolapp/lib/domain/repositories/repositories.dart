import 'dart:typed_data';

import '../entities/audit_log.dart';
import '../entities/classificacao.dart';
import '../entities/dispositivo.dart';
import '../entities/file_attachment.dart';
import '../entities/notificacao.dart';
import '../entities/reutilizacao.dart';
import '../entities/solicitacao_cargo.dart';
import '../entities/user.dart';

/// Contratos da camada de dados. As implementações Firestore ficam em
/// `lib/data/`; os testes usam fakes em memória (`test/support/fakes.dart`).

class AuthUser {
  final String uid;
  final String? email;
  final String? displayName;
  const AuthUser({required this.uid, this.email, this.displayName});
}

/// Conta recém-criada no provedor de autenticação (app secundário).
class ContaAuthCriada {
  final String uid;

  /// Remove a conta de autenticação (rollback se o perfil não puder ser gravado).
  final Future<void> Function() desfazer;

  /// Encerra a sessão efêmera usada na criação.
  final Future<void> Function() finalizar;
  const ContaAuthCriada({required this.uid, required this.desfazer, required this.finalizar});
}

abstract class AuthGateway {
  Stream<AuthUser?> authStateChanges();
  AuthUser? get currentUser;
  Future<AuthUser> signIn(String email, String senha);
  Future<AuthUser> createUser(String email, String senha);
  Future<void> deleteCurrentUser();
  Future<void> signOut();

  /// Reautentica com a senha atual (temporária) e grava a nova.
  Future<void> atualizarSenha(String senhaAtual, String novaSenha);

  /// Cria a conta num app secundário: a sessão da administradora não é substituída.
  Future<ContaAuthCriada> criarContaSecundaria(String email, String senha);
}

abstract class UsersRepository {
  Future<UserProfile?> getProfile(String uid);
  Future<void> setProfile(UserProfile profile);
  Future<void> updateProfile(String uid, Map<String, dynamic> data);
  Future<void> updateRole(String uid, UserRole perfil);
  Future<void> updateStatus(String uid, bool ativo);
  Future<void> deleteProfile(String uid);

  /// Administração ativa — destinatária das notificações de cadastro e cargo.
  Future<List<UserProfile>> listarAdministradoresAtivos();
  Stream<List<UserProfile>> watchAll();

  /// Perfil em tempo real, somente com estado confirmado pelo servidor.
  Stream<UserProfile?> watchProfile(String uid);
}

class FiltrosAuditoria {
  final AuditLogCategoria? categoria;
  final AuditLogAcao? acao;
  final String? usuarioUid;
  final AuditLogTipoEntidade? tipoEntidade;
  final bool somenteFalhas;

  /// Limites do período (ISO, inclusivos).
  final String? de;
  final String? ate;
  const FiltrosAuditoria({
    this.categoria,
    this.acao,
    this.usuarioUid,
    this.tipoEntidade,
    this.somenteFalhas = false,
    this.de,
    this.ate,
  });
}

class PaginaAuditoria {
  final List<AuditLog> logs;

  /// Cursor opaco para a próxima página.
  final Object? cursor;
  final bool temMais;
  const PaginaAuditoria({required this.logs, required this.cursor, required this.temMais});
}

abstract class AuditLogRepository {
  Future<String> registrarLog(AuditLogInput input);
  Stream<List<AuditLog>> watchLogs({int max = 100});
  Future<PaginaAuditoria> listarPagina(FiltrosAuditoria filtros, int tamanho, {Object? apos});
  Future<int> contar(FiltrosAuditoria filtros);
}

abstract class NotificationsRepository {
  /// Criação idempotente (id determinístico).
  Future<void> criar(Notificacao n);
  Future<void> marcarLida(String id, bool lida);
  Future<void> marcarResolvida(String id, bool resolvida);
  Stream<List<Notificacao>> watchParaUsuario(String uid);
}

class DecisaoSolicitacaoCargo {
  final SolicitacaoCargoStatus status;
  final String decididoPorUid;
  final String decididoPorNome;
  final String dataDecisao;
  final String? motivoDecisao;
  const DecisaoSolicitacaoCargo({
    required this.status,
    required this.decididoPorUid,
    required this.decididoPorNome,
    required this.dataDecisao,
    this.motivoDecisao,
  });

  Map<String, dynamic> toMap() => {
        'status': status.name,
        'decididoPorUid': decididoPorUid,
        'decididoPorNome': decididoPorNome,
        'dataDecisao': dataDecisao,
        if (motivoDecisao != null) 'motivoDecisao': motivoDecisao,
      };
}

abstract class SolicitacoesCargoRepository {
  Future<SolicitacaoCargo?> obter(String id);
  Future<SolicitacaoCargo?> obterPendenteDoUsuario(String uid);

  /// Grava a solicitação e a trava de pendência do usuário no mesmo lote atômico.
  Future<void> criar(SolicitacaoCargo s);

  /// Registra a decisão, aplica o novo cargo (se aprovada) e libera a trava.
  Future<void> decidir(SolicitacaoCargo s, DecisaoSolicitacaoCargo decisao);
  Stream<List<SolicitacaoCargo>> watchTodas();
  Stream<List<SolicitacaoCargo>> watchDoUsuario(String uid);
}

class ResultadoImportacaoLote {
  final int sucesso;
  final int erros;
  final int inseridos;
  final int atualizados;
  final List<String> falhas;
  const ResultadoImportacaoLote({
    required this.sucesso,
    required this.erros,
    this.inseridos = 0,
    this.atualizados = 0,
    this.falhas = const [],
  });
}

class ResultadoExclusaoLote {
  final int excluidos;
  final int erros;
  final List<String> falhas;
  const ResultadoExclusaoLote({required this.excluidos, required this.erros, this.falhas = const []});
}

abstract class DispositivosRepository {
  Stream<List<Dispositivo>> watchAll();

  /// Cria o documento (gera id se ausente) com `dataCriacao`; retorna o id.
  Future<String> add(Map<String, dynamic> data, {String? id});
  Future<void> update(String id, Map<String, dynamic> data);

  /// Remove o documento e a pasta `retool/dispositivos/{id}` no Storage.
  Future<void> delete(String id);

  /// Importação em lote: cria classificações novas (sem duplicar por caixa/espaço)
  /// e grava os dispositivos por chave Código + Dispositivo (merge).
  Future<ResultadoImportacaoLote> importarLote({
    required List<Map<String, dynamic>> novosDispositivos,
    required List<String> novasCategorias,
    required List<String> novasFamilias,
    required List<String> novosProdutos,
    required List<Classificacao> categoriasExistentes,
    required List<Classificacao> familiasExistentes,
    required List<Classificacao> produtosExistentes,
  });
  Future<ResultadoExclusaoLote> excluirEmLote(List<String> ids);
}

abstract class ClassificacoesRepository {
  Stream<List<Classificacao>> watchAll(TipoClassificacao tipo);
  Future<String> add(TipoClassificacao tipo, {required String nome, bool ativo = true});
  Future<void> update(TipoClassificacao tipo, String id, Map<String, dynamic> data);
  Future<void> delete(TipoClassificacao tipo, String id);
}

abstract class ReutilizacoesRepository {
  Stream<List<Reutilizacao>> watchAll();

  /// Cria com id gerado e `dataCriacao`; retorna o id.
  Future<String> add(Map<String, dynamic> data);
  Future<void> update(String id, Map<String, dynamic> data);
  Future<void> delete(String id);
}

abstract class StorageService {
  /// Valida, envia com progresso (0–100) e devolve o anexo com `downloadURL`.
  Future<FileAttachment> uploadFile({
    required String baseStoragePath,
    required Uint8List bytes,
    required String nomeOriginal,
    required String contentType,
    required CategoriaAnexo categoria,
    void Function(int progresso)? onProgress,
  });
  Future<void> deleteFile(String storagePath);
  Future<void> deleteFolder(String folderPath);
}

abstract class ContasService {
  /// Gera nova senha temporária para outra conta (Cloud Function); devolvida uma única vez.
  Future<String> redefinirSenhaTemporaria(String uid);
}
