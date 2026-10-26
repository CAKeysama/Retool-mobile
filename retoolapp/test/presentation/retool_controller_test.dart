import 'package:flutter_test/flutter_test.dart';
import 'package:retoolapp/core/router/app_router.dart';
import 'package:retoolapp/core/router/rotas.dart';
import 'package:retoolapp/domain/entities/audit_log.dart';
import 'package:retoolapp/domain/entities/classificacao.dart';
import 'package:retoolapp/domain/entities/dispositivo.dart';
import 'package:retoolapp/domain/entities/notificacao.dart';
import 'package:retoolapp/domain/entities/reutilizacao.dart';
import 'package:retoolapp/domain/entities/user.dart';
import 'package:retoolapp/presentation/state/auth_controller.dart';
import 'package:retoolapp/presentation/state/retool_controller.dart';

import '../support/fakes.dart';

Future<void> _ciclo() => Future<void>.delayed(Duration.zero);

/// Monta controladores logados com o perfil pedido e dados de exemplo.
Future<(FakeBackend, AuthController, ReToolController, List<String>)> montar(String perfil) async {
  final b = FakeBackend()..semearDadosFabris();
  b.criarUsuario('proj1', perfil: 'projetista');
  b.criarUsuario('adm9', perfil: 'admin');
  b.criarUsuario('eng1', perfil: 'engenharia');
  b.criarUsuario('eu', perfil: perfil, nome: 'Eu Mesmo', logar: true);
  final anuncios = <String>[];
  final auth = AuthController(b.deps);
  final retool = ReToolController(b.deps, auth, announce: anuncios.add);
  for (var i = 0; i < 5; i++) {
    await _ciclo();
  }
  addTearDown(() {
    retool.dispose();
    auth.dispose();
  });
  return (b, auth, retool, anuncios);
}

