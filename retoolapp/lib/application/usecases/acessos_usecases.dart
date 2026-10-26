import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/audit_log.dart';
import '../../domain/entities/notificacao.dart';
import '../../domain/entities/solicitacao_cargo.dart';
import '../../domain/entities/user.dart';
import '../../domain/errors.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/services/senha_temporaria.dart';
import 'acessos_comum.dart';

/// Fluxo A (início): autocadastro público. Toda conta nasce como Convidado,
/// inativa e aguardando aprovação; a Administração é notificada.
class SolicitarCadastroUseCase {
  final UsersRepository usersRepo;
  final AuditLogRepository auditRepo;
  final NotificationsRepository notificationsRepo;
  SolicitarCadastroUseCase(this.usersRepo, this.auditRepo, this.notificationsRepo);

  Future<UserProfile> execute({required String uid, required String email, required String nome}) async {
    final nomeLimpo = limparTexto(nome, 120);
    if (nomeLimpo.isEmpty) throw const ErroValidacao('Informe seu nome completo.');

    final perfil = UserProfile(
      uid: uid,
      email: email.trim().toLowerCase(),
      nome: nomeLimpo,
      perfil: perfilConvidado,
      ativo: false,
      statusAprovacao: StatusAprovacao.pendente,
      criadoEm: agoraIso(),
    );
    await usersRepo.setProfile(perfil);

    final notificados = await notificarAdministradores(
      usersRepo,
      notificationsRepo,
      (admin) => Notificacao(
        id: idNotificacao(NotificacaoTipo.contaNova, perfil.uid, admin.uid),
        tipo: NotificacaoTipo.contaNova,
        destinatarioUid: admin.uid,
        remetenteUid: perfil.uid,
        titulo: 'Novo cadastro aguardando aprovação',
        descricao: '$nomeLimpo (${perfil.email}) criou uma conta e aguarda a definição de cargo.',
        dataHora: agoraIso(),
        entidadeId: perfil.uid,
      ),
    );

    await registrarAuditoriaSemFalhar(
      auditRepo,
      logDe(perfil,
          acao: AuditLogAcao.cadastro,
          acaoDescricao: 'Solicitou cadastro no sistema (Convidado aguardando aprovação)',
          tipoEntidade: AuditLogTipoEntidade.usuario,
          entidadeId: perfil.uid,
          entidadeNome: nomeLimpo,
          conteudo: {
            'email': perfil.email,
            'perfil': perfil.perfil,
            'statusAprovacao': 'pendente',
            'administradoresNotificados': notificados,
          }),
    );
    return perfil;
  }
}

/// Fluxo A (decisão): a Administração aprova — definindo o cargo — ou rejeita.
class DecidirCadastroUseCase {
  final UsersRepository usersRepo;
  final AuditLogRepository auditRepo;
  final NotificationsRepository notificationsRepo;
  DecidirCadastroUseCase(this.usersRepo, this.auditRepo, this.notificationsRepo);

