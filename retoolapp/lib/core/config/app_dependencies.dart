import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../data/repositories/firestore_repositories.dart';
import '../../data/services/firebase_services.dart';
import '../../domain/repositories/repositories.dart';
import 'env.dart';

/// Injeção de dependências do app. Produção usa Firebase; testes montam fakes.
class AppDependencies {
  final AuthGateway auth;
  final UsersRepository users;
  final AuditLogRepository audit;
  final NotificationsRepository notifications;
  final SolicitacoesCargoRepository solicitacoesCargo;
  final DispositivosRepository dispositivos;
  final ClassificacoesRepository classificacoes;
  final ReutilizacoesRepository reutilizacoes;
  final StorageService storage;
  final ContasService contas;

  /// Traduz erros de infraestrutura em mensagens para o usuário.
  final String Function(Object erro) traduzirErro;

  /// URL do formulário externo de reporte de bugs.
  final String urlFormularioBugs;

  const AppDependencies({
    required this.auth,
    required this.users,
    required this.audit,
    required this.notifications,
    required this.solicitacoesCargo,
    required this.dispositivos,
    required this.classificacoes,
    required this.reutilizacoes,
    required this.storage,
    required this.contas,
    required this.traduzirErro,
    required this.urlFormularioBugs,
  });

  static Future<AppDependencies> firebase(AppEnv env) async {
    final options = env.firebaseOptions;
    final app = await Firebase.initializeApp(options: options);
    final db = FirebaseFirestore.instanceFor(app: app);
    final auth = FirebaseAuth.instanceFor(app: app);
    final storage = FirebaseStorage.instanceFor(app: app);
    // Mesma região declarada nas Cloud Functions do desktop.
    final functions = FirebaseFunctions.instanceFor(app: app, region: 'southamerica-east1');

    // Cache offline persistente: listas abrem instantaneamente e funcionam sem rede.
    db.settings = const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);

    ({String host, int port})? emuladorAuth;
    if (env.usarEmuladores) {
      final host = env.hostEmuladores;
      db.useFirestoreEmulator(host, 8181);
      await auth.useAuthEmulator(host, 9099);
      await storage.useStorageEmulator(host, 9199);
      functions.useFunctionsEmulator(host, 5001);
      emuladorAuth = (host: host, port: 9099);
    }

    final storageService = FirebaseStorageService(storage);
    return AppDependencies(
      auth: FirebaseAuthGateway(auth, options, emulador: emuladorAuth),
      users: FirestoreUsersRepository(db),
      audit: FirestoreAuditLogRepository(db),
      notifications: FirestoreNotificationsRepository(db),
      solicitacoesCargo: FirestoreSolicitacoesCargoRepository(db),
      dispositivos: FirestoreDispositivosRepository(db, storage: storageService),
      classificacoes: FirestoreClassificacoesRepository(db),
      reutilizacoes: FirestoreReutilizacoesRepository(db),
      storage: storageService,
      contas: FirebaseContasService(functions),
      traduzirErro: traduzirErroAuth,
      urlFormularioBugs: env.urlFormularioBugs,
    );
  }
}
