import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:retoolapp/core/router/rotas.dart';
import 'package:retoolapp/domain/entities/audit_log.dart';
import 'package:retoolapp/domain/entities/notificacao.dart';
import 'package:retoolapp/domain/entities/reutilizacao.dart';
import 'package:retoolapp/features/dispositivos/dispositivo_detalhes_screen.dart';
import 'package:retoolapp/features/reutilizacoes/reutilizacoes_logica.dart';
import 'package:retoolapp/features/reutilizacoes/reutilizacoes_screen.dart';
import 'package:retoolapp/features/reutilizacoes/widgets/abas_pilula.dart';
import 'package:retoolapp/features/reutilizacoes/widgets/cartao_reutilizacao.dart';

import '../../support/fakes.dart';
import '../../support/harness.dart';

FakeBackend _backend(String perfil, {String uid = 'eu'}) {
  final b = FakeBackend()..semearDadosFabris();
  b.criarUsuario('eng1', perfil: 'engenharia', nome: 'Engenheiro');
  b.criarUsuario('proj1', perfil: 'projetista', nome: 'Paula Projetista');
  b.criarUsuario('adm1', perfil: 'admin', nome: 'Ana Admin');
  b.criarUsuario(uid, perfil: perfil, nome: 'Eu Mesmo', logar: true);
  return b;
}

Finder _cartao(String id) => find.byKey(ValueKey('reu-$id'));
Finder _aba(AbaReutilizacoes a) => find.byKey(ValueKey('aba-${a.name}'));
Finder _noDialogo(String texto) => find.descendant(of: find.byType(AlertDialog), matching: find.text(texto));

AbaReutilizacoes _abaAtiva(WidgetTester t) => t.widget<AbasPilula>(find.byType(AbasPilula)).ativa;

