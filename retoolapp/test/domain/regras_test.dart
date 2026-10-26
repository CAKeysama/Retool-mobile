import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:retoolapp/core/utils/busca.dart';
import 'package:retoolapp/domain/entities/audit_log.dart';
import 'package:retoolapp/domain/entities/classificacao.dart';
import 'package:retoolapp/domain/entities/dispositivo.dart';
import 'package:retoolapp/domain/entities/file_attachment.dart';
import 'package:retoolapp/domain/entities/notificacao.dart';
import 'package:retoolapp/domain/entities/reutilizacao.dart';
import 'package:retoolapp/domain/entities/solicitacao_cargo.dart';
import 'package:retoolapp/domain/entities/user.dart';
import 'package:retoolapp/domain/services/file_validators.dart';
import 'package:retoolapp/domain/services/senha_temporaria.dart';

/// Porte de `reutilizacao.test.ts`, `dispositivo.test.ts`, `auditLog.test.ts`,
/// `solicitacaoCargo.test.ts`, `senhaTemporaria.test.ts` e `fileValidators.test.ts`.
void main() {
  group('Reutilização - máquina de estados', () {
    test('possui exatamente os 6 estados da arquitetura', () {
      expect(ReutilizacaoStatus.values.map((s) => s.valor), [
        'Em análise (Engenharia)',
        'Em análise (Projetista)',
        'Reutilização aprovada',
        'Reutilização não aprovada',
        'Liberado para fabricação (novo dispositivo)',
        'Aguardando novo filtro (Projetista)',
      ]);
    });

    test('normaliza registros legados', () {
      expect(normalizarStatusReutilizacao('pendente'), ReutilizacaoStatus.emAnaliseProjetista);
      expect(normalizarStatusReutilizacao('aprovado'), ReutilizacaoStatus.aprovada);
      expect(normalizarStatusReutilizacao('rejeitado'), ReutilizacaoStatus.naoAprovada);
      expect(normalizarStatusReutilizacao(null), ReutilizacaoStatus.emAnaliseProjetista);
      expect(normalizarStatusReutilizacao('Em andamento - OS'), ReutilizacaoStatus.aprovada);
      expect(normalizarStatusReutilizacao('Reutilização não aprovada'), ReutilizacaoStatus.naoAprovada);
    });

    test('Engenharia inicia o 1º filtro e solicita dispositivo novo', () {
      expect(transicaoReutilizacaoPermitida('engenharia', ReutilizacaoStatus.emAnaliseEngenharia, ReutilizacaoStatus.emAnaliseProjetista), isTrue);
      expect(transicaoReutilizacaoPermitida('engenharia', ReutilizacaoStatus.naoAprovada, ReutilizacaoStatus.aguardandoNovoFiltro), isTrue);
      expect(transicaoReutilizacaoPermitida('engenharia', ReutilizacaoStatus.emAnaliseProjetista, ReutilizacaoStatus.aprovada), isFalse);
      expect(transicaoReutilizacaoPermitida('engenharia', ReutilizacaoStatus.aguardandoNovoFiltro, ReutilizacaoStatus.liberadoFabricacao), isFalse);
    });

    test('Projetista: 1º filtro e 2º filtro', () {
      expect(transicaoReutilizacaoPermitida('projetista', ReutilizacaoStatus.emAnaliseProjetista, ReutilizacaoStatus.aprovada), isTrue);
      expect(transicaoReutilizacaoPermitida('projetista', ReutilizacaoStatus.emAnaliseProjetista, ReutilizacaoStatus.naoAprovada), isTrue);
      expect(transicaoReutilizacaoPermitida('projetista', ReutilizacaoStatus.aguardandoNovoFiltro, ReutilizacaoStatus.emAnaliseProjetista), isTrue);
      expect(transicaoReutilizacaoPermitida('projetista', ReutilizacaoStatus.aguardandoNovoFiltro, ReutilizacaoStatus.liberadoFabricacao), isTrue);
      expect(transicaoReutilizacaoPermitida('projetista', ReutilizacaoStatus.emAnaliseEngenharia, ReutilizacaoStatus.emAnaliseProjetista), isFalse);
    });

    test('Gerência e Convidado: nenhuma transição', () {
      for (final perfil in ['gerencia', 'convidado']) {
        for (final de in ReutilizacaoStatus.values) {
          for (final para in ReutilizacaoStatus.values) {
            expect(transicaoReutilizacaoPermitida(perfil, de, para), isFalse);
          }
        }
        expect(transicoesDisponiveis(perfil, ReutilizacaoStatus.emAnaliseProjetista), isEmpty);
      }
    });

    test('fromMap aceita números como texto com vírgula', () {
      final r = Reutilizacao.fromMap('x', {'dispositivoId': 'd', 'hardSaving': '1.234,5'.replaceAll('.', ''), 'pesoPeca': 2});
      expect(r.hardSaving, 1234.5);
      expect(r.pesoPeca, 2.0);
    });
  });

  group('Propagação de imagens por Número da Peça', () {
    Dispositivo disp(String id, String? codigo, {String? peca, String? dispositivo}) =>
        Dispositivo(id: id, nome: 'Disp $id', codigo: codigo, imagemPeca: peca, imagemDispositivo: dispositivo);

    test('normaliza a chave da linha', () {
      expect(normalizarNumeroPeca('  51500101580 '), '51500101580');
      expect(normalizarNumeroPeca('ABC-123'), 'abc-123');
      expect(normalizarNumeroPeca(null), '');
    });

    test('upload preenche apenas células vazias da mesma linha', () {
      const url = 'https://storage/img-peca.png';
      final linha = [
        disp('a', '51500101580'),
        disp('b', '51500101580', peca: 'https://storage/existente.png'),
        disp('c', '51500101580'),
        disp('d', '99999999999'),
      ];
      final p = calcularPropagacaoImagens(linha, 'a', '51500101580', {'imagemPeca': url}, false);
      expect(p, hasLength(1));
      expect(p.single.id, 'c');
      expect(p.single.patch, {'imagemPeca': url});
      expect(p.single.origem, 'propagacao');
    });

    test('propaga os dois campos de forma independente', () {
      final linha = [disp('a', 'ABC-1'), disp('b', 'abc-1', peca: 'https://storage/ja-tem.png')];
      final p = calcularPropagacaoImagens(
          linha, 'a', 'ABC-1', {'imagemPeca': 'https://storage/peca.png', 'imagemDispositivo': 'https://storage/disp.png'}, false);
      expect(p, hasLength(1));
      expect(p.single.id, 'b');
      expect(p.single.patch, {'imagemDispositivo': 'https://storage/disp.png'});
    });

    test('sem número de peça não propaga', () {
      expect(calcularPropagacaoImagens([disp('a', null), disp('b', '  ')], 'a', null, {'imagemPeca': 'x'}, false), isEmpty);
    });

    test('edição que limpa a imagem não propaga', () {
      expect(calcularPropagacaoImagens([disp('a', 'ABC-1'), disp('b', 'ABC-1')], 'a', 'ABC-1', {'imagemPeca': ''}, false), isEmpty);
    });

    test('na criação, a origem herda a imagem existente na linha', () {
      final p = calcularPropagacaoImagens([disp('b', 'ABC-1', dispositivo: 'https://storage/linha.png')], 'a-novo', 'ABC-1',
          {'imagemPeca': ''}, true);
      expect(p, hasLength(1));
      expect(p.single.id, 'a-novo');
      expect(p.single.patch, {'imagemDispositivo': 'https://storage/linha.png'});
      expect(p.single.origem, 'heranca');
    });

    test('na edição não há herança inversa', () {
      expect(calcularPropagacaoImagens([disp('b', 'ABC-1', dispositivo: 'x')], 'a', 'ABC-1', {}, false), isEmpty);
    });
  });

  group('Chave Código + Dispositivo e duplicados', () {
    test('equivalências e distinções da chave', () {
      expect(chaveCodigoDispositivo(' ABC ', 'Gabarito'), chaveCodigoDispositivo('abc', ' gabarito '));
      expect(chaveCodigoDispositivo('A​1', 'x'), chaveCodigoDispositivo('A1', 'X'));
      expect(chaveCodigoDispositivo(123, 'x'), chaveCodigoDispositivo('123', 'x'));
      expect(chaveCodigoDispositivo(123.0, 'x'), chaveCodigoDispositivo('123', 'x'));
      expect(chaveCodigoDispositivo('0041', 'x'), isNot(chaveCodigoDispositivo('41', 'x')));
      expect(chaveCodigoDispositivo('1.10', 'x'), isNot(chaveCodigoDispositivo('1.1', 'x')));
      expect(chaveCodigoDispositivo('PEÇA', 'x'), isNot(chaveCodigoDispositivo('PECA', 'x')));
      // NFD (C + U+0327) equivale ao NFC já gravado, como o normalize('NFC') do desktop.
      expect(chaveCodigoDispositivo('PEÇA', 'Válvula'), chaveCodigoDispositivo('PEÇA', 'Válvula'));
      // Separador não colide: tupla JSON.
      expect(chaveCodigoDispositivo('A|B', 'C'), isNot(chaveCodigoDispositivo('A', 'B|C')));
      expect(jsonDecode(chaveCodigoDispositivo('A', 'B')), ['a', 'b']);
    });

    Dispositivo d(String id, String codigo, String nome, {String? peca, List<FileAttachment> anexos = const [], String? obs}) =>
        Dispositivo(
            id: id,
            codigo: codigo,
            nome: nome,
            dataCriacao: '2026-01-0${id.substring(id.length - 1)}',
            imagemPeca: peca,
            anexos: anexos,
            observacoes: obs);

    test('sem repetidos não planeja nada', () {
      final plano = planejarLimpezaDuplicados([d('a1', 'A', '1'), d('a2', 'A', '2')], {});
      expect(plano.grupos, isEmpty);
      expect(plano.totalDocumentos, 2);
      expect(plano.combinacoesDistintas, 2);
      expect(plano.totalRemover, 0);
    });

    test('mantém o mais antigo e remove repetidos sem vínculo', () {
      final plano = planejarLimpezaDuplicados([d('x3', 'A', '1'), d('x1', 'a ', '1'), d('x2', 'A', '1'), d('y1', 'B', '1')], {});
      expect(plano.grupos, hasLength(1));
      expect(plano.grupos.single.manter.id, 'x1');
      expect(plano.grupos.single.remover.map((r) => r.id), ['x2', 'x3']);
      expect(plano.totalDocumentos, 4);
      expect(plano.combinacoesDistintas, 2);
      expect(plano.totalRemover, 2);
      expect(plano.totalRevisar, 0);
    });

    test('documentos com vínculo nunca são removidos', () {
      const anexo = FileAttachment(
          id: 'f', originalName: 'a.pdf', fileName: 'f_a.pdf', contentType: 'application/pdf', size: 1, storagePath: 'p', downloadURL: 'u', uploadedAt: '', categoria: CategoriaAnexo.documentoPdf);
      final plano = planejarLimpezaDuplicados([
        d('x1', 'A', '1'),
        d('x2', 'A', '1'),
        d('x3', 'A', '1', peca: 'img.png'),
        d('x4', 'A', '1', anexos: [anexo]),
        d('x5', 'A', '1', obs: 'ver'),
        d('x6', 'A', '1'),
      ], {'x2'});
      final g = plano.grupos.single;
      expect(g.manter.id, 'x2');
      expect(g.remover.map((r) => r.id), ['x1', 'x6']);
      expect(g.revisar.map((r) => r.id), ['x3', 'x4', 'x5']);
    });

    test('fromMap tolera acervo legado (OWA)', () {
      final x = Dispositivo.fromMap('id1', {'codigo': 123, 'palavrasChave': ['a', 1], 'anexos': 'lixo'});
      expect(x.codigo, '123');
      expect(x.palavrasChave, ['a', '1']);
      expect(x.anexos, isEmpty);
      expect(x.ativo, isTrue);
      expect(x.nome, isNull);
    });
  });

  group('Auditoria', () {
    test('toda ação pertence a exatamente uma categoria', () {
      final categorizadas = acoesPorCategoria.values.expand((l) => l).toList();
      expect(categorizadas.toSet().length, categorizadas.length);
      expect(categorizadas.toSet(), AuditLogAcao.values.toSet());
    });

    const casos = {
      'login': 'autenticacao',
      'logout': 'autenticacao',
      'cadastro': 'autenticacao',
      'troca_senha': 'autenticacao',
      'aprovacao_usuario': 'usuarios',
      'rejeicao_usuario': 'usuarios',
      'criacao_usuario': 'usuarios',
      'solicitacao_cargo': 'usuarios',
      'aprovacao_cargo': 'usuarios',
      'rejeicao_cargo': 'usuarios',
      'alteracao_perfil': 'usuarios',
      'edicao': 'dados',
      'transicao': 'fluxo',
    };
    casos.forEach((acao, categoria) {
      test('$acao → $categoria', () => expect(categoriaDaAcao(AuditLogAcao.fromValor(acao)).valor, categoria));
    });

    for (final campo in ['senha', 'senhaTemporaria', 'novaSenha', 'password', 'userPassword', 'idToken', 'refresh_token', 'apiKey', 'senhaHash', 'secret']) {
      test('campo "$campo" é sensível', () => expect(isCampoSensivel(campo), isTrue));
    }
    for (final campo in ['nome', 'email', 'perfil', 'motivo', 'secretaria', 'hashtagCampanha']) {
      test('campo "$campo" não é sensível', () => expect(isCampoSensivel(campo), isFalse));
    }

    test('remove segredos em qualquer nível e preserva o restante', () {
      final limpo = sanitizarDadosAuditoria({
        'email': 'a@b.c',
        'senha': '123456',
        'senhaTemporaria': 'Xy7!abcDEF',
        'trocaSenhaObrigatoria': true,
        'conteudo': {
          'perfil': 'engenharia',
          'credenciais': {'password': 'segredo', 'usuario': 'ana'},
          'lista': [
            {'token': 'abc', 'id': 1},
            {'novaSenha': 'x', 'id': 2},
          ],
        },
        'vazio': null,
      });
      expect(limpo, {
        'email': 'a@b.c',
        'trocaSenhaObrigatoria': true,
        'conteudo': {
          'perfil': 'engenharia',
          'credenciais': {'usuario': 'ana'},
          'lista': [
            {'id': 1},
            {'id': 2},
          ],
        },
      });
    });

    test('AuditLogInput.toMap grava tokens estáveis e categoria derivada', () {
      const input = AuditLogInput(
        usuarioUid: 'u',
        usuarioNome: 'U',
        usuarioEmail: 'u@x',
        usuarioPerfil: 'admin',
        acao: AuditLogAcao.aprovacaoCargo,
        tipoEntidade: AuditLogTipoEntidade.solicitacaoCargo,
        entidadeId: 's1',
        conteudo: {'senhaTemporaria': 'x', 'perfil': 'engenharia'},
      );
      final m = input.toMap();
      expect(m['acao'], 'aprovacao_cargo');
      expect(m['categoria'], 'usuarios');
      expect(m['tipoEntidade'], 'solicitacao_cargo');
      expect(m['resultado'], 'sucesso');
      expect(m['conteudo'], {'perfil': 'engenharia'});
      expect(m.containsKey('entidadeNome'), isFalse);
    });
  });

  group('Solicitação de cargo', () {
    final ativo = UserProfile(uid: 'u', email: 'u@x', nome: 'U', perfil: 'engenharia', ativo: true, statusAprovacao: StatusAprovacao.aprovado);

    test('valida a nova solicitação', () {
      expect(validarNovaSolicitacaoCargo(ativo, 'projetista', null), isNull);
      expect(validarNovaSolicitacaoCargo(ativo, 'engenharia', null), contains('diferente'));
      expect(validarNovaSolicitacaoCargo(ativo, 'convidado', null), contains('cargo válido'));
      expect(validarNovaSolicitacaoCargo(ativo, 'projetista', null, 'x' * 501), contains('500'));
      final pendente = SolicitacaoCargo(
          id: 's', usuarioUid: 'u', usuarioNome: 'U', usuarioEmail: 'u@x', perfilAtual: UserRole.engenharia, perfilSolicitado: UserRole.projetista, dataSolicitacao: '');
      expect(validarNovaSolicitacaoCargo(ativo, 'projetista', pendente), contains('pendente'));
    });

    test('Administração e contas não operacionais não solicitam', () {
      expect(podeSolicitarAlteracaoCargo(ativo.copyWith(perfil: 'admin')), isFalse);
      expect(podeSolicitarAlteracaoCargo(ativo.copyWith(ativo: false)), isFalse);
      expect(podeSolicitarAlteracaoCargo(null), isFalse);
      expect(validarNovaSolicitacaoCargo(null, 'projetista', null), contains('não pode'));
    });
  });

  group('Senha temporária', () {
    test('tem o tamanho padrão e todas as classes de caractere', () {
      for (var i = 0; i < 50; i++) {
        final s = gerarSenhaTemporaria();
        expect(s.length, tamanhoSenhaTemporaria);
        expect(s, matches(RegExp(r'[A-Z]')));
        expect(s, matches(RegExp(r'[a-z]')));
        expect(s, matches(RegExp(r'[2-9]')));
        expect(s, matches(RegExp(r'[!@#$%*\-_+?]')));
        expect(s, isNot(matches(RegExp(r'[0O1lI]'))));
      }
    });

    test('é determinística com fonte injetada e recusa tamanho curto', () {
      expect(gerarSenhaTemporaria(fonte: Random(7)), gerarSenhaTemporaria(fonte: Random(7)));
      expect(() => gerarSenhaTemporaria(tamanho: 6), throwsArgumentError);
    });

    test('política da nova senha', () {
      expect(validarNovaSenha('curta1', 'curta1'), contains('mínimo'));
      expect(validarNovaSenha('somenteletras', 'somenteletras'), contains('letras e números'));
      expect(validarNovaSenha('abcdefg1', 'abcdefg2'), contains('confirmação'));
      expect(validarNovaSenha('abcdefg1', 'abcdefg1', 'abcdefg1'), contains('diferente'));
      expect(validarNovaSenha('abcdefg1', 'abcdefg1', 'Tmp!'), isNull);
    });
  });

  group('Arquivos', () {
    test('valida tipo e tamanho como o storage.rules', () {
      expect(validarArquivo(contentType: 'image/png', size: 100, categoria: CategoriaAnexo.imagemPeca), isNull);
      expect(validarArquivo(contentType: 'image/gif', size: 100, categoria: CategoriaAnexo.imagemPeca), contains('JPG, PNG e WEBP'));
      expect(validarArquivo(contentType: 'image/jpeg', size: maxImageSizeBytes + 1, categoria: CategoriaAnexo.imagemDispositivo),
          contains('excede'));
      expect(validarArquivo(contentType: 'application/pdf', size: maxDocumentSizeBytes, categoria: CategoriaAnexo.documentoPdf), isNull);
      expect(validarArquivo(contentType: 'image/png', size: 1, categoria: CategoriaAnexo.documentoPdf), contains('PDF'));
    });

    test('sanitiza nomes e formata tamanhos', () {
      expect(sanitizeFileName('Desenho Técnico (rev 2).pdf'), 'Desenho_Tecnico_rev_2.pdf');
      expect(sanitizeFileName('***'), 'arquivo');
      expect(formatFileSize(0), '0 B');
      expect(formatFileSize(1536), '1.5 KB');
      expect(formatFileSize(10 * 1024 * 1024), '10 MB');
      expect(contentTypeDoNome('FOTO.JPEG'), 'image/jpeg');
      expect(contentTypeDoNome('manual.pdf'), 'application/pdf');
    });
  });

  group('Busca e textos', () {
    test('normalização de busca do desktop', () {
      expect(normalizarBusca('Válvula 2,5'), 'valvula 2.5');
      expect(normalizarBusca('AVULA'), 'avola');
      expect(removerAcentos('Ação Única'), 'Acao Unica');
      expect(compararNomes('Ábaco', 'abacaxi') > 0, isTrue);
    });

    test('id de notificação é determinístico', () {
      expect(idNotificacao(NotificacaoTipo.contaNova, 'u1', 'adm'), 'conta_nova_u1_adm');
    });

    test('notificação exige ação só quando não resolvida', () {
      const n = Notificacao(id: 'n', tipo: NotificacaoTipo.contaNova, destinatarioUid: 'a', remetenteUid: 'b', titulo: '', descricao: '', dataHora: '');
      expect(n.exigeAcao, isTrue);
      expect(Notificacao.fromMap('n', {...n.toMap(), 'resolvida': true}).exigeAcao, isFalse);
      expect(n.toMap().containsKey('resolvida'), isFalse);
    });

    test('classificação legada sem ativo conta como ativa', () {
      expect(Classificacao.fromMap('c', {'nome': 'X'}).ativo, isTrue);
    });
  });
}