  Future<UserProfile> execute({
    required UserProfile? admin,
    required String alvoUid,
    required bool aprovar,
    UserRole? perfil,
    String? motivo,
  }) async {
    final acao = aprovar ? AuditLogAcao.aprovacaoUsuario : AuditLogAcao.rejeicaoUsuario;
    if (!isAdministrador(admin)) {
      if (admin != null) {
        await registrarAuditoriaSemFalhar(
            auditRepo,
            logDe(admin,
                acao: acao,
                resultado: AuditLogResultado.negado,
                acaoDescricao: 'Tentativa de decidir cadastro sem permissão',
                tipoEntidade: AuditLogTipoEntidade.usuario,
                entidadeId: alvoUid));
      }
      throw const ErroPermissao();
    }

    final alvo = await usersRepo.getProfile(alvoUid);
    if (alvo == null) throw const ErroValidacao('Cadastro não encontrado.');
    if (situacaoDoUsuario(alvo) != SituacaoUsuario.pendente) {
      throw const ErroValidacao('Este cadastro já foi analisado.');
    }
    if (aprovar && perfil == null) throw const ErroValidacao('Defina o cargo do usuário para aprovar o cadastro.');

    final agora = agoraIso();
    final motivoLimpo = limparTexto(motivo, 500);
    final alteracoes = aprovar
        ? <String, dynamic>{
            'perfil': perfil!.name,
            'ativo': true,
            'statusAprovacao': 'aprovado',
            'aprovadoPorUid': admin!.uid,
            'aprovadoEm': agora,
            'atualizadoEm': agora,
          }
        : <String, dynamic>{
            'ativo': false,
            'statusAprovacao': 'rejeitado',
            'rejeitadoPorUid': admin!.uid,
            'rejeitadoEm': agora,
            'atualizadoEm': agora,
            if (motivoLimpo.isNotEmpty) 'motivoRejeicao': motivoLimpo,
          };

    try {
      await usersRepo.updateProfile(alvoUid, alteracoes);
    } catch (e) {
      await registrarAuditoriaSemFalhar(
          auditRepo,
          logDe(admin,
              acao: acao,
              resultado: AuditLogResultado.falha,
              acaoDescricao: aprovar ? 'Falha ao aprovar cadastro' : 'Falha ao rejeitar cadastro',
              tipoEntidade: AuditLogTipoEntidade.usuario,
              entidadeId: alvoUid,
              entidadeNome: alvo.nome,
              conteudo: {'erro': e.toString()}));
      rethrow;
    }

    try {
      await notificationsRepo.criar(Notificacao(
        id: idNotificacao(NotificacaoTipo.contaDecidida, alvoUid, alvoUid),
        tipo: NotificacaoTipo.contaDecidida,
        destinatarioUid: alvoUid,
        remetenteUid: admin.uid,
        titulo: aprovar ? 'Cadastro aprovado' : 'Cadastro recusado',
        descricao: aprovar
            ? 'Seu acesso foi liberado com o cargo ${rolesConfig[perfil]!.titulo}.'
            : 'Sua solicitação de cadastro foi recusada pela Administração.${motivoLimpo.isNotEmpty ? ' Motivo: $motivoLimpo' : ''}',
        dataHora: agora,
        entidadeId: alvoUid,
        perfilSolicitado: aprovar ? perfil!.name : null,
        decisao: aprovar ? 'aprovada' : 'recusada',
      ));
    } catch (e) {
      debugPrint('Falha ao notificar o solicitante: $e');
    }

    try {
      await notificationsRepo.marcarResolvida(idNotificacao(NotificacaoTipo.contaNova, alvoUid, admin.uid), true);
    } catch (_) {}

    await registrarAuditoriaSemFalhar(
        auditRepo,
        logDe(admin,
            acao: acao,
            acaoDescricao: aprovar
                ? 'Aprovou o cadastro de ${alvo.nome} com o cargo ${rolesConfig[perfil]!.titulo}'
                : 'Rejeitou o cadastro de ${alvo.nome}',
            tipoEntidade: AuditLogTipoEntidade.usuario,
            entidadeId: alvoUid,
            entidadeNome: alvo.nome,
            conteudo: aprovar
                ? {'perfilDefinido': perfil!.name, 'email': alvo.email}
                : {if (motivoLimpo.isNotEmpty) 'motivo': motivoLimpo, 'email': alvo.email},
            dadosAnteriores: {
              'perfil': alvo.perfil,
              'ativo': alvo.ativo,
              'statusAprovacao': alvo.statusAprovacao?.name ?? 'pendente',
            }));

    return aprovar
        ? alvo.copyWith(perfil: perfil!.name, ativo: true, statusAprovacao: StatusAprovacao.aprovado, atualizadoEm: agora)
        : alvo.copyWith(
            ativo: false,
            statusAprovacao: StatusAprovacao.rejeitado,
            atualizadoEm: agora,
            motivoRejeicao: motivoLimpo.isEmpty ? null : motivoLimpo);
  }
}

class ContaCriada {
  final UserProfile perfil;

  /// Senha temporária em texto puro — devolvida UMA vez. Nunca é persistida nem auditada.
  final String senhaTemporaria;
  const ContaCriada(this.perfil, this.senhaTemporaria);
}

/// Fluxo C (início): a Administração cria uma conta com senha temporária
/// e troca obrigatória no 1º acesso.
class CriarContaAdministrativaUseCase {
  final UsersRepository usersRepo;
  final AuditLogRepository auditRepo;
  final Future<ContaAuthCriada> Function(String email, String senha) criarContaAuth;
  final String Function() gerarSenha;
  CriarContaAdministrativaUseCase(this.usersRepo, this.auditRepo, this.criarContaAuth, {String Function()? gerarSenha})
      : gerarSenha = gerarSenha ?? (() => gerarSenhaTemporaria());

