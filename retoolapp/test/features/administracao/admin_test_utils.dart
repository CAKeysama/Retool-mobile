import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retoolapp/domain/entities/audit_log.dart';
import 'package:retoolapp/domain/entities/solicitacao_cargo.dart';
import 'package:retoolapp/domain/entities/user.dart';

import '../../support/fakes.dart';
import '../../support/harness.dart';

/// Administração logada + um usuário de cada situação relevante.
FakeBackend backendAdmin({bool comConvidado = true, bool comEngenheiro = true}) {
  final b = FakeBackend();
  if (comConvidado) {
    b.criarUsuario('conv',
        perfil: perfilConvidado,
        nome: 'Carlos Convidado',
        email: 'carlos@baldan.com.br',
        ativo: false,
        status: StatusAprovacao.pendente);
  }
  if (comEngenheiro) {
    b.criarUsuario('eng', perfil: 'engenharia', nome: 'Eduardo Eng', email: 'eduardo@baldan.com.br');
  }
  b.criarUsuario('adm', perfil: 'admin', nome: 'Ana Admin', email: 'ana@baldan.com.br', logar: true);
  return b;
}

Future<void> criarSolicitacao(FakeBackend b,
    {String id = 'sol1', String uid = 'eng', UserRole para = UserRole.projetista, String? justificativa}) async {
  final u = b.users.itens[uid]!;
  await b.solicitacoesCargo.criar(SolicitacaoCargo(
    id: id,
    usuarioUid: uid,
    usuarioNome: u.nome,
    usuarioEmail: u.email,
    perfilAtual: userRoleFromString(u.perfil)!,
    perfilSolicitado: para,
    justificativa: justificativa,
    dataSolicitacao: '2026-03-01T10:00:00.000Z',
  ));
}

Future<void> registrarLog(FakeBackend b, String descricao,
    {AuditLogAcao acao = AuditLogAcao.edicao,
    AuditLogResultado resultado = AuditLogResultado.sucesso,
    String uid = 'eng',
    Map<String, dynamic>? conteudo}) =>
    b.audit.registrarLog(AuditLogInput(
      usuarioUid: uid,
      usuarioNome: 'Eduardo Eng',
      usuarioEmail: 'eduardo@baldan.com.br',
      usuarioPerfil: 'engenharia',
      acao: acao,
      resultado: resultado,
      acaoDescricao: descricao,
      tipoEntidade: AuditLogTipoEntidade.dispositivo,
      entidadeId: 'd1',
      entidadeNome: 'Gabarito',
      conteudo: conteudo,
    ));

/// Escolhe um item num `DropdownButtonFormField` aberto a partir do texto exibido.
Future<void> escolherNoDropdown(WidgetTester tester, Finder dropdown, String item) async {
  await tester.ensureVisible(dropdown.first);
  await tester.pump();
  // O texto fica sob o InputDecorator do campo: o toque abre o menu mesmo assim.
  await tester.tap(dropdown.first, warnIfMissed: false);
  await assentar(tester);
  await tester.tap(find.text(item).last);
  await assentar(tester);
}

/// Captura o que for copiado para a área de transferência.
List<String> capturarClipboard(WidgetTester tester) {
  final copiados = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') {
      copiados.add((call.arguments as Map)['text'] as String);
    }
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return copiados;
}
