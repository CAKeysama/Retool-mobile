import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/config/app_dependencies.dart';
import 'core/config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  await dotenv.load(fileName: '.env', isOptional: true);

  final env = AppEnv(dotenv.env);
  if (!env.configurado) {
    runApp(ConfiguracaoAusenteApp(faltando: env.faltando));
    return;
  }
  runApp(ReToolApp(deps: await AppDependencies.firebase(env)));
}
