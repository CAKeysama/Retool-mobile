import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retoolapp/domain/entities/audit_log.dart';
import 'package:retoolapp/domain/repositories/repositories.dart';
import 'package:retoolapp/features/administracao/historico_auditoria_controller.dart';
import 'package:retoolapp/features/administracao/paineis/historico_acoes_panel.dart';

import '../../support/fakes.dart';
import '../../support/harness.dart';
import 'admin_test_utils.dart';

class _AuditoriaComErro extends FakeAuditLogRepository {
  @override
  Future<PaginaAuditoria> listarPagina(FiltrosAuditoria filtros, int tamanho, {Object? apos}) async =>
      throw StateError('failed-precondition: índice ausente');
}

Future<void> _semear(FakeBackend b, int n) async {
  for (var i = 1; i <= n; i++) {
    await registrarLog(b, 'Ação número $i');
  }
}

void main() {
  group('HistoricoAuditoriaController', () {
    test('pagina por cursor, conta o total e acumula ao carregar mais', () async {
      final b = FakeBackend();
      await _semear(b, 7);
      final h = HistoricoAuditoriaController(b.audit, 3);
      addTearDown(h.dispose);

      await h.recarregar();
      await Future<void>.delayed(Duration.zero);
      expect(h.estado, EstadoConsulta.pronto);
      expect(h.total, 7);
      expect(h.logs.map((l) => l.acaoDescricao), ['Ação número 7', 'Ação número 6', 'Ação número 5']);
      expect(h.temMais, isTrue);

      await h.carregarMais();
      await h.carregarMais();
      expect(h.logs, hasLength(7));
      expect(h.logs.last.acaoDescricao, 'Ação número 1');
      expect(h.temMais, isFalse);
    });

    test('filtros voltam para a primeira página', () async {
      final b = FakeBackend();
      await _semear(b, 4);
      await registrarLog(b, 'Login negado', acao: AuditLogAcao.login, resultado: AuditLogResultado.negado, uid: 'outro');
      final h = HistoricoAuditoriaController(b.audit, 2);
      addTearDown(h.dispose);

      h.aplicarFiltros(const FiltrosAuditoria(categoria: AuditLogCategoria.autenticacao));
      await Future<void>.delayed(Duration.zero);
      expect(h.logs.single.acaoDescricao, 'Login negado');
      expect(h.total, 1);
      expect(h.temFiltros, isTrue);
      expect(h.quantidadeFiltros, 1);

      h.aplicarFiltros(const FiltrosAuditoria(somenteFalhas: true, usuarioUid: 'outro'));
      await Future<void>.delayed(Duration.zero);
      expect(h.logs.single.resultado, AuditLogResultado.negado);
      expect(h.quantidadeFiltros, 2);

      h.aplicarFiltros(const FiltrosAuditoria(acao: AuditLogAcao.edicao));
      await Future<void>.delayed(Duration.zero);
      expect(h.total, 4);
      expect(h.logs, hasLength(2));
    });

    test('avisa quando chegam novos registros', () async {
      final b = FakeBackend();
      await _semear(b, 1);
      final h = HistoricoAuditoriaController(b.audit);
      addTearDown(h.dispose);
      await h.recarregar();
      await Future<void>.delayed(Duration.zero);
      expect(h.haNovos, isFalse);

      await registrarLog(b, 'Nova ação');
      await Future<void>.delayed(Duration.zero);
      expect(h.haNovos, isTrue);

      await h.recarregar();
      expect(h.haNovos, isFalse);
    });

    test('erro de índice vira mensagem amigável', () async {
      final h = HistoricoAuditoriaController(_AuditoriaComErro());
      addTearDown(h.dispose);
      await h.recarregar();
      expect(h.estado, EstadoConsulta.erro);
      expect(h.erro, contains('precisa de um índice no Firestore'));
    });

    test('detalhesJson formata conteúdo, dados anteriores e id', () {
      const log = AuditLog(
        id: 'log-9',
        dataHora: '2026-03-01T10:00:00.000Z',
        usuarioUid: 'u',
        usuarioNome: 'U',
        usuarioEmail: 'u@b.com',
        usuarioPerfil: 'admin',
        acao: AuditLogAcao.alteracaoPerfil,
        categoria: AuditLogCategoria.usuarios,
        tipoEntidade: AuditLogTipoEntidade.usuario,
        entidadeId: 'x',
        conteudo: {'perfilNovo': 'gerencia'},
        dadosAnteriores: {'perfil': 'engenharia'},
      );
      final json = detalhesJson(log);
      expect(json, contains('"perfilNovo": "gerencia"'));
      expect(json, contains('"dadosAnteriores"'));
      expect(json, contains('"registroId": "log-9"'));
      expect(json, isNot(contains('"detalhes"')));
    });
  });

  group('HistoricoAcoesPanel', () {
    Future<void> abrir(WidgetTester tester, FakeBackend b, {int tamanhoPagina = 25, Size tamanho = const Size(412, 915)}) =>
        pumpTela(tester, b, Scaffold(body: HistoricoAcoesPanel(tamanhoPagina: tamanhoPagina)), tamanho: tamanho);

    testWidgets('lista os registros com ação, resultado, usuário e recurso', (tester) async {
      final b = backendAdmin(comConvidado: false);
      await registrarLog(b, 'Editou o Gabarito', conteudo: {'campo': 'peso'});
      await registrarLog(b, 'Tentou excluir', acao: AuditLogAcao.exclusao, resultado: AuditLogResultado.negado);
      await abrir(tester, b);

      expect(find.text('2 registros'), findsOneWidget);
      expect(find.text('Editou o Gabarito'), findsOneWidget);
      expect(find.text('Tentou excluir'), findsOneWidget);
      expect(find.text('Edição'), findsOneWidget);
      expect(find.text('Exclusão'), findsOneWidget);
      expect(find.text('Sucesso'), findsOneWidget);
      expect(find.text('Negado'), findsOneWidget);
      expect(find.text('Eduardo Eng'), findsNWidgets(2));
      expect(find.text('ID: d1'), findsNWidgets(2));
    });

    testWidgets('cartão expande mostrando o JSON dos detalhes', (tester) async {
      final b = backendAdmin(comConvidado: false);
      await registrarLog(b, 'Editou o Gabarito', conteudo: {'campo': 'peso'});
      await abrir(tester, b);

      await tocar(tester, find.text('Editou o Gabarito'));
      final detalhes = find.descendant(of: find.byKey(const ValueKey('detalhes-log-0')), matching: find.byType(SelectableText));
      expect(tester.widget<SelectableText>(detalhes).data, contains('"campo": "peso"'));

      await tocar(tester, find.text('Editou o Gabarito'));
      expect(find.byKey(const ValueKey('detalhes-log-0')), findsNothing);
    });

    testWidgets('carregar mais busca a próxima página', (tester) async {
      final b = backendAdmin(comConvidado: false);
      await _semear(b, 5);
      await abrir(tester, b, tamanhoPagina: 3);

      expect(find.text('Exibindo 3 de 5 registros'), findsOneWidget);
      await tocar(tester, find.text('Carregar mais'));
      await tester.dragUntilVisible(
          find.text('Exibindo 5 de 5 registros'), find.byType(CustomScrollView), const Offset(0, -300));
      expect(find.text('Exibindo 5 de 5 registros'), findsOneWidget);
      expect(find.text('Ação número 1'), findsOneWidget);
      expect(find.text('Carregar mais'), findsNothing);
    });

    testWidgets('filtra pela categoria no painel de filtros e limpa', (tester) async {
      final b = backendAdmin(comConvidado: false);
      await _semear(b, 2);
      await registrarLog(b, 'Entrou no sistema', acao: AuditLogAcao.login);
      await abrir(tester, b);
      expect(find.text('3 registros'), findsOneWidget);

      await tocar(tester, find.byTooltip('Filtros'));
      await escolherNoDropdown(tester, find.text('Todas as categorias'), 'Autenticação');
      await tocar(tester, find.text('Aplicar filtros'));

      expect(find.text('1 registro'), findsOneWidget);
      expect(find.text('Entrou no sistema'), findsOneWidget);
      expect(find.text('Ação número 1'), findsNothing);

      await tocar(tester, find.text('Limpar filtros'));
      expect(find.text('3 registros'), findsOneWidget);
    });

    testWidgets('filtra somente falhas e por usuário', (tester) async {
      final b = backendAdmin(comConvidado: false);
      await _semear(b, 2);
      await registrarLog(b, 'Falhou', resultado: AuditLogResultado.falha);
      await abrir(tester, b);

      await tocar(tester, find.byTooltip('Filtros'));
      await escolherNoDropdown(tester, find.text('Todos os resultados'), 'Somente falhas e acessos negados');
      await escolherNoDropdown(tester, find.text('Todos os usuários'), 'Eduardo Eng (eduardo@baldan.com.br)');
      await tocar(tester, find.text('Aplicar filtros'));

      expect(find.text('1 registro'), findsOneWidget);
      expect(find.text('Falhou'), findsOneWidget);
    });

    testWidgets('busca local nos registros carregados', (tester) async {
      final b = backendAdmin(comConvidado: false);
      await _semear(b, 3);
      await abrir(tester, b);
      await tester.enterText(find.byType(TextField).first, 'número 2');
      await tester.pump(const Duration(milliseconds: 250));
      await assentar(tester);
      expect(find.text('Ação número 2'), findsOneWidget);
      expect(find.text('Ação número 1'), findsNothing);
      expect(find.text(' · 1 após a busca'), findsNothing); // dentro do Text.rich
      expect(find.textContaining('1 após a busca'), findsOneWidget);
    });

    testWidgets('aviso de novos registros e atualização', (tester) async {
      final b = backendAdmin(comConvidado: false);
      await _semear(b, 1);
      await abrir(tester, b);
      await registrarLog(b, 'Chegou agora');
      await assentar(tester);
      expect(find.text('Há novos registros no histórico.'), findsOneWidget);
      expect(find.text('Chegou agora'), findsNothing);

      await tocar(tester, find.text('Atualizar lista'));
      expect(find.text('Chegou agora'), findsOneWidget);
      expect(find.text('Há novos registros no histórico.'), findsNothing);
    });

    testWidgets('vazio sem registros', (tester) async {
      final b = backendAdmin(comConvidado: false);
      await abrir(tester, b);
      expect(find.text('Nenhuma ação registrada até o momento.'), findsOneWidget);
    });

    testWidgets('sem overflow em 360x740 com filtros abertos', (tester) async {
      final b = backendAdmin(comConvidado: false);
      await registrarLog(b, 'Uma descrição bem longa para testar a quebra de linha no cartão do histórico de ações',
          conteudo: {'lista': List.generate(30, (i) => 'item $i')});
      await abrir(tester, b, tamanho: const Size(360, 740));
      await tocar(tester, find.textContaining('Uma descrição bem longa'));
      await tocar(tester, find.byTooltip('Filtros'));
      expect(tester.takeException(), isNull);
    });
  });
}