void main() {
  group('Sincronização', () {
    test('conta operacional assina coleções e monta índices', () async {
      final (_, auth, retool, _) = await montar('engenharia');
      expect(auth.isOperacional, isTrue);
      expect(retool.dispositivos, hasLength(3));
      expect(retool.categoria('cat-1')!.nome, 'Gabaritos');
      expect(retool.reutilizacoesDo('d1').map((r) => r.id), ['r1', 'r2']); // mais recente primeiro
      expect(retool.dispositivosCarregados, isTrue);
    });

    test('logout limpa os dados', () async {
      final (_, auth, retool, _) = await montar('engenharia');
      await auth.logout();
      await _ciclo();
      expect(retool.dispositivos, isEmpty);
    });

    test('busca multidimensional tolera acentos e usa classificações', () async {
      final (_, _, retool, _) = await montar('gerencia');
      expect(retool.buscarDispositivos('valvula').map((d) => d.id), ['d2']);
      expect(retool.buscarDispositivos('preparo de solo').map((d) => d.id), ['d1']); // família
      expect(retool.buscarDispositivos('avola').map((d) => d.id), ['d2']); // produto
      expect(retool.buscarDispositivos('furacao').map((d) => d.id), ['d1']); // tag
      expect(retool.buscarDispositivos('14,5').map((d) => d.id), ['d1']); // peso com vírgula
      expect(retool.buscarDispositivos(''), hasLength(3));
    });
  });

  group('Permissões nas mutações', () {
    test('engenharia não cadastra dispositivo', () async {
      final (b, _, retool, anuncios) = await montar('engenharia');
      final id = await retool.addDispositivo({'nome': 'X'});
      expect(id, isNull);
      expect(b.dispositivos.itens, hasLength(3));
      expect(anuncios.last, contains('Acesso negado'));
    });

    test('projetista não exclui', () async {
      final (b, _, retool, anuncios) = await montar('projetista');
      await retool.deleteDispositivo('d1');
      expect(b.dispositivos.itens.containsKey('d1'), isTrue);
      expect(anuncios.last, contains('Apenas Administradoras'));
    });

    test('gerência não solicita reutilização', () async {
      final (b, _, retool, _) = await montar('gerencia');
      await retool.solicitarReutilizacao({'dispositivoId': 'd1'});
      expect(b.reutilizacoes.itens, hasLength(2));
    });
  });

  group('Dispositivos', () {
    test('cadastro audita e herda imagem da mesma linha', () async {
      final (b, _, retool, _) = await montar('projetista');
      await b.dispositivos.update('d2', {'imagemDispositivo': 'https://img/linha.png'});
      await _ciclo();
      final id = await retool.addDispositivo({'nome': 'Variante', 'codigo': ' val-0007 '});
      await _ciclo();
      expect(b.dispositivos.itens[id]!.imagemDispositivo, 'https://img/linha.png');
      expect(b.audit.registros.any((l) => l.acao == AuditLogAcao.criacao && l.entidadeId == id), isTrue);
      expect(b.audit.registros.any((l) => l.acaoDescricao!.contains('herdada')), isTrue);
    });

    test('exclusão remove reutilizações vinculadas e audita com dados anteriores', () async {
      final (b, _, retool, _) = await montar('admin');
      await retool.deleteDispositivo('d1');
      expect(b.dispositivos.itens.containsKey('d1'), isFalse);
      expect(b.reutilizacoes.itens.values.where((r) => r.dispositivoId == 'd1'), isEmpty);
      expect(b.dispositivos.pastasExcluidas, contains('retool/dispositivos/d1'));
      final log = b.audit.registros.lastWhere((l) => l.acao == AuditLogAcao.exclusao);
      expect(log.dadosAnteriores!['nome'], 'Gabarito de Furação Lateral');
    });

    test('limpeza de duplicados só apaga os seguros', () async {
      final (b, _, retool, _) = await montar('admin');
      b.dispositivos.seed(const [
        Dispositivo(id: 'x1', codigo: 'Z', nome: 'Dup', dataCriacao: '2026-01-01'),
        Dispositivo(id: 'x2', codigo: 'z', nome: 'dup', dataCriacao: '2026-01-02'),
        Dispositivo(id: 'x3', codigo: 'Z', nome: 'Dup', dataCriacao: '2026-01-03', observacoes: 'tem vínculo'),
      ]);
      await _ciclo();
      final r = await retool.limparDispositivosDuplicados(['x2', 'x3', 'd1']);
      expect(r.excluidos, 1);
      expect(b.dispositivos.itens.containsKey('x2'), isFalse);
      expect(b.dispositivos.itens.containsKey('x3'), isTrue);
      expect(b.dispositivos.itens.containsKey('d1'), isTrue);
    });

    test('importação delega ao repositório e audita o resumo', () async {
      final (b, _, retool, anuncios) = await montar('projetista');
      final r = await retool.importarDispositivosEmLote(
        novosDispositivos: [
          {'codigo': 'GAB-0042', 'nome': 'Gabarito de Furação Lateral', 'peso': '15'},
          {'codigo': 'NOVO-1', 'nome': 'Novo'},
        ],
        novasCategorias: const [],
        novasFamilias: const [],
        novosProdutos: const [],
      );
      expect(r.inseridos, 1);
      expect(r.atualizados, 1);
      expect(b.audit.registros.last.acao, AuditLogAcao.importacao);
      expect(anuncios.last, contains('Importação concluída'));
    });
  });

  group('Classificações', () {
    test('CRUD com auditoria por tipo', () async {
      final (b, _, retool, _) = await montar('admin');
      final id = await retool.addClassificacao(TipoClassificacao.familia, 'Pulverização');
      await _ciclo();
      expect(b.classificacoes.itens(TipoClassificacao.familia)[id]!.nome, 'Pulverização');
      await retool.updateClassificacao(TipoClassificacao.familia, id, {'ativo': false});
      expect(b.classificacoes.itens(TipoClassificacao.familia)[id]!.ativo, isFalse);
      await retool.deleteClassificacao(TipoClassificacao.familia, id);
      expect(b.classificacoes.itens(TipoClassificacao.familia).containsKey(id), isFalse);
      expect(b.audit.registros.map((l) => l.tipoEntidade).toSet(), {AuditLogTipoEntidade.familia});
    });
  });

  group('Fluxo de reutilização', () {
    test('engenharia solicita (Fila da Engenharia) e envia ao projetista notificando aprovadores', () async {
      final (b, _, retool, _) = await montar('engenharia');
      await retool.solicitarReutilizacao({'dispositivoId': 'd2', 'codigoPeca': 'P-1', 'hardSaving': 100.0});
      await _ciclo();
      final reu = b.reutilizacoes.itens.values.firstWhere((r) => r.codigoPeca == 'P-1');
      expect(reu.status, ReutilizacaoStatus.emAnaliseEngenharia);
      expect(reu.solicitanteId, 'eu');

      await retool.transicionarReutilizacao(reu.id, ReutilizacaoStatus.emAnaliseProjetista);
      expect(b.reutilizacoes.itens[reu.id]!.status, ReutilizacaoStatus.emAnaliseProjetista);
      final dest = b.notifications.itens.values.where((n) => n.tipo == NotificacaoTipo.reutilizacaoNova).map((n) => n.destinatarioUid).toSet();
      expect(dest, {'proj1', 'adm9'});
      expect(b.audit.registros.last.acaoDescricao, 'Solicitou análise do Projetista (1º filtro)');
    });

    test('projetista reprova com motivo e notifica o solicitante', () async {
      final (b, _, retool, anuncios) = await montar('projetista');
      await retool.transicionarReutilizacao('r1', ReutilizacaoStatus.naoAprovada, motivo: 'Peça incompatível');
      final r = b.reutilizacoes.itens['r1']!;
      expect(r.status, ReutilizacaoStatus.naoAprovada);
      expect(r.motivoRejeicao, 'Peça incompatível');
      expect(r.aprovadorId, 'eu');
      final n = b.notifications.itens.values.single;
      expect(n.destinatarioUid, 'eng1');
      expect(n.descricao, contains('Peça incompatível'));
      expect(b.audit.registros.last.acao, AuditLogAcao.rejeicao);
      expect(anuncios.last, 'Status atualizado: Reutilização não aprovada');
    });

    test('transição não permitida é negada', () async {
      final (b, _, retool, anuncios) = await montar('engenharia');
      await retool.transicionarReutilizacao('r1', ReutilizacaoStatus.aprovada);
      expect(b.reutilizacoes.itens['r1']!.status, ReutilizacaoStatus.emAnaliseProjetista);
      expect(anuncios.last, contains('não executa essa etapa'));
    });

    test('registro direto nasce aprovado', () async {
      final (b, _, retool, _) = await montar('admin');
      await retool.addReutilizacao({'dispositivoId': 'd2', 'codigoPeca': 'DIR'});
      expect(b.reutilizacoes.itens.values.firstWhere((r) => r.codigoPeca == 'DIR').status, ReutilizacaoStatus.aprovada);
    });
  });

  group('Guardas de rota', () {
    test('redireciona conforme a sessão e o cargo', () async {
      final (_, auth, _, _) = await montar('engenharia');
      expect(redirecionar(auth, Rotas.login), Rotas.home);
      expect(redirecionar(auth, Rotas.categorias), Rotas.dispositivos);
      expect(redirecionar(auth, Rotas.administracao), Rotas.dispositivos);
      expect(redirecionar(auth, Rotas.novoDispositivo), Rotas.dispositivos);
      expect(redirecionar(auth, Rotas.reutilizacoes), isNull);
    });

    test('admin acessa tudo; sem sessão vai ao login', () async {
      final (_, auth, _, _) = await montar('admin');
      expect(redirecionar(auth, Rotas.administracao), isNull);
      expect(redirecionar(auth, Rotas.categorias), isNull);
      await auth.logout();
      expect(redirecionar(auth, Rotas.dispositivos), Rotas.login);
      expect(auth.currentRole, perfilConvidado);
    });
  });
}
