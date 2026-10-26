import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:retoolapp/application/usecases/acessos_comum.dart';
import 'package:retoolapp/domain/entities/notificacao.dart';
import 'package:retoolapp/domain/entities/user.dart';
import 'package:retoolapp/features/administracao/administracao_screen.dart';
import 'package:retoolapp/features/conta/notificacoes_screen.dart';

import '../../support/fakes.dart';
import '../../support/harness.dart';

Notificacao _notif(
  String id, {
  NotificacaoTipo tipo = NotificacaoTipo.contaDecidida,
  String para = 'adm',
  String titulo = 'Título',
  String descricao = 'Descrição',
  bool lida = false,
  String? entidadeId,
  String? dispositivoId,
  String? decisao,
  String? dataHora,
}) =>
    Notificacao(
      id: id,
      tipo: tipo,
      destinatarioUid: para,
      remetenteUid: 'sistema',
      titulo: titulo,
      descricao: descricao,
      dataHora: dataHora ?? agoraIso(),
      lida: lida,
      entidadeId: entidadeId,
      dispositivoId: dispositivoId,
      decisao: decisao,
    );

FakeBackend _admin() {
  final b = FakeBackend();
  b.criarUsuario('adm', perfil: 'admin', nome: 'Ana Admin', logar: true);
  return b;
}

String _local(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).last)).state.uri.toString();

