import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:retoolapp/domain/entities/audit_log.dart';
import 'package:retoolapp/domain/entities/notificacao.dart';
import 'package:retoolapp/domain/entities/solicitacao_cargo.dart';
import 'package:retoolapp/domain/entities/user.dart';
import 'package:retoolapp/domain/repositories/repositories.dart';
import 'package:retoolapp/features/conta/perfil_screen.dart';
import 'package:retoolapp/features/sobre/sobre_screen.dart';

import '../../support/fakes.dart';
import '../../support/harness.dart';
import '../administracao/admin_test_utils.dart';

FakeBackend _engenheiro() {
  final b = FakeBackend();
  b.criarUsuario('adm', perfil: 'admin', nome: 'Ana Admin');
  b.criarUsuario('eng', perfil: 'engenharia', nome: 'Eduardo Eng', email: 'eduardo@baldan.com.br', logar: true);
  return b;
}

void main() {
  testWidgets('mostra avatar, dados, cargo, descrição e permissões', (tester) async {
    final b = _engenheiro();
    await pumpTela(tester, b, const PerfilScreen());

    expect(find.text('E'), findsOneWidget);
    expect(find.text('Eduardo Eng'), findsOneWidget);
    expect(find.text('eduardo@baldan.com.br'), findsOneWidget);
    expect(find.text('Engenharia de Processo / Industrial'), findsNWidgets(2)); // badge + quadro do cargo
    expect(find.textContaining('Faz a consulta e solicita reutilização'), findsOneWidget);
    // Engenharia: consulta e solicita; não cadastra, edita, exclui, aprova nem gerencia.
    expect(find.byIcon(LucideIcons.check), findsNWidgets(2));
    expect(find.byIcon(LucideIcons.x), findsNWidgets(6));
    expect(find.text('Solicitar alteração de cargo'), findsOneWidget);
    expect(find.text('Administração: usuários e aprovações'), findsNothing);
    expect(find.text('Sobre o Projeto'), findsOneWidget);
    expect(find.text('Sair da Conta'), findsOneWidget);
  });

  testWidgets('admin vê atalhos administrativos e não solicita cargo', (tester) async {
    final b = FakeBackend();
    b.criarUsuario('adm', perfil: 'admin', nome: 'Ana Admin', logar: true);
    await pumpTela(tester, b, const PerfilScreen());
    expect(find.text('Administração: usuários e aprovações'), findsOneWidget);
    expect(find.text('Histórico de ações (auditoria)'), findsOneWidget);
    expect(find.text('Solicitar alteração de cargo'), findsNothing);
    expect(find.byIcon(LucideIcons.x), findsNothing);
  });

  testWidgets('solicitar cargo cria solicitação pendente e notifica a Administração', (tester) async {
    final b = _engenheiro();
    await pumpTela(tester, b, const PerfilScreen());

    await tocar(tester, find.text('Solicitar alteração de cargo'));
    expect(find.text('Alteração de cargo'), findsOneWidget);
    expect(find.text('Cargo atual:'), findsOneWidget);

    await escolherNoDropdown(tester, find.text('Selecione...'), 'Projetista – Ferramentaria');
    expect(find.textContaining('Atua na análise e aprovação'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, 'Passei a cadastrar dispositivos.');
    await tocar(tester, find.text('Enviar solicitação'));

    final s = b.solicitacoesCargo.itens.values.single;
    expect(s.status, SolicitacaoCargoStatus.pendente);
    expect(s.perfilSolicitado, UserRole.projetista);
    expect(s.justificativa, 'Passei a cadastrar dispositivos.');
    expect(
        b.notifications.itens.values.where((n) => n.tipo == NotificacaoTipo.cargoSolicitado && n.destinatarioUid == 'adm'),
        hasLength(1));
    expect(b.audit.registros.last.acao, AuditLogAcao.solicitacaoCargo);
    expect(find.textContaining('Solicitação enviada.'), findsOneWidget);
    expect(find.textContaining('aguardando a decisão da Administração'), findsOneWidget);

    await tocar(tester, find.byTooltip('Fechar'));
    expect(find.text('Alteração de cargo (pendente)'), findsOneWidget);
  });

  testWidgets('mostra solicitações anteriores decididas', (tester) async {
    final b = _engenheiro();
    await criarSolicitacao(b, para: UserRole.gerencia);
    final s = b.solicitacoesCargo.itens['sol1']!;
    await b.solicitacoesCargo.decidir(
        s,
        const DecisaoSolicitacaoCargo(
          status: SolicitacaoCargoStatus.rejeitada,
          decididoPorUid: 'adm',
          decididoPorNome: 'Ana Admin',
          dataDecisao: '2026-03-02T10:00:00.000Z',
          motivoDecisao: 'Fora do escopo',
        ));
    await pumpTela(tester, b, const PerfilScreen());
    await tocar(tester, find.text('Solicitar alteração de cargo'));
    expect(find.text('Solicitações anteriores'), findsOneWidget);
    expect(find.text('Rejeitada'), findsOneWidget);
    expect(find.text('— Fora do escopo'), findsOneWidget);
    expect(find.text('Enviar solicitação'), findsOneWidget);
  });

  testWidgets('sair pede confirmação e desloga', (tester) async {
    final b = _engenheiro();
    await pumpApp(tester, b);
    await tocar(tester, find.bySemanticsLabel(RegExp('Menu do usuário')));
    expect(find.byType(PerfilScreen), findsOneWidget);

    await tocar(tester, find.text('Sair da Conta'));
    await tocar(tester, find.text('Cancelar'));
    expect(b.auth.currentUser, isNotNull);

    await tocar(tester, find.text('Sair da Conta'));
    await tocar(tester, find.text('Sair'));
    expect(b.auth.currentUser, isNull);
    expect(b.audit.registros.last.acao, AuditLogAcao.logout);
    expect(find.text('Acesse o Sistema'), findsOneWidget);
  });

  testWidgets('"Sobre o Projeto" abre a tela Sobre', (tester) async {
    final b = _engenheiro();
    await pumpApp(tester, b);
    await tocar(tester, find.bySemanticsLabel(RegExp('Menu do usuário')));
    await tocar(tester, find.text('Sobre o Projeto'));
    expect(find.byType(SobreScreen), findsOneWidget);
  });

  testWidgets('sem overflow em 360x740 (perfil e sheet de cargo)', (tester) async {
    final b = _engenheiro();
    await pumpTela(tester, b, const PerfilScreen(), tamanho: const Size(360, 740));
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await assentar(tester);
    await tocar(tester, find.text('Solicitar alteração de cargo'));
    await escolherNoDropdown(tester, find.text('Selecione...'), 'Programadora / Administradora');
    expect(tester.takeException(), isNull);
  });
}
