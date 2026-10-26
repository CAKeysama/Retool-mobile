import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../application/usecases/acessos_comum.dart' show agoraIso;
import '../../domain/entities/file_attachment.dart';
import '../../domain/errors.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/services/file_validators.dart';

/// Traduz códigos do Firebase Auth/Functions para mensagens amigáveis (iguais ao desktop).
String traduzirErroAuth(Object err) {
  if (err is ErroAmigavel || err is ErroValidacao || err is ErroPermissao) return mensagemDoErro(err);
  if (err is FirebaseFunctionsException) {
    final generico = (err.message ?? '').isEmpty || RegExp(r'^(internal|not[-_ ]found|unavailable)$', caseSensitive: false).hasMatch((err.message ?? '').trim());
    if (err.code == 'unavailable' || (generico && (err.code == 'internal' || err.code == 'not-found'))) {
      return 'Serviço de redefinição de senha indisponível. Verifique se as Cloud Functions foram publicadas (requer o plano Blaze do Firebase).';
    }
    return err.message ?? 'Erro ao processar a solicitação.';
  }
  final code = err is FirebaseException ? err.code : '';
  switch (code) {
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
      return 'E-mail ou senha incorretos.';
    case 'email-already-in-use':
      return 'Este e-mail já está cadastrado no sistema.';
    case 'weak-password':
      return 'A senha deve conter no mínimo 6 caracteres.';
    case 'too-many-requests':
      return 'Muitas tentativas seguidas. Aguarde alguns minutos e tente novamente.';
    case 'invalid-email':
      return 'Informe um e-mail válido.';
    case 'network-request-failed':
      return 'Falha de conexão. Verifique sua internet e tente novamente.';
    case 'user-disabled':
      return 'Esta conta foi desativada pela Administradora. Contate o suporte.';
    case 'requires-recent-login':
      return 'Por segurança, entre novamente e repita a operação.';
    case 'permission-denied':
      return 'Operação recusada pelas regras de segurança do servidor.';
  }
  if (err is FirebaseException) return err.message ?? 'Erro ao processar autenticação.';
  return mensagemDoErro(err);
}

AuthUser? _mapUser(User? u) => u == null ? null : AuthUser(uid: u.uid, email: u.email, displayName: u.displayName);

class FirebaseAuthGateway implements AuthGateway {
  final FirebaseAuth auth;

  /// Opções do app primário, reutilizadas no app secundário de provisionamento.
  final FirebaseOptions options;
  final ({String host, int port})? emulador;
  FirebaseAuthGateway(this.auth, this.options, {this.emulador});

  @override
  Stream<AuthUser?> authStateChanges() => auth.authStateChanges().map(_mapUser);

  @override
  AuthUser? get currentUser => _mapUser(auth.currentUser);

  @override
  Future<AuthUser> signIn(String email, String senha) async {
    final cred = await auth.signInWithEmailAndPassword(email: email, password: senha);
    return _mapUser(cred.user)!;
  }

  @override
  Future<AuthUser> createUser(String email, String senha) async {
    final cred = await auth.createUserWithEmailAndPassword(email: email, password: senha);
    return _mapUser(cred.user)!;
  }

  @override
  Future<void> deleteCurrentUser() async => auth.currentUser?.delete();

  @override
  Future<void> signOut() => auth.signOut();

  @override
  Future<void> atualizarSenha(String senhaAtual, String novaSenha) async {
    final user = auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const ErroAmigavel('Sua sessão expirou. Entre novamente para trocar a senha.');
    }
    try {
      await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: email, password: senhaAtual));
      await user.updatePassword(novaSenha);
    } on FirebaseAuthException catch (e) {
      throw ErroAmigavel(traduzirErroAuth(e), codigo: e.code);
    }
  }

  FirebaseApp? _secundario;

  @override
  Future<ContaAuthCriada> criarContaSecundaria(String email, String senha) async {
    // `createUserWithEmailAndPassword` troca a sessão da instância em que é
    // chamado; num app separado, a administradora permanece logada.
    _secundario ??= Firebase.apps.where((a) => a.name == 'retool-user-provisioning').firstOrNull ??
        await Firebase.initializeApp(name: 'retool-user-provisioning', options: options);
    final secAuth = FirebaseAuth.instanceFor(app: _secundario!);
    if (emulador != null) await secAuth.useAuthEmulator(emulador!.host, emulador!.port);
    final cred = await secAuth.createUserWithEmailAndPassword(email: email, password: senha);
    final user = cred.user!;
    return ContaAuthCriada(
      uid: user.uid,
      desfazer: () => user.delete(),
      finalizar: () => secAuth.signOut(),
    );
  }
}

class FirebaseStorageService implements StorageService {
  final FirebaseStorage storage;
  FirebaseStorageService(this.storage);

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

    final fileId = const Uuid().v4();
    final nome = sanitizeFileName(nomeOriginal);
    final storagePath = '$baseStoragePath/${categoria.valor}/${fileId}_$nome'.replaceAll(RegExp(r'/+'), '/');
    final ref = storage.ref(storagePath);
    final task = ref.putData(bytes, SettableMetadata(contentType: contentType));

    final sub = task.snapshotEvents.listen((s) {
      if (s.totalBytes > 0) onProgress?.call((s.bytesTransferred * 100 / s.totalBytes).round());
    }, onError: (_) {});
    try {
      await task;
    } finally {
      await sub.cancel();
    }
    final url = await ref.getDownloadURL();
    onProgress?.call(100);

    return FileAttachment(
      id: fileId,
      originalName: nomeOriginal,
      fileName: '${fileId}_$nome',
      contentType: contentType,
      size: bytes.length,
      storagePath: storagePath,
      downloadURL: url,
      uploadedAt: agoraIso(),
      categoria: categoria,
    );
  }

  @override
  Future<void> deleteFile(String storagePath) async {
    if (storagePath.isEmpty) return;
    try {
      await storage.ref(storagePath).delete();
    } on FirebaseException catch (e) {
      // Idempotente: arquivo já removido conta como sucesso.
      if (e.code != 'object-not-found') debugPrint('Aviso ao excluir arquivo do Storage ($storagePath): $e');
    }
  }

  @override
  Future<void> deleteFolder(String folderPath) async {
    if (folderPath.isEmpty) return;
    try {
      final lista = await storage.ref(folderPath).listAll();
      await Future.wait([
        ...lista.items.map((i) => i.delete().catchError((_) {})),
        ...lista.prefixes.map((p) => deleteFolder(p.fullPath)),
      ]);
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') debugPrint('Aviso ao excluir pasta do Storage ($folderPath): $e');
    }
  }
}

class FirebaseContasService implements ContasService {
  final FirebaseFunctions functions;
  FirebaseContasService(this.functions);

  @override
  Future<String> redefinirSenhaTemporaria(String uid) async {
    final result = await functions.httpsCallable('redefinirSenhaTemporaria').call({'uid': uid});
    return Map<String, dynamic>.from(result.data as Map)['senhaTemporaria'] as String;
  }
}
