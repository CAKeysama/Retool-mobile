import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retoolapp/core/config/app_dependencies.dart';
import 'package:retoolapp/domain/entities/audit_log.dart';
import 'package:retoolapp/domain/entities/user.dart';
import 'package:retoolapp/domain/errors.dart';
import 'package:retoolapp/domain/repositories/repositories.dart';
import 'package:retoolapp/features/administracao/administracao_screen.dart';

import '../../support/fakes.dart';
import '../../support/harness.dart';
import 'admin_test_utils.dart';

const _msgFunctions =
    'Serviço de redefinição de senha indisponível. Verifique se as Cloud Functions foram publicadas (requer o plano Blaze do Firebase).';

class _ContasIndisponiveis implements ContasService {
  @override
  Future<String> redefinirSenhaTemporaria(String uid) async => throw const ErroAmigavel(_msgFunctions);
}

/// Backend cujas Cloud Functions não foram publicadas.
class _BackendSemFunctions extends FakeBackend {
  late final AppDependencies _deps = AppDependencies(
    auth: auth,
    users: users,
    audit: audit,
    notifications: notifications,
    solicitacoesCargo: solicitacoesCargo,
    dispositivos: dispositivos,
    classificacoes: classificacoes,
    reutilizacoes: reutilizacoes,
    storage: storage,
    contas: _ContasIndisponiveis(),
    traduzirErro: mensagemDoErro,
    urlFormularioBugs: 'https://example.com/bugs',
  );

  @override
  AppDependencies get deps => _deps;
}

Future<void> _abrirUsuarios(WidgetTester tester, FakeBackend b, {Size tamanho = const Size(412, 915)}) =>
    pumpTela(tester, b, const AdministracaoScreen(abaInicial: 'usuarios'), tamanho: tamanho);