  Future<ContaCriada> execute({
    required UserProfile? admin,
    required String nome,
    required String email,
    required UserRole? perfil,
  }) async {
    if (!isAdministrador(admin)) {
      if (admin != null) {
        await registrarAuditoriaSemFalhar(
            auditRepo,
            logDe(admin,
                acao: AuditLogAcao.criacaoUsuario,
                resultado: AuditLogResultado.negado,
                acaoDescricao: 'Tentativa de criar conta sem permissão',
                tipoEntidade: AuditLogTipoEntidade.usuario,
                entidadeId: 'nova-conta'));
      }
      throw const ErroPermissao();
    }

    final nomeLimpo = limparTexto(nome, 120);
    final emailNormalizado = email.trim().toLowerCase();
    if (nomeLimpo.isEmpty) throw const ErroValidacao('Informe o nome completo do colaborador.');
    if (!emailValido(emailNormalizado)) throw const ErroValidacao('Informe um e-mail válido.');
    if (perfil == null) throw const ErroValidacao('Selecione um cargo válido.');

    final senhaTemporaria = gerarSenha();
    ContaAuthCriada conta;
    try {
      conta = await criarContaAuth(emailNormalizado, senhaTemporaria);
    } catch (e) {
      await registrarAuditoriaSemFalhar(
          auditRepo,
          logDe(admin!,
              acao: AuditLogAcao.criacaoUsuario,
              resultado: AuditLogResultado.falha,
              acaoDescricao: 'Falha ao criar a conta de $nomeLimpo',
              tipoEntidade: AuditLogTipoEntidade.usuario,
              entidadeId: emailNormalizado,
              entidadeNome: nomeLimpo,
              conteudo: {'email': emailNormalizado, 'perfil': perfil.name, 'erro': e.toString()}));
      rethrow;
    }

    final novoPerfil = UserProfile(
      uid: conta.uid,
      email: emailNormalizado,
      nome: nomeLimpo,
      perfil: perfil.name,
      ativo: true,
      statusAprovacao: StatusAprovacao.aprovado,
      trocaSenhaObrigatoria: true,
      criadoEm: agoraIso(),
      criadoPorUid: admin!.uid,
    );

    try {
      await usersRepo.setProfile(novoPerfil);
    } catch (e) {
      try {
        await conta.desfazer();
      } catch (err) {
        debugPrint('Falha ao desfazer conta de autenticação: $err');
      }
      await registrarAuditoriaSemFalhar(
          auditRepo,
          logDe(admin,
              acao: AuditLogAcao.criacaoUsuario,
              resultado: AuditLogResultado.falha,
              acaoDescricao: 'Falha ao gravar o perfil de $nomeLimpo; conta de autenticação desfeita',
              tipoEntidade: AuditLogTipoEntidade.usuario,
              entidadeId: conta.uid,
              entidadeNome: nomeLimpo,
              conteudo: {'email': emailNormalizado, 'perfil': perfil.name}));
      rethrow;
    } finally {
      try {
        await conta.finalizar();
      } catch (_) {}
    }

    await registrarAuditoriaSemFalhar(
        auditRepo,
        logDe(admin,
            acao: AuditLogAcao.criacaoUsuario,
            acaoDescricao:
                'Criou a conta de $nomeLimpo com o cargo ${rolesConfig[perfil]!.titulo} (senha temporária gerada)',
            tipoEntidade: AuditLogTipoEntidade.usuario,
            entidadeId: conta.uid,
            entidadeNome: nomeLimpo,
            conteudo: {'email': emailNormalizado, 'perfil': perfil.name, 'trocaSenhaObrigatoria': true}));

    return ContaCriada(novoPerfil, senhaTemporaria);
  }
}

/// Fluxo C (conclusão): troca obrigatória da senha temporária no primeiro acesso.
class ConcluirTrocaSenhaUseCase {
  final UsersRepository usersRepo;
  final AuditLogRepository auditRepo;
  final Future<void> Function(String senhaAtual, String novaSenha) atualizarSenhaAuth;
  ConcluirTrocaSenhaUseCase(this.usersRepo, this.auditRepo, this.atualizarSenhaAuth);

  Future<void> execute({
    required UserProfile usuario,
    required String senhaAtual,
    required String novaSenha,
    required String confirmacao,
  }) async {
    if (senhaAtual.isEmpty) throw const ErroValidacao('Informe a senha temporária recebida.');
    final erro = validarNovaSenha(novaSenha, confirmacao, senhaAtual);
    if (erro != null) throw ErroValidacao(erro);

    try {
      await atualizarSenhaAuth(senhaAtual, novaSenha);
    } catch (e) {
      await registrarAuditoriaSemFalhar(
          auditRepo,
          logDe(usuario,
              acao: AuditLogAcao.trocaSenha,
              resultado: AuditLogResultado.falha,
              acaoDescricao: 'Falha na troca obrigatória de senha (primeiro acesso)',
              tipoEntidade: AuditLogTipoEntidade.usuario,
              entidadeId: usuario.uid,
              entidadeNome: usuario.nome,
              conteudo: {'erro': e is ErroAmigavel ? (e.codigo ?? e.mensagem) : 'erro-desconhecido'}));
      rethrow;
    }

    await usersRepo.updateProfile(usuario.uid, {'trocaSenhaObrigatoria': false, 'senhaAlteradaEm': agoraIso()});

    await registrarAuditoriaSemFalhar(
        auditRepo,
        logDe(usuario,
            acao: AuditLogAcao.trocaSenha,
            acaoDescricao: 'Substituiu a senha temporária no primeiro acesso',
            tipoEntidade: AuditLogTipoEntidade.usuario,
            entidadeId: usuario.uid,
            entidadeNome: usuario.nome,
            conteudo: {'motivo': 'primeiro_acesso'}));
  }
}