void main() {
  group('abas visíveis por perfil', () {
    for (final (perfil, esperadas) in [
      ('admin', ['Fila do Projetista (1)', 'Fila da Engenharia (1)', 'Histórico Geral']),
      ('projetista', ['Fila do Projetista (1)', 'Histórico Geral']),
      ('engenharia', ['Fila da Engenharia (1)', 'Histórico Geral']),
      ('gerencia', ['Histórico Geral']),
    ]) {
      testWidgets(perfil, (tester) async {
        await pumpTela(tester, _backend(perfil), const ReutilizacoesScreen());
        final textos = tester
            .widgetList<Text>(find.descendant(of: find.byType(AbasPilula), matching: find.byType(Text)))
            .map((t) => t.data)
            .toList();
        expect(textos, esperadas);
      });
    }
  });

  testWidgets('Projetista aprova: status, auditoria e notificação ao solicitante', (tester) async {
    final b = _backend('projetista');
    final c = await pumpTela(tester, b, const ReutilizacoesScreen());
    expect(find.text('Pendências'), findsOneWidget, reason: 'banner para quem aprova');
    expect(find.textContaining('1 solicitação aguarda sua análise'), findsOneWidget);

    await tocar(tester, find.byKey(const ValueKey('acao-r1-aprovada')));

    expect(b.reutilizacoes.itens['r1']!.status, ReutilizacaoStatus.aprovada);
    expect(b.reutilizacoes.itens['r1']!.aprovadorId, 'eu');
    final log = b.audit.registros.last;
    expect(log.acao, AuditLogAcao.aprovacao);
    expect(log.acaoDescricao, 'Aprovou Reutilização');
    final n = b.notifications.itens.values.where((n) => n.destinatarioUid == 'eng1').single;
    expect(n.tipo, NotificacaoTipo.reutilizacaoDecidida);
    expect(n.titulo, 'Reutilização aprovada');
    expect(c.anuncios.last, 'Status atualizado: Reutilização aprovada');
    // Saiu da fila do Projetista.
    expect(_cartao('r1'), findsNothing);
    expect(find.text('Sem pendências no momento.'), findsOneWidget);
  });

  testWidgets('reprovar exige motivo e grava motivoRejeicao', (tester) async {
    final b = _backend('projetista');
    await pumpTela(tester, b, const ReutilizacoesScreen());

    await tocar(tester, find.byKey(const ValueKey('acao-r1-naoAprovada')));
    expect(find.text('Informe o motivo da não aprovação:'), findsOneWidget);

    // Sem motivo o botão fica desabilitado.
    await tocar(tester, _noDialogo('Não Aprovar'));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(b.reutilizacoes.itens['r1']!.status, ReutilizacaoStatus.emAnaliseProjetista);

    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextFormField)),
        'Peça fora de tolerância');
    await tester.pump();
    await tocar(tester, _noDialogo('Não Aprovar'));

    final r = b.reutilizacoes.itens['r1']!;
    expect(r.status, ReutilizacaoStatus.naoAprovada);
    expect(r.motivoRejeicao, 'Peça fora de tolerância');
    expect(b.audit.registros.last.acao, AuditLogAcao.rejeicao);
    final n = b.notifications.itens.values.where((n) => n.destinatarioUid == 'eng1').single;
    expect(n.descricao, contains('Motivo: Peça fora de tolerância'));
  });

  testWidgets('cancelar o motivo não altera o status', (tester) async {
    final b = _backend('projetista');
    await pumpTela(tester, b, const ReutilizacoesScreen());
    await tocar(tester, find.byKey(const ValueKey('acao-r1-naoAprovada')));
    await tocar(tester, _noDialogo('Cancelar'));
    expect(b.reutilizacoes.itens['r1']!.status, ReutilizacaoStatus.emAnaliseProjetista);
  });

  testWidgets('Engenharia envia ao Projetista e notifica aprovadores ativos', (tester) async {
    final b = _backend('engenharia');
    b.criarUsuario('proj2', perfil: 'projetista', ativo: false);
    b.reutilizacoes.seed(const [
      Reutilizacao(
        id: 'r3',
        dispositivoId: 'd2',
        descricaoAlteracao: 'Novo furo',
        status: ReutilizacaoStatus.emAnaliseEngenharia,
        solicitanteId: 'eu',
        dataCriacao: '2026-03-01T10:00:00.000Z',
      ),
    ]);
    await pumpTela(tester, b, const ReutilizacoesScreen());
    expect(_abaAtiva(tester), AbaReutilizacoes.filaEngenharia);
    expect(find.text('Solicitar Análise (1º Filtro)'), findsOneWidget);

    await tocar(tester, find.text('Solicitar Análise (1º Filtro)'));

    expect(b.reutilizacoes.itens['r3']!.status, ReutilizacaoStatus.emAnaliseProjetista);
    expect(b.audit.registros.last.acaoDescricao, 'Solicitou análise do Projetista (1º filtro)');
    final destinos = b.notifications.itens.values
        .where((n) => n.tipo == NotificacaoTipo.reutilizacaoNova)
        .map((n) => n.destinatarioUid)
        .toSet();
    expect(destinos, {'proj1', 'adm1'});
  });

  testWidgets('Engenharia pede novo filtro após reprovação', (tester) async {
    final b = _backend('engenharia');
    b.reutilizacoes.seed(const [
      Reutilizacao(
        id: 'r4',
        dispositivoId: 'd1',
        descricaoAlteracao: 'Troca de bucha',
        status: ReutilizacaoStatus.naoAprovada,
        motivoRejeicao: 'Sem estoque',
        solicitanteId: 'eu',
        dataCriacao: '2026-03-02T10:00:00.000Z',
      ),
    ]);
    await pumpTela(tester, b, const ReutilizacoesScreen());
    expect(find.text('Motivo: Sem estoque'), findsOneWidget);

    await tocar(tester, find.byKey(const ValueKey('acao-r4-aguardandoNovoFiltro')));

    expect(b.reutilizacoes.itens['r4']!.status, ReutilizacaoStatus.aguardandoNovoFiltro);
    expect(b.audit.registros.last.acao, AuditLogAcao.transicao);
    expect(
        b.notifications.itens.values
            .where((n) => n.tipo == NotificacaoTipo.reutilizacaoNova)
            .map((n) => n.destinatarioUid)
            .toSet(),
        {'proj1', 'adm1'});
  });

  testWidgets('Projetista decide o 2º filtro (Liberar Fabricação)', (tester) async {
    final b = _backend('projetista');
    b.reutilizacoes.seed(const [
      Reutilizacao(
        id: 'r5',
        dispositivoId: 'd1',
        status: ReutilizacaoStatus.aguardandoNovoFiltro,
        solicitanteId: 'eng1',
        dataCriacao: '2026-03-03T10:00:00.000Z',
      ),
    ]);
    await pumpTela(tester, b, const ReutilizacoesScreen());
    expect(find.text('Similar Encontrado'), findsOneWidget);
    await tocar(tester, find.text('Liberar Fabricação'));
    expect(b.reutilizacoes.itens['r5']!.status, ReutilizacaoStatus.liberadoFabricacao);
    expect(b.notifications.itens.values.any((n) => n.titulo == 'Liberado para fabricação'), isTrue);
  });

  testWidgets('Gerência só consulta: sem botões de ação nem exclusão', (tester) async {
    final b = _backend('gerencia');
    await pumpTela(tester, b, const ReutilizacoesScreen());
    expect(_abaAtiva(tester), AbaReutilizacoes.historico);
    expect(_cartao('r1'), findsOneWidget);
    for (final t in ['Aprovar', 'Não Aprovar', 'Solicitar Análise (1º Filtro)', 'Ações em Massa', 'Pendências']) {
      expect(find.text(t), findsNothing);
    }
    await tocar(tester, find.text('Usinagem de 2 furos'));
    expect(find.text('Ver Dispositivo'), findsOneWidget);
    expect(find.text('Excluir'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('cartão expandido mostra peça, produto, hard saving e datas', (tester) async {
    final b = _backend('projetista');
    await pumpTela(tester, b, const ReutilizacoesScreen());
    expect(find.textContaining('Gabarito de Furação Lateral'), findsOneWidget);
    expect(find.textContaining('18.500,00'), findsOneWidget);
    expect(find.text('10/02/2026'), findsWidgets);

    await tocar(tester, find.text('Usinagem de 2 furos'));
    expect(tester.widget<CartaoReutilizacao>(_cartao('r1')).expandido, isTrue);
    expect(find.text('PC-5501 — Suporte Direito'), findsOneWidget);
    expect(find.text('SPE 5500'), findsOneWidget);
    expect(find.text('2,150 kg'), findsOneWidget);
    expect(find.text('Luiz Ramos'), findsOneWidget);
  });

  group('Histórico Geral', () {
    testWidgets('busca e filtros (status pelo bottom sheet)', (tester) async {
      final b = _backend('projetista');
      await pumpTela(tester, b, const ReutilizacoesScreen());
      await tocar(tester, _aba(AbaReutilizacoes.historico));
      expect(find.text('2 registros'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'pc-1000');
      await assentar(tester);
      expect(_cartao('r2'), findsOneWidget);
      expect(_cartao('r1'), findsNothing);
      expect(find.text('1 registro'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'inexistente');
      await assentar(tester);
      expect(find.text('Nenhum registro encontrado para os filtros atuais.'), findsOneWidget);
      await tocar(tester, find.text('Limpar filtros'));
      expect(find.text('2 registros'), findsOneWidget);

      await tocar(tester, find.byKey(const ValueKey('abrir-filtros')));
      await tocar(tester, find.byKey(const ValueKey('filtro-status-0')));
      await tocar(tester, find.text('Reutilização aprovada').last);
      await tocar(tester, find.text('Aplicar filtros'));

      expect(_cartao('r2'), findsOneWidget);
      expect(_cartao('r1'), findsNothing);
      expect(find.byType(InputChip), findsOneWidget);
      await tocar(tester, find.byTooltip('Remover filtro'));
      expect(find.text('2 registros'), findsOneWidget);
    });

    testWidgets('não mostra ações de fluxo no histórico', (tester) async {
      final b = _backend('admin');
      await pumpTela(tester, b, const ReutilizacoesScreen());
      await tocar(tester, _aba(AbaReutilizacoes.historico));
      expect(find.text('Aprovar'), findsNothing);
    });

    testWidgets('exclusão só para a Administração', (tester) async {
      final b = _backend('projetista');
      await pumpTela(tester, b, const ReutilizacoesScreen());
      await tocar(tester, _aba(AbaReutilizacoes.historico));
      await tocar(tester, find.text('Ajuste'));
      expect(find.text('Excluir'), findsNothing);
      expect(find.text('Ações em Massa'), findsNothing);
    });

    testWidgets('admin exclui um registro com confirmação', (tester) async {
      final b = _backend('admin');
      await pumpTela(tester, b, const ReutilizacoesScreen());
      await tocar(tester, _aba(AbaReutilizacoes.historico));
      await tocar(tester, find.text('Ajuste'));
      await tocar(tester, find.byKey(const ValueKey('excluir-r2')));
      expect(find.text('Excluir reutilização'), findsOneWidget);
      await tocar(tester, _noDialogo('Excluir'));

      expect(b.reutilizacoes.itens.containsKey('r2'), isFalse);
      expect(b.audit.registros.last.acao, AuditLogAcao.exclusao);
      expect(_cartao('r2'), findsNothing);
    });

    testWidgets('admin: ações em massa com barra de progresso', (tester) async {
      final b = _backend('admin');
      b.reutilizacoes.seed([
        for (var i = 0; i < 23; i++)
          Reutilizacao(
            id: 'm$i',
            dispositivoId: 'd2',
            descricaoAlteracao: 'Massa $i',
            status: ReutilizacaoStatus.aprovada,
            dataCriacao: '2025-01-${(i + 1).toString().padLeft(2, '0')}T10:00:00.000Z',
          ),
      ]);
      final c = await pumpTela(tester, b, const ReutilizacoesScreen());
      await tocar(tester, _aba(AbaReutilizacoes.historico));
      await tocar(tester, find.text('Ações em Massa'));
      expect(find.text('Selecione itens e aplique uma ação'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Buscar item...'), 'massa');
      await tester.pump();
      await tocar(tester, find.text('Selecionar todos (23)'));
      expect(find.text(' selecionados'), findsNothing);
      await tocar(tester, find.text('Excluir').last);
      await tester.tap(_noDialogo('Excluir 23'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Progresso em lotes; o modo silencioso dá um único aviso no fim.
      expect(find.text('Não feche esta janela'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await assentar(tester, quadros: 20);

      expect(b.reutilizacoes.itens.keys.where((k) => k.startsWith('m')), isEmpty);
      expect(b.reutilizacoes.itens.keys, containsAll(['r1', 'r2']));
      expect(c.anuncios.last, '23 reutilizações excluídas com sucesso');
      expect(c.anuncios.where((a) => a == 'Reutilização removida com sucesso'), isEmpty);
      expect(find.text('Selecione itens e aplique uma ação'), findsNothing);
    });

    testWidgets('seleção pelos cartões aparece na contagem', (tester) async {
      final b = _backend('admin');
      await pumpTela(tester, b, const ReutilizacoesScreen());
      await tocar(tester, _aba(AbaReutilizacoes.historico));
      await tocar(tester, find.byType(Checkbox));
      expect(find.textContaining('1 selecionado(s)'), findsOneWidget);
    });
  });

  testWidgets('ajuda abre o fluxo de aceite', (tester) async {
    final b = _backend('engenharia');
    await pumpTela(tester, b, const ReutilizacoesScreen());
    await tocar(tester, find.byTooltip('Como funciona o fluxo'));
    expect(find.text('Como funciona o fluxo de aceite'), findsOneWidget);
    expect(find.text('1. Solicitação'), findsOneWidget);
    expect(find.text('Permissões por perfil'), findsOneWidget);
    await tocar(tester, find.text('Entendi'));
    expect(find.text('Como funciona o fluxo de aceite'), findsNothing);
  });

  testWidgets('carregando mostra esqueleto', (tester) async {
    final b = FakeBackend();
    b.criarUsuario('conv', perfil: 'convidado', logar: true);
    await pumpTela(tester, b, const ReutilizacoesScreen());
    expect(find.byKey(const ValueKey('reu-r1')), findsNothing);
    expect(find.text('Histórico Geral'), findsOneWidget);
  });

  group('destaque vindo de notificação', () {
    testWidgets('Projetista: abre a fila e destaca', (tester) async {
      final b = _backend('projetista');
      await pumpTela(tester, b, const ReutilizacoesScreen(destaqueId: 'r1'));
      expect(_abaAtiva(tester), AbaReutilizacoes.filaProjetista);
      expect(tester.widget<CartaoReutilizacao>(_cartao('r1')).destacado, isTrue);
    });

    testWidgets('Engenharia: registro em análise do Projetista abre o histórico expandido', (tester) async {
      final b = _backend('engenharia');
      await pumpTela(tester, b, const ReutilizacoesScreen(destaqueId: 'r1'));
      expect(_abaAtiva(tester), AbaReutilizacoes.historico);
      final cartao = tester.widget<CartaoReutilizacao>(_cartao('r1'));
      expect(cartao.destacado, isTrue);
      expect(cartao.expandido, isTrue);
    });

    testWidgets('rola até um cartão fora da tela', (tester) async {
      final b = _backend('projetista');
      b.reutilizacoes.seed([
        for (var i = 0; i < 40; i++)
          Reutilizacao(
            id: 'f$i',
            dispositivoId: 'd1',
            descricaoAlteracao: 'Pedido $i',
            status: ReutilizacaoStatus.emAnaliseProjetista,
            dataCriacao: '2026-09-${(i % 28 + 1).toString().padLeft(2, '0')}T${(i % 24).toString().padLeft(2, '0')}:00:00.000Z',
          ),
      ]);
      await pumpTela(tester, b, const ReutilizacoesScreen(destaqueId: 'r1'), tamanho: const Size(360, 740));
      await assentar(tester);
      expect(_cartao('r1'), findsOneWidget);
      expect(tester.widget<CartaoReutilizacao>(_cartao('r1')).destacado, isTrue);
      final r = tester.getRect(_cartao('r1'));
      expect(r.top, lessThan(740));
      expect(r.bottom, greaterThan(0));
    });

    testWidgets('pelo router (pumpApp) e toque no dispositivo abre o detalhe', (tester) async {
      final b = _backend('admin');
      await pumpApp(tester, b);
      final ctx = tester.element(find.byType(NavigationBar));
      GoRouter.of(ctx).go(Rotas.reutilizacao('r2'));
      await assentar(tester);

      expect(_abaAtiva(tester), AbaReutilizacoes.filaEngenharia, reason: 'aprovada fica na Fila da Engenharia');
      expect(tester.widget<CartaoReutilizacao>(_cartao('r2')).destacado, isTrue);

      // Notificação nova com a tela já aberta.
      GoRouter.of(ctx).go(Rotas.reutilizacao('r1'));
      await assentar(tester);
      expect(_abaAtiva(tester), AbaReutilizacoes.filaProjetista);
      expect(tester.widget<CartaoReutilizacao>(_cartao('r1')).destacado, isTrue);

      await tocar(tester, find.textContaining('Gabarito de Furação Lateral'));
      final detalhe = tester.widget<DispositivoDetalhesScreen>(find.byType(DispositivoDetalhesScreen));
      expect(detalhe.id, 'd1');
    });
  });

  testWidgets('sem overflow em 360x740 em todas as abas', (tester) async {
    final b = _backend('admin');
    b.reutilizacoes.seed(const [
      Reutilizacao(
        id: 'longo',
        dispositivoId: 'd1',
        codigoPeca: 'PC-COM-UM-CODIGO-MUITO-LONGO-0000000001',
        descricaoPeca: 'Descrição extensa da peça para testar quebras',
        descricaoAlteracao:
            'Alteração com um texto muito comprido que precisa quebrar linha sem estourar o layout no celular pequeno',
        status: ReutilizacaoStatus.naoAprovada,
        motivoRejeicao: 'Motivo longo de reprovação que ocupa bastante espaço horizontal no cartão',
        hardSaving: 123456789.99,
        solicitanteNome: 'Fulano de Tal com Nome Bem Comprido da Silva',
        aprovadorNome: 'Projetista com Nome Comprido',
        dataAprovacao: '2026-03-10T10:00:00.000Z',
        dataCriacao: '2026-03-09T10:00:00.000Z',
      ),
    ]);
    await pumpTela(tester, b, const ReutilizacoesScreen(), tamanho: const Size(360, 740));
    await tocar(tester, _aba(AbaReutilizacoes.filaEngenharia));
    await tocar(tester, find.textContaining('Alteração com um texto').first);
    await tocar(tester, _aba(AbaReutilizacoes.historico));
    await tocar(tester, find.textContaining('Alteração com um texto').first);
    await tocar(tester, find.text('Ações em Massa'));
    await tocar(tester, find.byTooltip('Fechar'));
    await tocar(tester, find.byKey(const ValueKey('abrir-filtros')));
    await tocar(tester, find.byTooltip('Fechar'));
    await tocar(tester, find.byTooltip('Como funciona o fluxo'));
    await tester.drag(find.text('1. Solicitação'), const Offset(0, -1500));
    await assentar(tester);
    expect(tester.takeException(), isNull);
  });
}
