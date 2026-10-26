import 'package:flutter/foundation.dart';

import '../../domain/entities/audit_log.dart';
import '../../domain/entities/notificacao.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/repositories.dart';

/// Autoria do registro de auditoria a partir de um perfil.
AuditLogInput logDe(
  UserProfile u, {
  required AuditLogAcao acao,
  AuditLogResultado resultado = AuditLogResultado.sucesso,
  String? acaoDescricao,
  required AuditLogTipoEntidade tipoEntidade,
  required String entidadeId,
  String? entidadeNome,
  String? detalhes,
  Map<String, dynamic>? conteudo,
  Map<String, dynamic>? dadosAnteriores,
}) =>
    AuditLogInput(
      usuarioUid: u.uid,
      usuarioNome: u.nome,
      usuarioEmail: u.email,
      usuarioPerfil: u.perfil,
      acao: acao,
      resultado: resultado,
      acaoDescricao: acaoDescricao,
      tipoEntidade: tipoEntidade,
      entidadeId: entidadeId,
      entidadeNome: entidadeNome,
      detalhes: detalhes,
      conteudo: conteudo,
      dadosAnteriores: dadosAnteriores,
    );

/// A auditoria nunca derruba a operação principal.
Future<void> registrarAuditoriaSemFalhar(AuditLogRepository repo, AuditLogInput input) async {
  try {
    await repo.registrarLog(input);
  } catch (e) {
    debugPrint('Falha ao registrar auditoria: $e');
  }
}

/// Envia uma notificação a cada administrador ativo. Retorna quantos foram notificados.
Future<int> notificarAdministradores(
  UsersRepository usersRepo,
  NotificationsRepository notificationsRepo,
  Notificacao Function(UserProfile admin) montar, {
  String? exceto,
}) async {
  List<UserProfile> admins;
  try {
    admins = await usersRepo.listarAdministradoresAtivos();
  } catch (e) {
    debugPrint('Não foi possível localizar a Administração para notificar: $e');
    return 0;
  }
  var enviados = 0;
  for (final admin in admins) {
    if (admin.uid == exceto) continue;
    try {
      await notificationsRepo.criar(montar(admin));
      enviados++;
    } catch (e) {
      debugPrint('Falha ao notificar a Administração: $e');
    }
  }
  return enviados;
}

String limparTexto(String? valor, int max) {
  final t = (valor ?? '').trim();
  return t.length > max ? t.substring(0, max) : t;
}

bool emailValido(String email) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);

/// Mesmo formato do `new Date().toISOString()` do desktop (UTC, milissegundos),
/// para que a ordenação textual de `dataHora` continue homogênea entre os apps.
String agoraIso() => isoDe(DateTime.now());

String isoDe(DateTime d) {
  final utc = d.toUtc();
  final ms = DateTime.utc(utc.year, utc.month, utc.day, utc.hour, utc.minute, utc.second, utc.millisecond);
  return ms.toIso8601String();
}
