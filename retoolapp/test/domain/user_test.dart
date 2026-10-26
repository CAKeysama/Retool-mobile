import 'package:flutter_test/flutter_test.dart';
import 'package:retoolapp/domain/entities/user.dart';

/// Porte de `user.test.ts` e `convidado.test.ts` do desktop.
UserProfile perfil({
  String perfil = 'engenharia',
  bool ativo = true,
  StatusAprovacao? status,
  bool trocaSenha = false,
  String? perfilSolicitado,
  String? motivoRejeicao,
}) =>
    UserProfile(
      uid: 'u1',
      email: 'u1@retool.test',
      nome: 'U1',
      perfil: perfil,
      ativo: ativo,
      statusAprovacao: status,
      trocaSenhaObrigatoria: trocaSenha,
      perfilSolicitado: perfilSolicitado,
      motivoRejeicao: motivoRejeicao,
    );

void main() {
  group('RBAC - matriz oficial de permissões', () {
    const matriz = {
      UserRole.admin: (consultar: true, cadastrar: true, editar: true, excluir: true, aprovar: true, solicitar: true),
      UserRole.projetista: (consultar: true, cadastrar: true, editar: true, excluir: false, aprovar: true, solicitar: true),
      UserRole.engenharia: (consultar: true, cadastrar: false, editar: false, excluir: false, aprovar: false, solicitar: true),
      UserRole.gerencia: (consultar: true, cadastrar: false, editar: false, excluir: false, aprovar: false, solicitar: false),
    };

    for (final e in matriz.entries) {
      test('${e.key.name} reflete a matriz', () {
        final c = rolesConfig[e.key]!;
        expect(c.canConsultar, e.value.consultar);
        expect(c.canCadastrar, e.value.cadastrar);
        expect(c.canEditar, e.value.editar);
        expect(c.canExcluir, e.value.excluir);
        expect(c.canAprovar, e.value.aprovar);
        expect(c.canSolicitar, e.value.solicitar);
      });
    }

    test('gestão de usuários e auditoria apenas para a Administração', () {
      expect(rolesConfig[UserRole.admin]!.canGerenciarUsuarios, isTrue);
      expect(rolesConfig[UserRole.admin]!.canVerLogs, isTrue);
      for (final r in [UserRole.projetista, UserRole.engenharia, UserRole.gerencia]) {
        expect(rolesConfig[r]!.canGerenciarUsuarios, isFalse);
        expect(rolesConfig[r]!.canVerLogs, isFalse);
      }
    });
  });

  group('Convidado: autocadastro sem permissões', () {
    test('não concede nenhuma permissão', () {
      const c = convidadoConfig;
      expect([c.canConsultar, c.canCadastrar, c.canEditar, c.canExcluir, c.canAprovar, c.canSolicitar, c.canGerenciarUsuarios, c.canVerLogs],
          everyElement(isFalse));
    });

    test('não é um cargo atribuível', () {
      expect(perfisAtribuiveis.map((r) => r.name), ['admin', 'projetista', 'engenharia', 'gerencia']);
      expect(isPerfilAtribuivel('convidado'), isFalse);
      expect(isPerfilAtribuivel('superadmin'), isFalse);
      expect(isPerfilAtribuivel('projetista'), isTrue);
    });

    test('perfil desconhecido cai no menor privilégio', () {
      expect(identical(configDoPerfil('convidado'), convidadoConfig), isTrue);
      expect(identical(configDoPerfil(null), convidadoConfig), isTrue);
      expect(identical(configDoPerfil('root'), convidadoConfig), isTrue);
      expect(identical(configDoPerfil('admin'), rolesConfig[UserRole.admin]), isTrue);
    });
  });

  group('Situação da conta', () {
    final casos = <String, (UserProfile, SituacaoUsuario)>{
      'convidado pendente': (perfil(perfil: 'convidado', ativo: false, status: StatusAprovacao.pendente), SituacaoUsuario.pendente),
      'cadastro rejeitado': (perfil(perfil: 'convidado', ativo: false, status: StatusAprovacao.rejeitado), SituacaoUsuario.rejeitado),
      'conta aprovada ativa': (perfil(status: StatusAprovacao.aprovado), SituacaoUsuario.ativo),
      'conta aprovada bloqueada': (perfil(ativo: false, status: StatusAprovacao.aprovado), SituacaoUsuario.bloqueado),
      'conta legada ativa': (perfil(), SituacaoUsuario.ativo),
      'conta legada bloqueada': (perfil(ativo: false), SituacaoUsuario.bloqueado),
      'pendente legado (tier solicitado)': (perfil(perfil: 'gerencia', ativo: false, perfilSolicitado: 'engenharia'), SituacaoUsuario.pendente),
      'convidado ativo inconsistente': (perfil(perfil: 'convidado'), SituacaoUsuario.pendente),
    };
    casos.forEach((desc, caso) {
      test(desc, () => expect(situacaoDoUsuario(caso.$1), caso.$2));
    });

    test('pendente não opera, mas mantém a sessão na área do convidado', () {
      final c = perfil(perfil: 'convidado', ativo: false, status: StatusAprovacao.pendente);
      expect(isContaOperacional(c), isFalse);
      expect(podeManterSessao(c), isTrue);
      expect(telaDaSessao(c), TelaDaSessao.aguardandoAprovacao);
    });

    test('senha temporária obriga a troca antes de operar', () {
      final temp = perfil(status: StatusAprovacao.aprovado, trocaSenha: true);
      expect(isContaOperacional(temp), isFalse);
      expect(telaDaSessao(temp), TelaDaSessao.trocaSenha);
      expect(telaDaSessao(temp.copyWith(trocaSenhaObrigatoria: false)), TelaDaSessao.sistema);
    });

    test('bloqueados, rejeitados e sessões sem perfil voltam ao login', () {
      expect(telaDaSessao(null), TelaDaSessao.login);
      expect(telaDaSessao(perfil(ativo: false, status: StatusAprovacao.aprovado)), TelaDaSessao.login);
      expect(telaDaSessao(perfil(perfil: 'convidado', ativo: false, status: StatusAprovacao.rejeitado)), TelaDaSessao.login);
    });

    test('administração só é reconhecida em conta operacional', () {
      expect(isAdministrador(perfil(perfil: 'admin')), isTrue);
      expect(isAdministrador(perfil(perfil: 'admin', ativo: false)), isFalse);
      expect(isAdministrador(perfil(perfil: 'admin', trocaSenha: true)), isFalse);
      expect(isAdministrador(perfil(perfil: 'projetista')), isFalse);
    });

    test('mensagem de acesso negado informa o motivo da rejeição', () {
      final rejeitado = perfil(perfil: 'convidado', ativo: false, status: StatusAprovacao.rejeitado, motivoRejeicao: 'Fora do escopo');
      expect(mensagemAcessoNegado(rejeitado), allOf(contains('recusada'), contains('Fora do escopo')));
      expect(mensagemAcessoNegado(perfil(ativo: false)), contains('desativado'));
    });
  });

  group('Serialização', () {
    test('toMap/fromMap preserva campos e omite nulos', () {
      final u = perfil(perfil: 'admin', status: StatusAprovacao.aprovado, trocaSenha: true);
      final m = u.toMap();
      expect(m.containsKey('motivoRejeicao'), isFalse);
      expect(m['statusAprovacao'], 'aprovado');
      final volta = UserProfile.fromMap('u1', m);
      expect(volta.perfil, 'admin');
      expect(volta.trocaSenhaObrigatoria, isTrue);
      expect(volta.statusAprovacao, StatusAprovacao.aprovado);
    });
  });
}
