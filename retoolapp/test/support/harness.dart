import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:retoolapp/app.dart';
import 'package:retoolapp/core/theme/app_theme.dart';
import 'package:retoolapp/core/widgets/widgets.dart';
import 'package:retoolapp/presentation/state/auth_controller.dart';
import 'package:retoolapp/presentation/state/retool_controller.dart';

import 'fakes.dart';

bool _datasProntas = false;

Future<void> prepararLocale() async {
  if (_datasProntas) return;
  await initializeDateFormatting('pt_BR');
  _datasProntas = true;
}

/// Sobe o app inteiro (router, guardas, shell) sobre o [FakeBackend].
/// Use `backend.criarUsuario(..., logar: true)` antes para entrar logado.
Future<void> pumpApp(WidgetTester tester, FakeBackend backend, {Size tamanho = const Size(412, 915)}) async {
  await prepararLocale();
  tester.view.physicalSize = tamanho * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ReToolApp(deps: backend.deps, fontesRemotas: false));
  await assentar(tester);
}

/// Avança streams e animações sem depender de `pumpAndSettle` (que trava com
/// indicadores de progresso infinitos).
Future<void> assentar(WidgetTester tester, {int quadros = 12}) async {
  for (var i = 0; i < quadros; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// Controladores conectados ao [FakeBackend] para testar uma tela isolada.
class ControladoresTeste {
  final FakeBackend backend;
  late final AuthController auth = AuthController(backend.deps);
  late final ReToolController retool = ReToolController(backend.deps, auth, announce: anuncios.add);
  final List<String> anuncios = [];
  ControladoresTeste(this.backend);

  void dispose() {
    retool.dispose();
    auth.dispose();
  }
}

/// Monta só um widget (sem router) com os providers do app. Navegações via
/// `context.push/go` não funcionam aqui — use [pumpApp] para fluxos de navegação.
Future<ControladoresTeste> pumpTela(
  WidgetTester tester,
  FakeBackend backend,
  Widget tela, {
  Size tamanho = const Size(412, 915),
}) async {
  await prepararLocale();
  tester.view.physicalSize = tamanho * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  final c = ControladoresTeste(backend);
  addTearDown(c.dispose);
  await tester.pumpWidget(MultiProvider(
    providers: [
      Provider.value(value: backend.deps),
      ChangeNotifierProvider<AuthController>.value(value: c.auth),
      ChangeNotifierProvider<ReToolController>.value(value: c.retool),
    ],
    child: MaterialApp(
      theme: AppTheme.build(fontesRemotas: false),
      scaffoldMessengerKey: Toasts.messengerKey,
      home: tela,
    ),
  ));
  await assentar(tester);
  return c;
}

/// Rola até o alvo e toca (botões abaixo da dobra em telas de celular).
Future<void> tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo.first);
  await tester.pump();
  await tester.tap(alvo.first);
  await assentar(tester);
}
