import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retoolapp/domain/entities/audit_log.dart';
import 'package:retoolapp/domain/entities/notificacao.dart';
import 'package:retoolapp/domain/entities/solicitacao_cargo.dart';
import 'package:retoolapp/domain/entities/user.dart';
import 'package:retoolapp/features/administracao/administracao_screen.dart';

import '../../support/harness.dart';
import 'admin_test_utils.dart';

void main() {
  testWidgets('lista a pendente com transição de cargo e justificativa', (tester) async {
    final b = backendAdmin(comConvidado: false);
    await criarSolicitacao(b, justificativa: 'Vou cadastrar dispositivos.');
    await pumpTela(tester, b, const AdministracaoScreen());

    expect(find.text('Pendentes (1)'), findsOneWidget);
    expect(find.text('Eduardo Eng'), findsOneWidget);
    expect(find.text('Engenharia de Processo / Industrial'), findsOneWidget);
    expect(find.text('Projetista – Ferramentaria'), findsOneWidget);
    expect(find.textContaining('Vou cadastrar dispositivos.'), findsOneWidget);
    expect(find.text('Nenhuma decisão registrada.'), findsOneWidget);
  });

  testWidgets('aprovar muda o cargo do usuário e notifica', (tester) async {
    final b = backendAdmin(comConvidado: false);
    await criarSolicitacao(b);
    await pumpTela(tester, b, const AdministracaoScreen(abaInicial: 'cargos'));

    await tocar(tester, find.text('Aprovar'));
    expect(find.textContaining('Confirmar a alteração do cargo de'), findsOneWidget);
    await tocar(tester, find.text('Confirmar aprovação'));

    expect(b.users.itens['eng']!.perfil, 'projetista');
    expect(b.solicitacoesCargo.itens['sol1']!.status, SolicitacaoCargoStatus.aprovada);
    expect(b.solicitacoesCargo.itens['sol1']!.decididoPorNome, 'Ana Admin');
    expect(b.audit.registros.last.acao, AuditLogAcao.aprovacaoCargo);
    expect(b.notifications.itens.values.where((n) => n.tipo == NotificacaoTipo.cargoDecidido && n.destinatarioUid == 'eng'),
        hasLength(1));
    expect(find.text('Cargo de Eduardo Eng alterado para Projetista – Ferramentaria.'), findsOneWidget);
    expect(find.text('Pendentes (0)'), findsOneWidget);
    expect(find.text('Aprovada'), findsOneWidget); // histórico
  });

  testWidgets('rejeitar com observação mantém o cargo atual', (tester) async {
    final b = backendAdmin(comConvidado: false);
    await criarSolicitacao(b);
    await pumpTela(tester, b, const AdministracaoScreen(abaInicial: 'cargos'));

    await tocar(tester, find.text('Rejeitar'));
    await tester.enterText(find.byType(TextFormField).last, 'Sem vaga no setor');
    await tocar(tester, find.text('Confirmar rejeição'));

    final s = b.solicitacoesCargo.itens['sol1']!;
    expect(s.status, SolicitacaoCargoStatus.rejeitada);
    expect(s.motivoDecisao, 'Sem vaga no setor');
    expect(b.users.itens['eng']!.perfil, 'engenharia');
    expect(find.text('Solicitação de Eduardo Eng rejeitada; o cargo atual foi mantido.'), findsOneWidget);
    expect(find.text('Sem vaga no setor'), findsOneWidget);
  });

  testWidgets('histórico filtra por status', (tester) async {
    final b = backendAdmin(comConvidado: false);
    b.criarUsuario('ger', perfil: 'gerencia', nome: 'Gisele Ger');
    await criarSolicitacao(b);
    await criarSolicitacao(b, id: 'sol2', uid: 'ger', para: UserRole.projetista);
    await pumpTela(tester, b, const AdministracaoScreen(abaInicial: 'cargos'));

    await tocar(tester, find.text('Aprovar').first);
    await tocar(tester, find.text('Confirmar aprovação'));
    await tocar(tester, find.text('Rejeitar'));
    await tocar(tester, find.text('Confirmar rejeição'));
    expect(find.text('Aprovada'), findsOneWidget);
    expect(find.text('Rejeitada'), findsOneWidget);

    await escolherNoDropdown(tester, find.text('Todas as decisões'), 'Rejeitadas');
    expect(find.text('Aprovada'), findsNothing);
    expect(find.text('Rejeitada'), findsOneWidget);
  });
}