/// Fluxo B (início): o próprio usuário pede outro cargo.
class SolicitarAlteracaoCargoUseCase {
  final SolicitacoesCargoRepository solicitacoesRepo;
  final UsersRepository usersRepo;
  final AuditLogRepository auditRepo;
  final NotificationsRepository notificationsRepo;
  SolicitarAlteracaoCargoUseCase(this.solicitacoesRepo, this.usersRepo, this.auditRepo, this.notificationsRepo);

  Future<SolicitacaoCargo> execute({
    required UserProfile? usuario,
    required UserRole? perfilSolicitado,
    String? justificativa,
  }) async {
    final justificativaLimpa = limparTexto(justificativa, justificativaMax + 1);
    final pendente = usuario != null ? await solicitacoesRepo.obterPendenteDoUsuario(usuario.uid) : null;
    final erro = validarNovaSolicitacaoCargo(usuario, perfilSolicitado?.name, pendente, justificativaLimpa);
    if (erro != null) throw ErroValidacao(erro);

    final atual = userRoleFromString(usuario!.perfil)!;
    final solicitacao = SolicitacaoCargo(
      id: const Uuid().v4(),
      usuarioUid: usuario.uid,
      usuarioNome: usuario.nome,
      usuarioEmail: usuario.email,
      perfilAtual: atual,
      perfilSolicitado: perfilSolicitado!,
      justificativa: justificativaLimpa.isEmpty ? null : justificativaLimpa,
      dataSolicitacao: agoraIso(),
    );
    await solicitacoesRepo.criar(solicitacao);

    final notificados = await notificarAdministradores(
      usersRepo,
      notificationsRepo,
      (admin) => Notificacao(
        id: idNotificacao(NotificacaoTipo.cargoSolicitado, solicitacao.id, admin.uid),
        tipo: NotificacaoTipo.cargoSolicitado,
        destinatarioUid: admin.uid,
        remetenteUid: solicitacao.usuarioUid,
        titulo: 'Solicitação de alteração de cargo',
        descricao:
            '${solicitacao.usuarioNome} solicitou mudar de ${rolesConfig[atual]!.titulo} para ${rolesConfig[perfilSolicitado]!.titulo}.',
        dataHora: solicitacao.dataSolicitacao,
        entidadeId: solicitacao.id,
        perfilSolicitado: perfilSolicitado.name,
      ),
      exceto: solicitacao.usuarioUid,
    );

    await registrarAuditoriaSemFalhar(
        auditRepo,
        logDe(usuario,
            acao: AuditLogAcao.solicitacaoCargo,
            acaoDescricao: 'Solicitou alteração de cargo para ${rolesConfig[perfilSolicitado]!.titulo}',
            tipoEntidade: AuditLogTipoEntidade.solicitacaoCargo,
            entidadeId: solicitacao.id,
            entidadeNome: solicitacao.usuarioNome,
            conteudo: {
              'perfilAtual': atual.name,
              'perfilSolicitado': perfilSolicitado.name,
              'justificativa': solicitacao.justificativa,
              'administradoresNotificados': notificados,
            }));
    return solicitacao;
  }
}

/// Fluxo B (decisão): somente a Administração aprova ou rejeita.
class DecidirSolicitacaoCargoUseCase {
  final SolicitacoesCargoRepository solicitacoesRepo;
  final UsersRepository usersRepo;
  final AuditLogRepository auditRepo;
  final NotificationsRepository notificationsRepo;
  DecidirSolicitacaoCargoUseCase(this.solicitacoesRepo, this.usersRepo, this.auditRepo, this.notificationsRepo);

