import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/rotas.dart';

/// Volta para a tela anterior; sem histórico, abre a lista de dispositivos.
/// Funciona também fora do GoRouter (telas montadas isoladamente nos testes).
void voltarDaTelaDeDispositivo(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router == null) {
    Navigator.of(context).maybePop();
    return;
  }
  if (router.canPop()) {
    router.pop();
  } else {
    router.go(Rotas.dispositivos);
  }
}