void main() {
  testWidgets('lista notificações com destaque das não lidas e tempo relativo', (tester) async {
    final b = _admin();
    await b.notifications.criar(_notif('n1', titulo: 'Cadastro aprovado', decisao: 'aprovada'));
    await b.notifications.criar(_notif('n2', titulo: 'Antiga', lida: true, dataHora: '2026-01-01T10:00:00.000Z'));
    await pumpTela(tester, b, const NotificacoesScreen());

    expect(find.text('Todas (2)'), findsOneWidget);
    expect(find.text('Não lidas (1)'), findsOneWidget);
    expect(find.text('Cadastro aprovado'), findsOneWidget);
    expect(find.text('agora'), findsOneWidget);
    expect(find.text('Aprovada'), findsOneWidget);
    expect(find.text('Marcar todas como lidas'), findsOneWidget);
    expect(find.byTooltip('Marcar como lida'), findsOneWidget);
  });

  testWidgets('filtro de não lidas', (tester) async {
    final b = _admin();
    await b.notifications.criar(_notif('n1', titulo: 'Nova'));
    await b.notifications.criar(_notif('n2', titulo: 'Lida', lida: true));
    await pumpTela(tester, b, const NotificacoesScreen());

    await tocar(tester, find.text('Não lidas (1)'));
    expect(find.text('Nova'), findsOneWidget);
    expect(find.text('Lida'), findsNothing);
  });

  testWidgets('marcar uma como lida e marcar todas', (tester) async {
    final b = _admin();
    await b.notifications.criar(_notif('n1', titulo: 'Um'));
    await b.notifications.criar(_notif('n2', titulo: 'Dois'));
    await b.notifications.criar(_notif('n3', titulo: 'Três'));
    await pumpTela(tester, b, const NotificacoesScreen());

    await tocar(tester, find.byTooltip('Marcar como lida'));
    expect(b.notifications.itens.values.where((n) => n.lida), hasLength(1));
    expect(find.text('Não lidas (2)'), findsOneWidget);

    await tocar(tester, find.text('Marcar todas como lidas'));
    expect(b.notifications.itens.values.every((n) => n.lida), isTrue);
    expect(find.text('Marcar todas como lidas'), findsNothing);
    expect(find.byTooltip('Marcar como lida'), findsNothing);
  });

  testWidgets('cadastro pendente exige ação e abre a aba de cadastros destacada', (tester) async {
    final b = _admin();
    b.criarUsuario('conv', perfil: perfilConvidado, nome: 'Carlos Convidado', ativo: false, status: StatusAprovacao.pendente);
    await b.notifications.criar(_notif('nc',
        tipo: NotificacaoTipo.contaNova, titulo: 'Novo cadastro aguardando aprovação', entidadeId: 'conv'));
    await pumpApp(tester, b);

    await tocar(tester, find.byIcon(LucideIcons.bell));
    expect(find.text('Requer ação'), findsOneWidget);
    expect(find.text('1 aguardando ação'), findsOneWidget);
    expect(find.text('Pendente'), findsOneWidget);

    await tocar(tester, find.text('Analisar'));
    expect(b.notifications.itens['nc']!.lida, isTrue);
    expect(_local(tester), '/administracao?aba=cadastros&destaque=conv');
    expect(find.byType(AdministracaoScreen), findsOneWidget);
    expect(find.text('Carlos Convidado'), findsOneWidget);
    expect(find.text('Selecione o cargo...'), findsOneWidget);
  });

  testWidgets('solicitação de cargo leva à aba de cargos', (tester) async {
    final b = _admin();
    await b.notifications.criar(
        _notif('ns', tipo: NotificacaoTipo.cargoSolicitado, titulo: 'Solicitação de alteração de cargo', entidadeId: 'sol1'));
    await pumpApp(tester, b);

    await tocar(tester, find.byIcon(LucideIcons.bell));
    await tocar(tester, find.text('Solicitação de alteração de cargo'));
    expect(_local(tester), '/administracao?aba=cargos&destaque=sol1');
    expect(find.text('Pendentes (0)'), findsOneWidget);
  });

  testWidgets('reutilização abre a lista destacando a solicitação', (tester) async {
    final b = FakeBackend();
    b.semearDadosFabris();
    b.criarUsuario('proj', perfil: 'projetista', nome: 'Paula', logar: true);
    await b.notifications.criar(_notif('nr',
        tipo: NotificacaoTipo.reutilizacaoNova,
        para: 'proj',
        titulo: 'Nova solicitação de reutilização',
        entidadeId: 'r1',
        dispositivoId: 'd1'));
    await pumpApp(tester, b);

    await tocar(tester, find.byIcon(LucideIcons.bell));
    expect(find.text('Em análise'), findsOneWidget); // status vivo da reutilização
    expect(find.text('Requer ação'), findsOneWidget);
    await tocar(tester, find.text('Nova solicitação de reutilização'));
    expect(b.notifications.itens['nr']!.lida, isTrue);
    expect(_local(tester), '/reutilizacoes?destaque=r1');
  });

  testWidgets('decisão recebida só é marcada como lida (sem navegar)', (tester) async {
    final b = FakeBackend();
    b.criarUsuario('eng', perfil: 'engenharia', logar: true);
    await b.notifications.criar(_notif('nd',
        tipo: NotificacaoTipo.cargoDecidido, para: 'eng', titulo: 'Alteração de cargo rejeitada', decisao: 'rejeitada'));
    await pumpApp(tester, b);

    await tocar(tester, find.byIcon(LucideIcons.bell));
    expect(find.text('Rejeitada'), findsOneWidget);
    await tocar(tester, find.text('Alteração de cargo rejeitada'));
    expect(b.notifications.itens['nd']!.lida, isTrue);
    expect(_local(tester), '/notificacoes');
  });

  testWidgets('vazio e sem overflow em 360x740', (tester) async {
    final b = _admin();
    await pumpTela(tester, b, const NotificacoesScreen(), tamanho: const Size(360, 740));
    expect(find.text('Sem notificações.'), findsOneWidget);

    await b.notifications.criar(_notif('n1',
        tipo: NotificacaoTipo.contaNova,
        titulo: 'Novo cadastro aguardando aprovação com título comprido',
        descricao: 'Fulano de Tal (fulano.de.tal@baldan.com.br) criou uma conta e aguarda a definição de cargo.'));
    await assentar(tester);
    expect(tester.takeException(), isNull);
  });
}