void main() {
  testWidgets('lista usuários com cargo, situação e contagem', (tester) async {
    final b = backendAdmin();
    await _abrirUsuarios(tester, b);
    expect(find.text('3 de 3 usuários'), findsOneWidget);
    expect(find.text('Ana Admin (você)'), findsOneWidget);
    expect(find.text('Eduardo Eng'), findsOneWidget);
    expect(find.text('Carlos Convidado'), findsOneWidget);
    expect(find.text('● Ativo'), findsNWidgets(2));
    expect(find.text('● Aguardando aprovação'), findsOneWidget);
    expect(find.text('Analisar cadastro'), findsOneWidget);
  });

  testWidgets('busca e filtros por situação e cargo', (tester) async {
    final b = backendAdmin();
    await _abrirUsuarios(tester, b);

    await tester.enterText(find.byType(TextField).first, 'eduardo');
    await tester.pump(const Duration(milliseconds: 250));
    await assentar(tester);
    expect(find.text('1 de 3 usuários'), findsOneWidget);
    expect(find.text('Eduardo Eng'), findsOneWidget);
    expect(find.text('Carlos Convidado'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump(const Duration(milliseconds: 250));
    await escolherNoDropdown(tester, find.text('Todas as situações'), 'Aguardando aprovação');
    expect(find.text('1 de 3 usuários'), findsOneWidget);
    expect(find.text('Carlos Convidado'), findsOneWidget);

    await escolherNoDropdown(tester, find.text('Aguardando aprovação').first, 'Todas as situações');
    await escolherNoDropdown(tester, find.text('Todos os cargos'), 'Engenharia');
    expect(find.text('1 de 3 usuários'), findsOneWidget);
    expect(find.text('Eduardo Eng'), findsOneWidget);
  });

  testWidgets('criar conta mostra a senha temporária uma vez e exige troca no 1º acesso', (tester) async {
    final b = backendAdmin();
    final copiados = capturarClipboard(tester);
    await _abrirUsuarios(tester, b);

    await tocar(tester, find.text('Nova conta'));
    expect(find.text('Criar nova conta'), findsOneWidget);
    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'Paula Projetista');
    await tester.enterText(campos.at(1), 'PAULA@baldan.com.br');
    await escolherNoDropdown(tester, find.text('Engenharia de Processo / Industrial'), 'Projetista – Ferramentaria');
    await tocar(tester, find.text('Criar conta e gerar senha'));

    final criado = b.users.itens.values.firstWhere((u) => u.email == 'paula@baldan.com.br');
    expect(criado.perfil, 'projetista');
    expect(criado.trocaSenhaObrigatoria, isTrue);
    expect(criado.criadoPorUid, 'adm');
    expect(b.audit.registros.last.acao, AuditLogAcao.criacaoUsuario);

    expect(find.text('Conta criada: Paula Projetista (Projetista – Ferramentaria)'), findsOneWidget);
    expect(find.textContaining('não será exibida novamente'), findsOneWidget);
    final senha = tester.widget<SelectableText>(find.byKey(const ValueKey('senha-temporaria'))).data!;
    expect(b.auth.contas['paula@baldan.com.br']!.senha, senha);
    // A senha nunca vai para a auditoria.
    expect(b.audit.registros.any((r) => r.toMap().toString().contains(senha)), isFalse);

    await tocar(tester, find.text('Copiar'));
    expect(copiados, [senha]);
    expect(find.text('Copiada'), findsOneWidget);

    await tocar(tester, find.text('Concluir'));
    expect(find.byKey(const ValueKey('senha-temporaria')), findsNothing);
    expect(find.text('Paula Projetista'), findsOneWidget);
  });

  testWidgets('erro na criação aparece no formulário', (tester) async {
    final b = backendAdmin();
    await _abrirUsuarios(tester, b);
    await tocar(tester, find.text('Nova conta'));
    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'Repetido');
    await tester.enterText(campos.at(1), 'eduardo@baldan.com.br');
    await tocar(tester, find.text('Criar conta e gerar senha'));
    expect(find.text('Este e-mail já está cadastrado no sistema.'), findsOneWidget);
  });

  testWidgets('altera o cargo de outro usuário, nunca o próprio', (tester) async {
    final b = backendAdmin();
    await _abrirUsuarios(tester, b);
    expect(find.byTooltip('Cargo de Ana Admin'), findsNothing);

    await tocar(tester, find.byTooltip('Cargo de Eduardo Eng'));
    await tester.tap(find.text('Gerência').last);
    await assentar(tester);

    expect(b.users.itens['eng']!.perfil, 'gerencia');
    expect(b.audit.registros.last.acao, AuditLogAcao.alteracaoPerfil);
    expect(find.text('Cargo de Eduardo Eng alterado para Gerência.'), findsOneWidget);
  });

  testWidgets('bloqueia e desbloqueia outro usuário', (tester) async {
    final b = backendAdmin(comConvidado: false);
    await _abrirUsuarios(tester, b);
    // Só existe o botão do outro usuário.
    expect(find.text('Bloquear acesso'), findsOneWidget);

    await tocar(tester, find.text('Bloquear acesso'));
    expect(b.users.itens['eng']!.ativo, isFalse);
    expect(find.text('● Bloqueado'), findsOneWidget);
    expect(b.audit.registros.last.acao, AuditLogAcao.bloqueioUsuario);

    await tocar(tester, find.text('Desbloquear'));
    expect(b.users.itens['eng']!.ativo, isTrue);
    expect(b.audit.registros.last.acao, AuditLogAcao.desbloqueioUsuario);
  });

  testWidgets('exclui outro usuário com confirmação; a própria conta não', (tester) async {
    final b = backendAdmin(comConvidado: false);
    await _abrirUsuarios(tester, b);

    await tocar(tester, find.byTooltip('Não é possível excluir a própria conta'));
    expect(find.text('Excluir usuário'), findsNothing);
    expect(b.users.itens.containsKey('adm'), isTrue);

    await tocar(tester, find.byTooltip('Excluir usuário Eduardo Eng'));
    expect(find.textContaining('Esta ação não pode ser desfeita.'), findsOneWidget);
    await tocar(tester, find.text('Cancelar'));
    expect(b.users.itens.containsKey('eng'), isTrue);

    await tocar(tester, find.byTooltip('Excluir usuário Eduardo Eng'));
    await tocar(tester, find.text('Excluir'));
    expect(b.users.itens.containsKey('eng'), isFalse);
    expect(b.audit.registros.last.acao, AuditLogAcao.exclusao);
    expect(find.text('Usuário Eduardo Eng excluído do sistema.'), findsOneWidget);
  });

  testWidgets('redefinir senha mostra a nova senha temporária', (tester) async {
    final b = backendAdmin(comConvidado: false);
    await _abrirUsuarios(tester, b);
    expect(find.byTooltip('Gerar nova senha temporária para Ana Admin'), findsNothing);

    await tocar(tester, find.byTooltip('Gerar nova senha temporária para Eduardo Eng'));
    expect(find.textContaining('deixará de valer'), findsOneWidget);
    await tocar(tester, find.text('Gerar nova senha'));

    expect(b.contas.redefinidas, ['eng']);
    expect(find.text('Nova senha temporária: Eduardo Eng'), findsOneWidget);
    expect(find.text('Tmp-Senha-123!'), findsOneWidget);
    await tocar(tester, find.text('Concluir'));
    expect(find.text('Tmp-Senha-123!'), findsNothing);
  });

  testWidgets('Cloud Functions indisponíveis mostram mensagem amigável', (tester) async {
    final b = _BackendSemFunctions();
    b.criarUsuario('eng', perfil: 'engenharia', nome: 'Eduardo Eng');
    b.criarUsuario('adm', perfil: 'admin', nome: 'Ana Admin', logar: true);
    await _abrirUsuarios(tester, b);

    await tocar(tester, find.byTooltip('Gerar nova senha temporária para Eduardo Eng'));
    await tocar(tester, find.text('Gerar nova senha'));
    expect(find.text(_msgFunctions), findsOneWidget);
    expect(find.byKey(const ValueKey('senha-temporaria')), findsNothing);
  });

  testWidgets('cadastro pendente não pode ser bloqueado nem ter o cargo alterado', (tester) async {
    final b = backendAdmin(comEngenheiro: false);
    await _abrirUsuarios(tester, b);
    expect(find.text('Bloquear acesso'), findsNothing);
    expect(find.byTooltip('Cargo de Carlos Convidado'), findsNothing);
    expect(situacaoDoUsuario(b.users.itens['conv']!), SituacaoUsuario.pendente);
  });

  testWidgets('sem overflow em 360x740 com conta de senha temporária', (tester) async {
    final b = backendAdmin();
    b.criarUsuario('tmp', perfil: 'gerencia', nome: 'Gustavo Gerente com Nome Bem Comprido', trocaSenha: true);
    await _abrirUsuarios(tester, b, tamanho: const Size(360, 740));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await assentar(tester);
    expect(tester.takeException(), isNull);
  });
}
