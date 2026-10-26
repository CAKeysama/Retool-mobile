import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retoolapp/domain/entities/audit_log.dart';
import 'package:retoolapp/domain/entities/notificacao.dart';
import 'package:retoolapp/domain/entities/user.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

void main() {
  testWidgets('sem sessão abre o login', (tester) async {
    final b = FakeBackend();
    await pumpApp(tester, b);
    expect(find.text('Acesse o Sistema'), findsOneWidget);
    expect(find.text('Entrar no ReTool'), findsOneWidget);
  });

  testWidgets('login válido entra no sistema e registra auditoria', (tester) async {
    final b = FakeBackend();
    b.criarUsuario('adm', perfil: 'admin', email: 'ana@baldan.com.br', senha: 'segredo1');
    await pumpApp(tester, b);

    await tester.enterText(find.byType(TextFormField).at(0), 'ANA@baldan.com.br ');
    await tester.enterText(find.byType(TextFormField).at(1), 'segredo1');
    await tocar(tester, find.text('Entrar no ReTool'));

    expect(find.text('Acesse o Sistema'), findsNothing);
    expect(find.text('Dispositivos'), findsWidgets); // barra inferior
    final log = b.audit.registros.last;
    expect(log.acao, AuditLogAcao.login);
    expect(log.acaoDescricao, 'Entrou no sistema');
  });

  testWidgets('senha errada mostra mensagem amigável', (tester) async {
    final b = FakeBackend();
    b.criarUsuario('adm', email: 'ana@baldan.com.br', senha: 'segredo1');
    await pumpApp(tester, b);

    await tester.enterText(find.byType(TextFormField).at(0), 'ana@baldan.com.br');
    await tester.enterText(find.byType(TextFormField).at(1), 'errada');
    await tocar(tester, find.text('Entrar no ReTool'));

    expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
  });

  testWidgets('conta bloqueada é recusada com o motivo', (tester) async {
    final b = FakeBackend();
    b.criarUsuario('u1', perfil: 'projetista', email: 'p@b.com', senha: 'segredo1', ativo: false);
    await pumpApp(tester, b);

    await tester.enterText(find.byType(TextFormField).at(0), 'p@b.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'segredo1');
    await tocar(tester, find.text('Entrar no ReTool'));

    expect(find.textContaining('desativado pela Administradora'), findsOneWidget);
    expect(b.auth.currentUser, isNull);
    expect(b.audit.registros.last.resultado, AuditLogResultado.negado);
  });

  testWidgets('autocadastro vira Convidado em análise e notifica a Administração', (tester) async {
    final b = FakeBackend();
    b.criarUsuario('adm', perfil: 'admin');
    await pumpApp(tester, b);

    await tocar(tester, find.text('Cadastre-se aqui'));
    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'Maria Silva');
    await tester.enterText(campos.at(1), 'maria@baldan.com.br');
    await tester.enterText(campos.at(2), 'senha123');
    await tester.enterText(campos.at(3), 'senha123');
    await tocar(tester, find.text('Cadastrar e Aguardar Aprovação'));

    expect(find.text('Cadastro em análise'), findsOneWidget);
    final criado = b.users.itens.values.firstWhere((u) => u.email == 'maria@baldan.com.br');
    expect(criado.perfil, perfilConvidado);
    expect(situacaoDoUsuario(criado), SituacaoUsuario.pendente);
    expect(b.notifications.itens.values.where((n) => n.tipo == NotificacaoTipo.contaNova && n.destinatarioUid == 'adm'),
        hasLength(1));
  });

  testWidgets('aprovação em tempo real libera o sistema para o convidado', (tester) async {
    final b = FakeBackend();
    b.criarUsuario('conv', perfil: perfilConvidado, ativo: false, status: StatusAprovacao.pendente, logar: true);
    await pumpApp(tester, b);
    expect(find.text('Cadastro em análise'), findsOneWidget);

    await b.users.updateProfile('conv', {'perfil': 'engenharia', 'ativo': true, 'statusAprovacao': 'aprovado'});
    await assentar(tester);

    expect(find.text('Cadastro em análise'), findsNothing);
    expect(find.text('Reutilizações'), findsWidgets);
  });

  testWidgets('senha temporária exige troca antes do sistema', (tester) async {
    final b = FakeBackend();
    b.criarUsuario('novo', perfil: 'engenharia', senha: 'Tmp-ABC-123', trocaSenha: true, logar: true);
    await pumpApp(tester, b);
    expect(find.text('Defina sua nova senha'), findsOneWidget);

    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'Tmp-ABC-123');
    await tester.enterText(campos.at(1), 'novaSenha9');
    await tester.enterText(campos.at(2), 'novaSenha9');
    await tester.pump();
    await tocar(tester, find.text('Salvar nova senha e continuar'));

    expect(find.text('Defina sua nova senha'), findsNothing);
    expect(b.users.itens['novo']!.trocaSenhaObrigatoria, isFalse);
    expect(b.auth.contas['novo@baldan.com.br']!.senha, 'novaSenha9');
  });

  testWidgets('abas Categorias e Admin aparecem só para quem pode', (tester) async {
    final b = FakeBackend();
    b.criarUsuario('eng', perfil: 'engenharia', logar: true);
    await pumpApp(tester, b);
    expect(find.text('Categorias'), findsNothing);
    expect(find.text('Admin'), findsNothing);
  });

  testWidgets('admin vê abas Categorias e Admin', (tester) async {
    final b = FakeBackend();
    b.criarUsuario('adm', perfil: 'admin', logar: true);
    await pumpApp(tester, b);
    expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Categorias')), findsOneWidget);
    expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Admin')), findsOneWidget);
  });
}
