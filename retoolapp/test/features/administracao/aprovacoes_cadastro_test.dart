import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retoolapp/domain/entities/audit_log.dart';
import 'package:retoolapp/domain/entities/notificacao.dart';
import 'package:retoolapp/domain/entities/user.dart';
import 'package:retoolapp/features/administracao/administracao_screen.dart';

import '../../support/harness.dart';
import 'admin_test_utils.dart';

void main() {
  testWidgets('com cadastro pendente abre na aba de cadastros com os contadores', (tester) async {
    final b = backendAdmin();
    await criarSolicitacao(b);
    await pumpTela(tester, b, const AdministracaoScreen());

    expect(find.text('Cadastros pendentes (1)'), findsOneWidget);
    expect(find.text('Solicitações de cargo (1)'), findsOneWidget);
    expect(find.text('Usuários (3)'), findsOneWidget);
    expect(find.text('Histórico de ações'), findsOneWidget);
    expect(find.text('Carlos Convidado'), findsOneWidget);
    expect(find.text('Convidado'), findsOneWidget);
    expect(find.text('● Aguardando aprovação'), findsOneWidget);
  });

  testWidgets('aprovar exige cargo e libera a conta com o cargo escolhido', (tester) async {
    final b = backendAdmin();
    await pumpTela(tester, b, const AdministracaoScreen(abaInicial: 'cadastros'));

    // Sem cargo, "Aprovar" fica desabilitado.
    await tocar(tester, find.text('Aprovar'));
    expect(b.users.itens['conv']!.statusAprovacao, StatusAprovacao.pendente);

    await escolherNoDropdown(tester, find.text('Selecione o cargo...'), 'Projetista – Ferramentaria');
    await tocar(tester, find.text('Aprovar'));

    final u = b.users.itens['conv']!;
    expect(u.perfil, 'projetista');
    expect(u.ativo, isTrue);
    expect(u.statusAprovacao, StatusAprovacao.aprovado);
    expect(b.audit.registros.last.acao, AuditLogAcao.aprovacaoUsuario);
    expect(b.notifications.itens.values.where((n) => n.tipo == NotificacaoTipo.contaDecidida && n.destinatarioUid == 'conv'),
        hasLength(1));
    expect(find.text('Cadastro de Carlos Convidado aprovado com o cargo Projetista – Ferramentaria.'), findsOneWidget);
    expect(find.text('Nenhum cadastro aguardando aprovação.'), findsOneWidget);
    expect(find.text('Decisões recentes'), findsOneWidget);
    expect(find.text('● Aprovado'), findsOneWidget);
  });

  testWidgets('rejeitar com motivo opcional', (tester) async {
    final b = backendAdmin();
    await pumpTela(tester, b, const AdministracaoScreen(abaInicial: 'aprovacoes'));

    await tocar(tester, find.text('Rejeitar'));
    expect(find.text('Motivo da rejeição (opcional — exibido ao usuário)'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, 'E-mail externo');
    await tocar(tester, find.text('Confirmar rejeição'));

    final u = b.users.itens['conv']!;
    expect(situacaoDoUsuario(u), SituacaoUsuario.rejeitado);
    expect(u.motivoRejeicao, 'E-mail externo');
    expect(b.audit.registros.last.acao, AuditLogAcao.rejeicaoUsuario);
    expect(find.text('Cadastro de Carlos Convidado rejeitado.'), findsOneWidget);
    expect(find.text('Motivo: E-mail externo'), findsOneWidget);
  });

  testWidgets('cancelar a rejeição esconde o motivo', (tester) async {
    final b = backendAdmin();
    await pumpTela(tester, b, const AdministracaoScreen(abaInicial: 'cadastros'));
    await tocar(tester, find.text('Rejeitar'));
    await tocar(tester, find.text('Cancelar'));
    expect(find.text('Confirmar rejeição'), findsNothing);
    expect(situacaoDoUsuario(b.users.itens['conv']!), SituacaoUsuario.pendente);
  });

  testWidgets('sem pendências abre em Usuários e alterna abas', (tester) async {
    final b = backendAdmin(comConvidado: false);
    await pumpTela(tester, b, const AdministracaoScreen());
    expect(find.text('Nova conta'), findsOneWidget);

    await tocar(tester, find.text('Cadastros pendentes (0)'));
    expect(find.text('Nenhum cadastro aguardando aprovação.'), findsOneWidget);
    await tocar(tester, find.text('Solicitações de cargo (0)'));
    expect(find.text('Nenhuma solicitação de alteração de cargo pendente.'), findsOneWidget);
  });

  testWidgets('"Analisar cadastro" em Usuários leva à aba de cadastros', (tester) async {
    final b = backendAdmin();
    await pumpTela(tester, b, const AdministracaoScreen(abaInicial: 'usuarios'));
    await tocar(tester, find.text('Analisar cadastro'));
    expect(find.text('Selecione o cargo...'), findsOneWidget);
  });

  testWidgets('sem overflow em 360x740 nas quatro abas', (tester) async {
    final b = backendAdmin();
    await criarSolicitacao(b, justificativa: 'Preciso cadastrar dispositivos da linha nova.');
    await registrarLog(b, 'Editou o dispositivo Gabarito de Furação Lateral', conteudo: {'campo': 'peso'});
    await pumpTela(tester, b, const AdministracaoScreen(), tamanho: const Size(360, 740));
    await tocar(tester, find.text('Rejeitar'));
    await tocar(tester, find.textContaining('Solicitações de cargo'));
    await tocar(tester, find.text('Aprovar'));
    await tocar(tester, find.textContaining('Usuários ('));
    await tocar(tester, find.text('Histórico de ações'));
    await tocar(tester, find.text('Editou o dispositivo Gabarito de Furação Lateral'));
    expect(tester.takeException(), isNull);
  });
}
