import 'package:flutter_test/flutter_test.dart';
import 'package:retoolapp/application/usecases/acessos_usecases.dart';
import 'package:retoolapp/domain/entities/audit_log.dart';
import 'package:retoolapp/domain/entities/notificacao.dart';
import 'package:retoolapp/domain/entities/solicitacao_cargo.dart';
import 'package:retoolapp/domain/entities/user.dart';
import 'package:retoolapp/domain/errors.dart';
import 'package:retoolapp/domain/repositories/repositories.dart';

import '../support/fakes.dart';

/// Porte de `fluxosDeAcesso.test.ts` do desktop (Fluxos A, B e C).
void main() {
  late FakeBackend b;
  late UserProfile admin;

  setUp(() {
    b = FakeBackend();
    admin = b.criarUsuario('adm1', perfil: 'admin', nome: 'Ana Admin');
    b.criarUsuario('adm2', perfil: 'admin', nome: 'Bia Admin');
    b.criarUsuario('admBloq', perfil: 'admin', ativo: false);
    b.criarUsuario('proj', perfil: 'projetista');
  });

  SolicitarCadastroUseCase cadastro() => SolicitarCadastroUseCase(b.users, b.audit, b.notifications);
  DecidirCadastroUseCase decidir() => DecidirCadastroUseCase(b.users, b.audit, b.notifications);

  group('Fluxo A — cadastro público e aprovação', () {
    test('cadastro sem cargo entra como Convidado aguardando aprovação', () async {
      final p = await cadastro().execute(uid: 'novo', email: ' Novo@Baldan.com ', nome: '  Novo Colaborador ');
      expect(p.perfil, perfilConvidado);
      expect(p.ativo, isFalse);
      expect(p.statusAprovacao, StatusAprovacao.pendente);
      expect(p.email, 'novo@baldan.com');
      expect(p.nome, 'Novo Colaborador');
      expect(telaDaSessao(p), TelaDaSessao.aguardandoAprovacao);
    });

    test('notifica cada administrador ativo (e só eles)', () async {
      await cadastro().execute(uid: 'novo', email: 'n@b.com', nome: 'N');
      final dest = b.notifications.itens.values.where((n) => n.tipo == NotificacaoTipo.contaNova).map((n) => n.destinatarioUid).toSet();
      expect(dest, {'adm1', 'adm2'});
    });

    test('cadastro é auditado', () async {
      await cadastro().execute(uid: 'novo', email: 'n@b.com', nome: 'N');
      final log = b.audit.registros.single;
      expect(log.acao, AuditLogAcao.cadastro);
      expect(log.conteudo!['administradoresNotificados'], 2);
    });

    test('cadastro sem nome é recusado', () async {
      expect(() => cadastro().execute(uid: 'x', email: 'x@b.com', nome: '   '), throwsA(isA<ErroValidacao>()));
    });

    test('aprovação define cargo, ativa, notifica, resolve pendência e audita', () async {
      await cadastro().execute(uid: 'novo', email: 'n@b.com', nome: 'N');
      final r = await decidir().execute(admin: admin, alvoUid: 'novo', aprovar: true, perfil: UserRole.engenharia);
      final salvo = b.users.itens['novo']!;
      expect(salvo.perfil, 'engenharia');
      expect(salvo.ativo, isTrue);
      expect(situacaoDoUsuario(salvo), SituacaoUsuario.ativo);
      expect(r.perfil, 'engenharia');
      final n = b.notifications.itens[idNotificacao(NotificacaoTipo.contaDecidida, 'novo', 'novo')]!;
      expect(n.decisao, 'aprovada');
      expect(b.notifications.itens[idNotificacao(NotificacaoTipo.contaNova, 'novo', 'adm1')]!.resolvida, isTrue);
      expect(b.audit.registros.last.acao, AuditLogAcao.aprovacaoUsuario);
    });

    test('aprovação exige cargo', () async {
      await cadastro().execute(uid: 'novo', email: 'n@b.com', nome: 'N');
      expect(() => decidir().execute(admin: admin, alvoUid: 'novo', aprovar: true), throwsA(isA<ErroValidacao>()));
    });

    test('rejeição mantém inativo, guarda motivo e impede acesso', () async {
      await cadastro().execute(uid: 'novo', email: 'n@b.com', nome: 'N');
      await decidir().execute(admin: admin, alvoUid: 'novo', aprovar: false, motivo: 'Fora do escopo');
      final salvo = b.users.itens['novo']!;
      expect(situacaoDoUsuario(salvo), SituacaoUsuario.rejeitado);
      expect(salvo.motivoRejeicao, 'Fora do escopo');
      expect(telaDaSessao(salvo), TelaDaSessao.login);
      expect(mensagemAcessoNegado(salvo), contains('Fora do escopo'));
    });

    test('cadastro já decidido não é decidido de novo', () async {
      await cadastro().execute(uid: 'novo', email: 'n@b.com', nome: 'N');
      await decidir().execute(admin: admin, alvoUid: 'novo', aprovar: true, perfil: UserRole.gerencia);
      expect(() => decidir().execute(admin: admin, alvoUid: 'novo', aprovar: false), throwsA(isA<ErroValidacao>()));
    });

    test('não-administração não decide e a tentativa é auditada como negada', () async {
      final conv = await cadastro().execute(uid: 'novo', email: 'n@b.com', nome: 'N');
      await expectLater(decidir().execute(admin: conv, alvoUid: 'novo', aprovar: true, perfil: UserRole.admin),
          throwsA(isA<ErroPermissao>()));
      expect(b.audit.registros.last.resultado, AuditLogResultado.negado);
      expect(b.users.itens['novo']!.perfil, perfilConvidado);
    });
  });

  group('Fluxo B — solicitação de alteração de cargo', () {
    late UserProfile eng;
    SolicitarAlteracaoCargoUseCase solicitar() => SolicitarAlteracaoCargoUseCase(b.solicitacoesCargo, b.users, b.audit, b.notifications);
    DecidirSolicitacaoCargoUseCase decidirCargo() => DecidirSolicitacaoCargoUseCase(b.solicitacoesCargo, b.users, b.audit, b.notifications);

    setUp(() => eng = b.criarUsuario('eng', perfil: 'engenharia', nome: 'Edu Eng'));

    test('persiste, notifica a Administração e audita — sem mudar o cargo', () async {
      final s = await solicitar().execute(usuario: eng, perfilSolicitado: UserRole.projetista, justificativa: ' Assumi a ferramentaria ');
      expect(s.status, SolicitacaoCargoStatus.pendente);
      expect(s.justificativa, 'Assumi a ferramentaria');
      expect(b.users.itens['eng']!.perfil, 'engenharia');
      expect(b.notifications.itens.values.where((n) => n.tipo == NotificacaoTipo.cargoSolicitado).map((n) => n.destinatarioUid).toSet(),
          {'adm1', 'adm2'});
      expect(b.audit.registros.last.acao, AuditLogAcao.solicitacaoCargo);
    });

    test('não permite solicitações conflitantes', () async {
      await solicitar().execute(usuario: eng, perfilSolicitado: UserRole.projetista);
      expect(() => solicitar().execute(usuario: eng, perfilSolicitado: UserRole.gerencia), throwsA(isA<ErroValidacao>()));
    });

    test('cargo igual ao atual ou inexistente é recusado', () async {
      expect(() => solicitar().execute(usuario: eng, perfilSolicitado: UserRole.engenharia), throwsA(isA<ErroValidacao>()));
      expect(() => solicitar().execute(usuario: eng, perfilSolicitado: null), throwsA(isA<ErroValidacao>()));
    });

    test('Administração não usa o fluxo de solicitação', () async {
      expect(() => solicitar().execute(usuario: admin, perfilSolicitado: UserRole.gerencia), throwsA(isA<ErroValidacao>()));
    });

    test('aprovação altera o cargo, fecha, libera nova solicitação, notifica e audita', () async {
      final s = await solicitar().execute(usuario: eng, perfilSolicitado: UserRole.projetista);
      await decidirCargo().execute(admin: admin, solicitacaoId: s.id, aprovar: true);
      expect(b.users.itens['eng']!.perfil, 'projetista');
      expect(b.solicitacoesCargo.itens[s.id]!.status, SolicitacaoCargoStatus.aprovada);
      expect(b.solicitacoesCargo.travas.containsKey('eng'), isFalse);
      expect(b.notifications.itens[idNotificacao(NotificacaoTipo.cargoDecidido, s.id, 'eng')]!.decisao, 'aprovada');
      expect(b.notifications.itens[idNotificacao(NotificacaoTipo.cargoSolicitado, s.id, 'adm1')]!.resolvida, isTrue);
      expect(b.audit.registros.last.acao, AuditLogAcao.aprovacaoCargo);
      // Nova solicitação liberada.
      final atualizado = b.users.itens['eng']!;
      await solicitar().execute(usuario: atualizado, perfilSolicitado: UserRole.gerencia);
    });

    test('rejeição não altera o cargo', () async {
      final s = await solicitar().execute(usuario: eng, perfilSolicitado: UserRole.projetista);
      await decidirCargo().execute(admin: admin, solicitacaoId: s.id, aprovar: false, motivo: 'Sem vaga');
      expect(b.users.itens['eng']!.perfil, 'engenharia');
      expect(b.solicitacoesCargo.itens[s.id]!.motivoDecisao, 'Sem vaga');
    });

    test('solicitação decidida não é decidida de novo', () async {
      final s = await solicitar().execute(usuario: eng, perfilSolicitado: UserRole.projetista);
      await decidirCargo().execute(admin: admin, solicitacaoId: s.id, aprovar: false);
      expect(() => decidirCargo().execute(admin: admin, solicitacaoId: s.id, aprovar: true), throwsA(isA<ErroValidacao>()));
    });

    test('usuário comum não decide — nem a própria', () async {
      final s = await solicitar().execute(usuario: eng, perfilSolicitado: UserRole.projetista);
      expect(() => decidirCargo().execute(admin: eng, solicitacaoId: s.id, aprovar: true), throwsA(isA<ErroPermissao>()));
    });

    test('nem a Administração decide solicitação feita por ela mesma', () async {
      // Simula um registro antigo criado quando a conta ainda não era admin.
      final s = SolicitacaoCargo(
          id: 's-self', usuarioUid: 'adm1', usuarioNome: 'Ana', usuarioEmail: 'a@b', perfilAtual: UserRole.projetista, perfilSolicitado: UserRole.admin, dataSolicitacao: '2026-01-01');
      await b.solicitacoesCargo.criar(s);
      expect(() => decidirCargo().execute(admin: admin, solicitacaoId: 's-self', aprovar: true), throwsA(isA<ErroPermissao>()));
    });
  });

  group('Fluxo C — conta criada pela Administração', () {
    CriarContaAdministrativaUseCase criar({Future<ContaAuthCriada> Function(String, String)? auth, String Function()? senha}) =>
        CriarContaAdministrativaUseCase(b.users, b.audit, auth ?? b.auth.criarContaSecundaria, gerarSenha: senha);

    test('gera senha segura, guarda só no provedor e exige troca', () async {
      final r = await criar().execute(admin: admin, nome: 'Carlos', email: 'Carlos@Baldan.com', perfil: UserRole.engenharia);
      expect(r.senhaTemporaria.length, greaterThanOrEqualTo(14));
      expect(r.perfil.trocaSenhaObrigatoria, isTrue);
      expect(b.auth.contas['carlos@baldan.com']!.senha, r.senhaTemporaria);
      final salvo = b.users.itens[r.perfil.uid]!;
      expect(salvo.toMap().values.contains(r.senhaTemporaria), isFalse);
      expect(telaDaSessao(salvo), TelaDaSessao.trocaSenha);
      // A senha nunca chega à auditoria.
      expect(b.audit.registros.map((l) => l.toMap().toString()).join(), isNot(contains(r.senhaTemporaria)));
    });

    test('cada conta recebe uma senha diferente', () async {
      final a = await criar().execute(admin: admin, nome: 'A', email: 'a@b.com', perfil: UserRole.gerencia);
      final c = await criar().execute(admin: admin, nome: 'C', email: 'c@b.com', perfil: UserRole.gerencia);
      expect(a.senhaTemporaria, isNot(c.senhaTemporaria));
    });

    test('somente a Administração cria contas', () async {
      final proj = b.users.itens['proj']!;
      expect(() => criar().execute(admin: proj, nome: 'X', email: 'x@b.com', perfil: UserRole.admin), throwsA(isA<ErroPermissao>()));
    });

    test('dados inválidos são recusados antes de criar a autenticação', () async {
      var chamou = false;
      Future<ContaAuthCriada> auth(String e, String s) async {
        chamou = true;
        return b.auth.criarContaSecundaria(e, s);
      }

      expect(() => criar(auth: auth).execute(admin: admin, nome: ' ', email: 'x@b.com', perfil: UserRole.admin), throwsA(isA<ErroValidacao>()));
      expect(() => criar(auth: auth).execute(admin: admin, nome: 'X', email: 'invalido', perfil: UserRole.admin), throwsA(isA<ErroValidacao>()));
      expect(() => criar(auth: auth).execute(admin: admin, nome: 'X', email: 'x@b.com', perfil: null), throwsA(isA<ErroValidacao>()));
      expect(chamou, isFalse);
    });

    test('falha ao gravar o perfil desfaz a autenticação e registra a falha', () async {
      var desfeito = false;
      final quebrado = _UsersQueFalham(b.users);
      final uc = CriarContaAdministrativaUseCase(quebrado, b.audit, (e, s) async {
        return ContaAuthCriada(uid: 'tmp', desfazer: () async => desfeito = true, finalizar: () async {});
      });
      await expectLater(uc.execute(admin: admin, nome: 'X', email: 'x@b.com', perfil: UserRole.gerencia), throwsA(isA<StateError>()));
      expect(desfeito, isTrue);
      expect(b.audit.registros.last.resultado, AuditLogResultado.falha);
    });

    group('primeiro acesso', () {
      late UserProfile novo;
      setUp(() => novo = b.criarUsuario('n1', perfil: 'engenharia', senha: 'Tmp-ABC-123', trocaSenha: true, logar: true));
      ConcluirTrocaSenhaUseCase troca() => ConcluirTrocaSenhaUseCase(b.users, b.audit, b.auth.atualizarSenha);

      test('é obrigatório trocar a senha antes de operar', () {
        expect(isContaOperacional(novo), isFalse);
      });

      test('nova senha fora da política é recusada sem tocar no provedor', () async {
        await expectLater(troca().execute(usuario: novo, senhaAtual: 'Tmp-ABC-123', novaSenha: 'curta', confirmacao: 'curta'),
            throwsA(isA<ErroValidacao>()));
        expect(b.auth.contas['n1@baldan.com.br']!.senha, 'Tmp-ABC-123');
      });

      test('senha temporária incorreta mantém a exigência e registra a falha', () async {
        await expectLater(troca().execute(usuario: novo, senhaAtual: 'errada', novaSenha: 'novaSenha9', confirmacao: 'novaSenha9'),
            throwsA(isA<ErroAmigavel>()));
        expect(b.users.itens['n1']!.trocaSenhaObrigatoria, isTrue);
        expect(b.audit.registros.last.resultado, AuditLogResultado.falha);
      });

      test('troca concluída remove a exigência', () async {
        await troca().execute(usuario: novo, senhaAtual: 'Tmp-ABC-123', novaSenha: 'novaSenha9', confirmacao: 'novaSenha9');
        expect(b.users.itens['n1']!.trocaSenhaObrigatoria, isFalse);
        expect(b.users.itens['n1']!.senhaAlteradaEm, isNotNull);
        expect(isContaOperacional(b.users.itens['n1']), isTrue);
      });
    });
  });
}

class _UsersQueFalham extends FakeUsersRepository {
  final FakeUsersRepository real;
  _UsersQueFalham(this.real);

  @override
  Future<void> setProfile(UserProfile profile) async => throw StateError('permission-denied');
}
