import 'package:firebase_core/firebase_core.dart';

/// Configuração lida do `.env` (mesmos nomes de variáveis do ReTool desktop,
/// então o `.env` da versão web pode ser copiado sem alterações).
class AppEnv {
  final Map<String, String> valores;
  const AppEnv(this.valores);

  String? _v(String chave) {
    final v = valores[chave]?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  bool _flag(String chave) => _v(chave)?.toLowerCase() == 'true';

  bool get usarFallback => _flag('VITE_USE_FALLBACK_DB');
  bool get usarEmuladores => _flag('VITE_USE_FIREBASE_EMULATORS');

  /// Host dos emuladores. No emulador Android, `10.0.2.2` aponta para o PC.
  String get hostEmuladores => _v('VITE_FIREBASE_EMULATOR_HOST') ?? '10.0.2.2';

  String get _prefixo => usarFallback ? 'VITE_FIREBASE_FALLBACK' : 'VITE_FIREBASE';

  /// Variáveis obrigatórias ausentes para o banco selecionado.
  List<String> get faltando {
    if (usarEmuladores) return const [];
    return ['API_KEY', 'PROJECT_ID', 'APP_ID', 'MESSAGING_SENDER_ID', 'STORAGE_BUCKET']
        .map((s) => '${_prefixo}_$s')
        .where((k) => _v(k) == null)
        .toList();
  }

  bool get configurado => faltando.isEmpty;

  FirebaseOptions get firebaseOptions {
    if (usarEmuladores) {
      // Projeto "demo-" dispensa credenciais reais nos emuladores.
      return const FirebaseOptions(
        apiKey: 'demo-api-key',
        appId: '1:000000000000:android:0000000000000000',
        messagingSenderId: '000000000000',
        projectId: 'demo-retool',
        storageBucket: 'demo-retool.appspot.com',
      );
    }
    return FirebaseOptions(
      apiKey: _v('${_prefixo}_API_KEY') ?? '',
      appId: _v('${_prefixo}_APP_ID') ?? '',
      messagingSenderId: _v('${_prefixo}_MESSAGING_SENDER_ID') ?? '',
      projectId: _v('${_prefixo}_PROJECT_ID') ?? '',
      authDomain: _v('${_prefixo}_AUTH_DOMAIN'),
      storageBucket: _v('${_prefixo}_STORAGE_BUCKET'),
      measurementId: _v('${_prefixo}_MEASUREMENT_ID'),
    );
  }

  /// Link do formulário de bugs (o mesmo do botão da Home do desktop).
  String get urlFormularioBugs =>
      _v('RETOOL_BUG_FORM_URL') ??
      'https://docs.google.com/forms/d/e/1FAIpQLSdjL1QGliGpivKDGh0F9frKXchfo5gdtF5kTEpKOBVS7VpuIw/viewform';
}
