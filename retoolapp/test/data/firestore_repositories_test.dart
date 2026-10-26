import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retoolapp/data/repositories/firestore_repositories.dart';
import 'package:retoolapp/domain/entities/audit_log.dart';
import 'package:retoolapp/domain/entities/classificacao.dart';
import 'package:retoolapp/domain/entities/notificacao.dart';
import 'package:retoolapp/domain/entities/reutilizacao.dart';
import 'package:retoolapp/domain/entities/solicitacao_cargo.dart';
import 'package:retoolapp/domain/entities/user.dart';
import 'package:retoolapp/domain/repositories/repositories.dart';

/// Garante que o app grava exatamente no formato do desktop (mesmo banco).
void main() {
  late FakeFirebaseFirestore db;
  setUp(() => db = FakeFirebaseFirestore());

  group('Dispositivos', () {
    test('add grava id, dataCriacao ISO e omite nulos', () async {
      final repo = FirestoreDispositivosRepository(db);
      final id = await repo.add({'nome': 'Gabarito', 'codigo': 'G-1', 'peso': null, 'palavrasChave': ['a']});
      final doc = (await db.collection('dispositivos').doc(id).get()).data()!;
      expect(doc['id'], id);
      expect(doc['nome'], 'Gabarito');
      expect(doc.containsKey('peso'), isFalse);
      expect(doc['dataCriacao'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$')));
    });

    test('watchAll converte documentos legados', () async {
      await db.collection('dispositivos').doc('legado').set({'codigo': 41, 'nome': 'X'});
      final lista = await FirestoreDispositivosRepository(db).watchAll().first;
      expect(lista.single.codigo, '41');
      expect(lista.single.ativo, isTrue);
    });

    test('importarLote cria classificações sem duplicar e faz merge por Código + Dispositivo', () async {
      final repo = FirestoreDispositivosRepository(db);
      await db.collection('dispositivos').doc('existente').set({
        'id': 'existente',
        'codigo': 'A1',
        'nome': 'Gabarito',
        'imagemPeca': 'https://img/peca.png',
        'dataCriacao': '2026-01-01T00:00:00.000Z',
      });
      final r = await repo.importarLote(
        novosDispositivos: [
          {'codigo': ' a1 ', 'nome': 'GABARITO', 'peso': '12', 'categoriaId': 'Ferramentas', 'imagemPeca': ''},
          {'codigo': 'A1', 'nome': 'Outro', 'categoriaId': 'ferramentas '},
          {'codigo': 'B2', 'nome': 'Novo', 'familiaId': 'Colheita'},
          {'codigo': 'B2', 'nome': 'novo', 'peso': '3'},
        ],
        novasCategorias: ['Ferramentas', 'ferramentas '],
        novasFamilias: ['Colheita'],
        novosProdutos: const [],
        categoriasExistentes: const [],
        familiasExistentes: const [Classificacao(id: 'fam-x', nome: 'colheita')],
        produtosExistentes: const [],
      );
      expect(r.erros, 0);
      expect(r.atualizados, 2); // existente + repetição de B2 na própria lista
      expect(r.inseridos, 2);
      final cats = await db.collection('categorias').get();
      expect(cats.docs, hasLength(1));
      expect(await db.collection('familias').get().then((s) => s.docs), isEmpty);

      final existente = (await db.collection('dispositivos').doc('existente').get()).data()!;
      expect(existente['peso'], '12');
      expect(existente['imagemPeca'], 'https://img/peca.png'); // imagem preservada
      expect(existente['categoriaId'], cats.docs.single.id);

      final todos = (await db.collection('dispositivos').get()).docs.map((d) => d.data()).toList();
      expect(todos, hasLength(3));
      final novo = todos.firstWhere((d) => d['codigo'] == 'B2');
      expect(novo['familiaId'], 'fam-x');
      expect(novo['peso'], '3');
    });

    test('excluirEmLote remove todos', () async {
      final repo = FirestoreDispositivosRepository(db);
      final ids = [for (var i = 0; i < 3; i++) await repo.add({'nome': 'd$i'})];
      final r = await repo.excluirEmLote(ids);
      expect(r.excluidos, 3);
      expect((await db.collection('dispositivos').get()).docs, isEmpty);
    });
  });

  group('Reutilizações', () {
    test('status é gravado com o texto do desktop e legado é normalizado', () async {
      final repo = FirestoreReutilizacoesRepository(db);
      final id = await repo.add({'dispositivoId': 'd1', 'status': ReutilizacaoStatus.emAnaliseEngenharia.valor, 'hardSaving': 10.5});
      final doc = (await db.collection('reutilizacoes').doc(id).get()).data()!;
      expect(doc['status'], 'Em análise (Engenharia)');
      expect(doc['hardSaving'], 10.5);
      await db.collection('reutilizacoes').doc('velho').set({'dispositivoId': 'd1', 'status': 'pendente'});
      final lista = await repo.watchAll().first;
      expect(lista.firstWhere((r) => r.id == 'velho').status, ReutilizacaoStatus.emAnaliseProjetista);
    });
  });

  group('Classificações', () {
    test('ordena por nome sem acento e grava {id, nome, ativo}', () async {
      final repo = FirestoreClassificacoesRepository(db);
      await repo.add(TipoClassificacao.produto, nome: 'Zeta');
      final id = await repo.add(TipoClassificacao.produto, nome: 'Ábaco');
      final doc = (await db.collection('produtos').doc(id).get()).data()!;
      expect(doc, {'id': id, 'nome': 'Ábaco', 'ativo': true});
      final lista = await repo.watchAll(TipoClassificacao.produto).first;
      expect(lista.map((c) => c.nome), ['Ábaco', 'Zeta']);
    });
  });

  group('Usuários', () {
    test('lista só administradores ativos e grava perfil sem nulos', () async {
      final repo = FirestoreUsersRepository(db);
      await repo.setProfile(const UserProfile(uid: 'a', email: 'a@x', nome: 'A', perfil: 'admin', ativo: true));
      await repo.setProfile(const UserProfile(uid: 'b', email: 'b@x', nome: 'B', perfil: 'admin', ativo: false));
      await repo.setProfile(const UserProfile(uid: 'c', email: 'c@x', nome: 'C', perfil: 'projetista', ativo: true));
      expect((await repo.listarAdministradoresAtivos()).map((u) => u.uid), ['a']);
      final doc = (await db.collection('users').doc('a').get()).data()!;
      expect(doc.containsKey('statusAprovacao'), isFalse);
      await repo.updateRole('c', UserRole.gerencia);
      expect((await repo.getProfile('c'))!.perfil, 'gerencia');
    });
  });

  group('Solicitações de cargo', () {
    test('cria com trava e decide em lote atômico', () async {
      final repo = FirestoreSolicitacoesCargoRepository(db);
      await db.collection('users').doc('u').set({'perfil': 'engenharia', 'ativo': true});
      const s = SolicitacaoCargo(
          id: 's1', usuarioUid: 'u', usuarioNome: 'U', usuarioEmail: 'u@x', perfilAtual: UserRole.engenharia, perfilSolicitado: UserRole.projetista, dataSolicitacao: '2026-01-01T00:00:00.000Z');
      await repo.criar(s);
      expect((await repo.obterPendenteDoUsuario('u'))!.id, 's1');
      await repo.decidir(s, const DecisaoSolicitacaoCargo(
          status: SolicitacaoCargoStatus.aprovada, decididoPorUid: 'adm', decididoPorNome: 'Adm', dataDecisao: '2026-01-02T00:00:00.000Z'));
      expect((await db.collection('users').doc('u').get()).data()!['perfil'], 'projetista');
      expect((await db.collection('pendencias_cargo').doc('u').get()).exists, isFalse);
      expect(await repo.obterPendenteDoUsuario('u'), isNull);
      expect((await repo.obter('s1'))!.status, SolicitacaoCargoStatus.aprovada);
    });
  });

  group('Notificações', () {
    test('filtra por destinatário, ordena e marca lida', () async {
      final repo = FirestoreNotificationsRepository(db);
      for (final (id, dest, data) in [('1', 'a', '2026-01-01'), ('2', 'a', '2026-02-01'), ('3', 'b', '2026-03-01')]) {
        await repo.criar(Notificacao(
            id: id, tipo: NotificacaoTipo.reutilizacaoNova, destinatarioUid: dest, remetenteUid: 'x', titulo: 't', descricao: 'd', dataHora: data));
      }
      final lista = await repo.watchParaUsuario('a').first;
      expect(lista.map((n) => n.id), ['2', '1']);
      await repo.marcarLida('1', true);
      expect((await db.collection('notifications').doc('1').get()).data()!['lida'], isTrue);
    });
  });

  group('Auditoria', () {
    test('registra com dataHora ISO, servidor, sem segredos; pagina e conta', () async {
      final repo = FirestoreAuditLogRepository(db);
      for (var i = 0; i < 5; i++) {
        await repo.registrarLog(AuditLogInput(
          usuarioUid: 'u',
          usuarioNome: 'U',
          usuarioEmail: 'u@x',
          usuarioPerfil: 'admin',
          acao: i.isEven ? AuditLogAcao.login : AuditLogAcao.edicao,
          tipoEntidade: AuditLogTipoEntidade.sessao,
          entidadeId: 'e$i',
          conteudo: {'senha': 'nao-pode', 'ok': i},
        ));
      }
      final docs = (await db.collection('audit_logs').get()).docs;
      expect(docs, hasLength(5));
      final d = docs.first.data();
      expect(d['dataHora'], isA<String>());
      expect(d['dataHoraServidor'], isA<Timestamp>());
      expect((d['conteudo'] as Map).containsKey('senha'), isFalse);
      expect(d['categoria'], anyOf('autenticacao', 'dados'));

      final p1 = await repo.listarPagina(const FiltrosAuditoria(), 2);
      expect(p1.logs, hasLength(2));
      expect(p1.temMais, isTrue);
      final p2 = await repo.listarPagina(const FiltrosAuditoria(), 2, apos: p1.cursor);
      expect(p2.logs.map((l) => l.id).toSet().intersection(p1.logs.map((l) => l.id).toSet()), isEmpty);
      expect(await repo.contar(const FiltrosAuditoria(acao: AuditLogAcao.login)), 3);
      expect(await repo.contar(const FiltrosAuditoria(categoria: AuditLogCategoria.dados)), 2);
    });
  });
}