  Future<void> execute({
    required UserProfile? admin,
    required String solicitacaoId,
    required bool aprovar,
    String? motivo,
  }) async {
    final acao = aprovar ? AuditLogAcao.aprovacaoCargo : AuditLogAcao.rejeicaoCargo;
    if (!isAdministrador(admin)) {
      if (admin != null) {
        await registrarAuditoriaSemFalhar(
            auditRepo,
            logDe(admin,
                acao: acao,
                resultado: AuditLogResultado.negado,
                acaoDescricao: 'Tentativa de decidir solicitação de cargo sem permissão',
                tipoEntidade: AuditLogTipoEntidade.solicitacaoCargo,
                entidadeId: solicitacaoId));
      }
      throw const ErroPermissao();
    }

    final s = await solicitacoesRepo.obter(solicitacaoId);
    if (s == null) throw const ErroValidacao('Solicitação não encontrada.');
    if (s.status != SolicitacaoCargoStatus.pendente) throw const ErroValidacao('Esta solicitação já foi analisada.');
    if (s.usuarioUid == admin!.uid) {
      throw const ErroPermissao('Uma solicitação não pode ser decidida pelo próprio solicitante.');
    }

    final alvo = await usersRepo.getProfile(s.usuarioUid);
    if (aprovar && alvo == null) {
      throw const ErroValidacao('O usuário desta solicitação não existe mais; apenas a rejeição é possível.');
    }

    final motivoLimpo = limparTexto(motivo, 500);
    final decisao = DecisaoSolicitacaoCargo(
      status: aprovar ? SolicitacaoCargoStatus.aprovada : SolicitacaoCargoStatus.rejeitada,
      decididoPorUid: admin.uid,
      decididoPorNome: admin.nome,
      dataDecisao: agoraIso(),
      motivoDecisao: motivoLimpo.isEmpty ? null : motivoLimpo,
    );

    try {
      await solicitacoesRepo.decidir(s, decisao);
    } catch (e) {
      await registrarAuditoriaSemFalhar(
          auditRepo,
          logDe(admin,
              acao: acao,
              resultado: AuditLogResultado.falha,
              acaoDescricao: aprovar ? 'Falha ao aprovar alteração de cargo' : 'Falha ao rejeitar alteração de cargo',
              tipoEntidade: AuditLogTipoEntidade.solicitacaoCargo,
              entidadeId: s.id,
              entidadeNome: s.usuarioNome,
              conteudo: {'erro': e.toString()}));
      rethrow;
    }

    final de = rolesConfig[s.perfilAtual]!.titulo;
    final para = rolesConfig[s.perfilSolicitado]!.titulo;

    if (alvo != null) {
      try {
        await notificationsRepo.criar(Notificacao(
          id: idNotificacao(NotificacaoTipo.cargoDecidido, s.id, s.usuarioUid),
          tipo: NotificacaoTipo.cargoDecidido,
          destinatarioUid: s.usuarioUid,
          remetenteUid: admin.uid,
          titulo: aprovar ? 'Alteração de cargo aprovada' : 'Alteração de cargo rejeitada',
          descricao: aprovar
              ? 'Seu cargo foi alterado para $para.'
              : 'Sua solicitação para $para foi rejeitada.${motivoLimpo.isNotEmpty ? ' Motivo: $motivoLimpo' : ''}',
          dataHora: decisao.dataDecisao,
          entidadeId: s.id,
          perfilSolicitado: s.perfilSolicitado.name,
          decisao: aprovar ? 'aprovada' : 'rejeitada',
        ));
      } catch (e) {
        debugPrint('Falha ao notificar o solicitante: $e');
      }
    }

    try {
      await notificationsRepo.marcarResolvida(idNotificacao(NotificacaoTipo.cargoSolicitado, s.id, admin.uid), true);
    } catch (_) {}

    await registrarAuditoriaSemFalhar(
        auditRepo,
        logDe(admin,
            acao: acao,
            acaoDescricao: aprovar
                ? 'Aprovou a alteração de cargo de ${s.usuarioNome}: $de → $para'
                : 'Rejeitou a alteração de cargo de ${s.usuarioNome} ($de → $para)',
            tipoEntidade: AuditLogTipoEntidade.solicitacaoCargo,
            entidadeId: s.id,
            entidadeNome: s.usuarioNome,
            conteudo: {
              'usuarioUid': s.usuarioUid,
              'perfilAnterior': alvo?.perfil ?? s.perfilAtual.name,
              'perfilSolicitado': s.perfilSolicitado.name,
              'perfilResultante': aprovar ? s.perfilSolicitado.name : (alvo?.perfil ?? s.perfilAtual.name),
              if (motivoLimpo.isNotEmpty) 'motivo': motivoLimpo,
            },
            dadosAnteriores: {'status': 'pendente'}));
  }
}
