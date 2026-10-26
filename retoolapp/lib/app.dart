import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/config/app_dependencies.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/widgets.dart';
import 'presentation/state/auth_controller.dart';
import 'presentation/state/retool_controller.dart';

/// Raiz do app: injeta dependências e controladores e monta o roteador.
class ReToolApp extends StatefulWidget {
  final AppDependencies deps;

  /// `false` nos testes (sem baixar a fonte Inter).
  final bool fontesRemotas;
  const ReToolApp({super.key, required this.deps, this.fontesRemotas = true});

  @override
  State<ReToolApp> createState() => _ReToolAppState();
}

class _ReToolAppState extends State<ReToolApp> {
  late final AuthController _auth = AuthController(widget.deps);
  late final ReToolController _retool = ReToolController(widget.deps, _auth, announce: Toasts.mostrar);
  late final GoRouter _router = criarRouter(_auth);
  late final ThemeData _tema = AppTheme.build(fontesRemotas: widget.fontesRemotas);

  @override
  void dispose() {
    _router.dispose();
    _retool.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppDependencies>.value(value: widget.deps),
        ChangeNotifierProvider<AuthController>.value(value: _auth),
        ChangeNotifierProvider<ReToolController>.value(value: _retool),
      ],
      child: MaterialApp.router(
        title: 'ReTool',
        debugShowCheckedModeBanner: false,
        theme: _tema,
        routerConfig: _router,
        scaffoldMessengerKey: Toasts.messengerKey,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
      ),
    );
  }
}

/// Exibida quando o `.env` não tem as chaves do Firebase.
class ConfiguracaoAusenteApp extends StatelessWidget {
  final List<String> faltando;
  const ConfiguracaoAusenteApp({super.key, required this.faltando});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(fontesRemotas: false),
        home: Scaffold(
          body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
              const ReToolLogo(fontSize: 32),
              const SizedBox(height: AppSpacing.lg),
              const Text('Configuração do Firebase ausente',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Copie o arquivo .env.example para .env na pasta retoolapp, preencha as chaves do app Web do Firebase '
                '(as mesmas do ReTool desktop) e rode o app novamente.',
                style: TextStyle(color: AppColors.textBody, height: 1.5),
              ),
              const SizedBox(height: AppSpacing.md),
              InfoBox(tipo: InfoBoxTipo.aviso, titulo: 'Variáveis não preenchidas', mensagem: faltando.join('\n')),
            ]),
          ),
        ),
      );
}
