import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../application/usecases/acessos_comum.dart';
import '../../core/config/app_dependencies.dart';
import '../../core/utils/busca.dart';
import '../../domain/entities/audit_log.dart';
import '../../domain/entities/classificacao.dart';
import '../../domain/entities/dispositivo.dart';
import '../../domain/entities/notificacao.dart';
import '../../domain/entities/reutilizacao.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/repositories.dart';
import 'auth_controller.dart';

/// Exibe uma mensagem curta ao usuário (toast) — injetado pela camada de UI.
typedef Announce = void Function(String mensagem);

/// Dados fabris em tempo real e todas as mutações com auditoria e notificações
/// (equivalente ao `ReToolContext` do desktop).
///
/// Desempenho: índices (por id, por dispositivo) e o texto de busca normalizado
/// são recalculados uma vez por snapshot — nunca a cada tecla digitada.
class ReToolController extends ChangeNotifier {
  final AppDependencies deps;
  final AuthController auth;
  Announce announce;

  ReToolController(this.deps, this.auth, {Announce? announce}) : announce = announce ?? ((_) {}) {
    auth.addListener(_aoMudarSessao);
    _aoMudarSessao();
  }

  final List<StreamSubscription> _subs = [];
  bool _assinado = false;
  bool _disposed = false;

  List<Dispositivo> _dispositivos = const [];
  List<Classificacao> _categorias = const [];
  List<Classificacao> _familias = const [];
  List<Classificacao> _produtos = const [];
  List<Reutilizacao> _reutilizacoes = const [];

  bool _dispositivosCarregados = false;
  bool _reutilizacoesCarregadas = false;

  Map<String, Dispositivo> _dispPorId = const {};
  Map<String, Classificacao> _catPorId = const {};
  Map<String, Classificacao> _famPorId = const {};
  Map<String, Classificacao> _prodPorId = const {};
  Map<String, List<Reutilizacao>> _reuPorDispositivo = const {};
  Map<String, String> _textoBusca = const {};

  List<Dispositivo> get dispositivos => _dispositivos;
  List<Classificacao> get categorias => _categorias;
  List<Classificacao> get familias => _familias;
  List<Classificacao> get produtos => _produtos;
  List<Reutilizacao> get reutilizacoes => _reutilizacoes;
  bool get dispositivosCarregados => _dispositivosCarregados;
  bool get reutilizacoesCarregadas => _reutilizacoesCarregadas;

  Dispositivo? dispositivo(String? id) => id == null ? null : _dispPorId[id];
  Classificacao? categoria(String? id) => id == null ? null : _catPorId[id];
  Classificacao? familia(String? id) => id == null ? null : _famPorId[id];
  Classificacao? produto(String? id) => id == null ? null : _prodPorId[id];
  List<Classificacao> classificacoes(TipoClassificacao tipo) => switch (tipo) {
        TipoClassificacao.categoria => _categorias,
        TipoClassificacao.familia => _familias,
        TipoClassificacao.produto => _produtos,
      };
  Classificacao? classificacao(TipoClassificacao tipo, String? id) => switch (tipo) {
        TipoClassificacao.categoria => categoria(id),
        TipoClassificacao.familia => familia(id),
        TipoClassificacao.produto => produto(id),
      };

  /// Reutilizações de um dispositivo, da mais recente para a mais antiga.
  List<Reutilizacao> reutilizacoesDo(String dispositivoId) => _reuPorDispositivo[dispositivoId] ?? const [];

  /// Busca multidimensional do desktop (nome, código, descrição, família, produto,
  /// peso, categoria e palavras-chave), tolerante a acentos.
  List<Dispositivo> buscarDispositivos(String query, {Iterable<Dispositivo>? em}) {
    final q = normalizarBusca(query).trim();
    final base = em ?? _dispositivos;
    if (q.isEmpty) return base.toList();
    return base.where((d) => (_textoBusca[d.id] ?? '').contains(q)).toList();
  }

  void _notificar() {
    if (!_disposed) notifyListeners();
  }

  // Somente contas operacionais leem os dados; a assinatura é refeita quando a conta passa a operar.
  void _aoMudarSessao() {
    final deveAssinar = auth.isOperacional;
    if (deveAssinar == _assinado) return;
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _assinado = deveAssinar;
    if (!deveAssinar) {
      _dispositivos = const [];
      _categorias = _familias = _produtos = const [];
      _reutilizacoes = const [];
      _dispositivosCarregados = _reutilizacoesCarregadas = false;
      _reindexar();
      _notificar();
      return;
    }
    _subs.add(deps.dispositivos.watchAll().listen((l) {
      _dispositivos = l;
      _dispositivosCarregados = true;
      _reindexar();
      _notificar();
    }, onError: (e) => debugPrint('Falha ao sincronizar dispositivos: $e')));
    _subs.add(deps.reutilizacoes.watchAll().listen((l) {
      _reutilizacoes = l;
      _reutilizacoesCarregadas = true;
      _reindexarReutilizacoes();
      _notificar();
    }, onError: (e) => debugPrint('Falha ao sincronizar reutilizações: $e')));
    for (final tipo in TipoClassificacao.values) {
      _subs.add(deps.classificacoes.watchAll(tipo).listen((l) {
        switch (tipo) {
          case TipoClassificacao.categoria:
            _categorias = l;
          case TipoClassificacao.familia:
            _familias = l;
          case TipoClassificacao.produto:
            _produtos = l;
        }
        _reindexar();
        _notificar();
      }, onError: (e) => debugPrint('Falha ao sincronizar ${tipo.colecao}: $e')));
    }
  }

  void _reindexar() {
    _dispPorId = {for (final d in _dispositivos) d.id: d};
    _catPorId = {for (final c in _categorias) c.id: c};
    _famPorId = {for (final f in _familias) f.id: f};
    _prodPorId = {for (final p in _produtos) p.id: p};
    _textoBusca = {
      for (final d in _dispositivos)
        d.id: [
          d.nome,
          d.codigo,
          d.descricao,
          _famPorId[d.familiaId]?.nome,
          _prodPorId[d.produtoId]?.nome,
          d.peso,
          _catPorId[d.categoriaId]?.nome,
          ...d.palavrasChave,
        ].map(normalizarBusca).join('\u0000'),
    };
  }

  void _reindexarReutilizacoes() {
    final mapa = <String, List<Reutilizacao>>{};
    for (final r in _reutilizacoes) {
      mapa.putIfAbsent(r.dispositivoId, () => []).add(r);
    }
    for (final l in mapa.values) {
      l.sort((a, b) => (b.dataCriacao ?? b.data).compareTo(a.dataCriacao ?? a.data));
    }
    _reuPorDispositivo = mapa;
  }

  // ---------------------------------------------------------------- permissões

  String get _role => auth.currentRole;
  bool get _podeEditar => _role == 'admin' || _role == 'projetista';
  bool get _isAdmin => _role == 'admin';

  /// "Event handler" central de auditoria: a falha no registro nunca derruba a operação.
  Future<void> _auditar(
    AuditLogAcao acao,
    AuditLogTipoEntidade tipo,
    String entidadeId,
    String? entidadeNome,
    String acaoDescricao, {
    Map<String, dynamic>? conteudo,
    Map<String, dynamic>? dadosAnteriores,
  }) {
    final u = auth.userProfile;
    return registrarAuditoriaSemFalhar(
      deps.audit,
      AuditLogInput(
        usuarioUid: u?.uid ?? 'sistema',
        usuarioNome: u?.nome ?? 'Desconhecido',
        usuarioEmail: u?.email ?? '',
        usuarioPerfil: _role,
        acao: acao,
        acaoDescricao: acaoDescricao,
        tipoEntidade: tipo,
        entidadeId: entidadeId,
        entidadeNome: entidadeNome ?? entidadeId,
        detalhes: acaoDescricao,
        conteudo: conteudo,
        dadosAnteriores: dadosAnteriores,
      ),
    );
  }

  // ---------------------------------------------------------------- dispositivos

  /// Propagação automática de imagens por Número da Peça.
  Future<void> _propagarImagensPorCodigo(String origemId, String? codigo, Map<String, dynamic> payload, bool isNew) async {
    final chave = normalizarNumeroPeca(codigo);
    if (chave.isEmpty) return;
    final linha = _dispositivos.where((d) => normalizarNumeroPeca(d.codigo) == chave).toList();
    final patches = calcularPropagacaoImagens(linha, origemId, codigo, payload, isNew);
    if (patches.isEmpty) return;
    for (final p in patches) {
      await deps.dispositivos.update(p.id, p.patch);
      final alvo = _dispPorId[p.id];
      await _auditar(
        AuditLogAcao.edicao,
        AuditLogTipoEntidade.dispositivo,
        p.id,
        alvo?.nome ?? alvo?.codigo ?? p.id,
        p.origem == 'propagacao'
            ? 'Imagem propagada automaticamente (mesmo número de peça)'
            : 'Imagem herdada automaticamente da linha (mesmo número de peça)',
        conteudo: {'origemId': origemId, 'numeroPeca': codigo, 'campos': p.patch.keys.toList()},
      );
    }
    announce('Imagens sincronizadas em ${patches.length} dispositivo(s) da linha $codigo.');
  }

  /// Retorna o id criado (ou null se negado).
  Future<String?> addDispositivo(Map<String, dynamic> data, {String? id}) async {
    if (!_podeEditar) {
      announce('Acesso negado: seu perfil não possui permissão para cadastrar dispositivos.');
      return null;
    }
    final novoId = await deps.dispositivos.add(data, id: id);
    await _auditar(AuditLogAcao.criacao, AuditLogTipoEntidade.dispositivo, novoId, data['nome'] as String?,
        'Cadastrou dispositivo',
        conteudo: Map<String, dynamic>.from(data));
    await _propagarImagensPorCodigo(novoId, data['codigo'] as String?, data, true);
    announce('Dispositivo adicionado com sucesso');
    return novoId;
  }

  Future<void> updateDispositivo(String id, Map<String, dynamic> data, {bool silent = false}) async {
    if (!_podeEditar) {
      if (!silent) announce('Acesso negado: seu perfil não possui permissão para editar dispositivos.');
      return;
    }
    final atual = _dispPorId[id];
    await deps.dispositivos.update(id, data);
    await _auditar(AuditLogAcao.edicao, AuditLogTipoEntidade.dispositivo, id, atual?.nome ?? id, 'Editou dispositivo',
        conteudo: {'valoresAlterados': data}, dadosAnteriores: atual?.toMap());
    await _propagarImagensPorCodigo(id, (data['codigo'] as String?) ?? atual?.codigo, data, false);
    if (!silent) announce('Dispositivo atualizado com sucesso');
  }

  Future<void> deleteDispositivo(String id, {bool silent = false}) async {
    if (!_isAdmin) {
      announce('Apenas Administradoras têm permissão para excluir dispositivos.');
      return;
    }
    final disp = _dispPorId[id];
    await deps.dispositivos.delete(id);
    await _auditar(AuditLogAcao.exclusao, AuditLogTipoEntidade.dispositivo, id, disp?.nome,
        'Exclusão de dispositivo: ${disp?.nome ?? id}',
        conteudo: disp?.toMap(), dadosAnteriores: disp?.toMap());
    // Remove as reutilizações associadas.
    final relacoes = reutilizacoesDo(id);
    await Future.wait(relacoes.map((r) => deps.reutilizacoes.delete(r.id)));
    if (!silent) announce('Dispositivo removido com sucesso');
  }

  Future<ResultadoImportacaoLote> importarDispositivosEmLote({
    required List<Map<String, dynamic>> novosDispositivos,
    required List<String> novasCategorias,
    required List<String> novasFamilias,
    required List<String> novosProdutos,
  }) async {
    if (!_podeEditar) {
      announce('Acesso negado: apenas Administradoras e Projetistas podem importar dispositivos.');
      return ResultadoImportacaoLote(sucesso: 0, erros: novosDispositivos.length);
    }
    try {
      final r = await deps.dispositivos.importarLote(
        novosDispositivos: novosDispositivos,
        novasCategorias: novasCategorias,
        novasFamilias: novasFamilias,
        novosProdutos: novosProdutos,
        categoriasExistentes: _categorias,
        familiasExistentes: _familias,
        produtosExistentes: _produtos,
      );
      await _auditar(
        AuditLogAcao.importacao,
        AuditLogTipoEntidade.dispositivo,
        'importacao-lote',
        'Importação em lote',
        'Importação em lote: ${r.inseridos} inserido(s), ${r.atualizados} atualizado(s), ${r.erros} erro(s) de ${novosDispositivos.length} enviado(s)',
        conteudo: {
          'enviados': novosDispositivos.length,
          'sucesso': r.sucesso,
          'inseridos': r.inseridos,
          'atualizados': r.atualizados,
          'erros': r.erros,
        },
      );
      announce(r.erros > 0
          ? 'Importação parcial: ${r.sucesso} de ${novosDispositivos.length} registros gravados, ${r.erros} com erro. Importe o arquivo novamente para gravar os restantes.'
          : 'Importação concluída! ${r.inseridos} inseridos e ${r.atualizados} atualizados (${r.sucesso} de ${novosDispositivos.length}).');
      return r;
    } catch (e) {
      announce('Erro ao processar importação em lote.');
      return ResultadoImportacaoLote(sucesso: 0, erros: novosDispositivos.length, falhas: [e.toString()]);
    }
  }

  /// Remove duplicados (Código + Dispositivo) revisados; reconfere contra o estado atual.
  Future<ResultadoExclusaoLote> limparDispositivosDuplicados(List<String> ids) async {
    if (!_isAdmin) {
      announce('Apenas Administradoras podem remover dispositivos duplicados.');
      return const ResultadoExclusaoLote(excluidos: 0, erros: 0, falhas: ['acesso negado']);
    }
    final plano = planejarLimpezaDuplicados(_dispositivos, _reutilizacoes.map((r) => r.dispositivoId).toSet());
    final seguros = plano.grupos.expand((g) => g.remover.map((d) => d.id)).toSet();
    final alvo = ids.where(seguros.contains).toList();
    final r = await deps.dispositivos.excluirEmLote(alvo);
    await _auditar(
      AuditLogAcao.exclusao,
      AuditLogTipoEntidade.dispositivo,
      'limpeza-duplicados',
      'Dispositivos duplicados',
      'Limpeza de duplicados Código + Dispositivo: ${r.excluidos} removido(s), ${r.erros} erro(s)',
      conteudo: {'solicitados': ids.length, 'removidos': r.excluidos, 'erros': r.erros, 'ids': alvo},
    );
    announce(r.erros > 0
        ? 'Limpeza parcial: ${r.excluidos} duplicados removidos, ${r.erros} com erro. Rode a verificação de novo.'
        : '${r.excluidos} dispositivos duplicados removidos.');
    return r;
  }

  // ---------------------------------------------------------------- classificações

  static AuditLogTipoEntidade _tipoAuditoria(TipoClassificacao t) => switch (t) {
        TipoClassificacao.categoria => AuditLogTipoEntidade.categoria,
        TipoClassificacao.familia => AuditLogTipoEntidade.familia,
        TipoClassificacao.produto => AuditLogTipoEntidade.produto,
      };

  /// Retorna o id criado ('' se negado).
  Future<String> addClassificacao(TipoClassificacao tipo, String nome, {bool ativo = true}) async {
    final rotulo = tipo.rotulo.toLowerCase();
    if (!_podeEditar) {
      announce('Acesso negado: seu perfil não possui permissão para cadastrar ${tipo.rotuloPlural.toLowerCase()}.');
      return '';
    }
    final id = await deps.classificacoes.add(tipo, nome: nome, ativo: ativo);
    await _auditar(AuditLogAcao.criacao, _tipoAuditoria(tipo), id, nome, 'Cadastrou $rotulo',
        conteudo: {'nome': nome, 'ativo': ativo});
    announce('${tipo.rotulo} adicionad${tipo == TipoClassificacao.produto ? 'o' : 'a'} com sucesso');
    return id;
  }

  Future<void> updateClassificacao(TipoClassificacao tipo, String id, Map<String, dynamic> data,
      {bool silent = false}) async {
    if (!_podeEditar) {
      if (!silent) {
        announce('Acesso negado: seu perfil não possui permissão para editar ${tipo.rotuloPlural.toLowerCase()}.');
      }
      return;
    }
    final atual = classificacao(tipo, id);
    await deps.classificacoes.update(tipo, id, data);
    await _auditar(AuditLogAcao.edicao, _tipoAuditoria(tipo), id, atual?.nome ?? id,
        'Editou ${tipo.rotulo.toLowerCase()}',
        conteudo: {'valoresAlterados': data}, dadosAnteriores: atual?.toMap());
    if (!silent) {
      announce('${tipo.rotulo} atualizad${tipo == TipoClassificacao.produto ? 'o' : 'a'} com sucesso');
    }
  }

  Future<void> deleteClassificacao(TipoClassificacao tipo, String id, {bool silent = false}) async {
    if (!_isAdmin) {
      announce('Apenas Administradoras têm permissão para excluir ${tipo.rotuloPlural.toLowerCase()}.');
      return;
    }
    final atual = classificacao(tipo, id);
    await deps.classificacoes.delete(tipo, id);
    await _auditar(AuditLogAcao.exclusao, _tipoAuditoria(tipo), id, atual?.nome,
        'Exclusão de ${_tipoAuditoria(tipo).valor}: ${atual?.nome ?? id}',
        conteudo: atual?.toMap(), dadosAnteriores: atual?.toMap());
    if (!silent) {
      announce('${tipo.rotulo} removid${tipo == TipoClassificacao.produto ? 'o' : 'a'} com sucesso');
    }
  }

  // ---------------------------------------------------------------- reutilizações

  String _nomeDisp(String dispositivoId) => _dispPorId[dispositivoId]?.nome ?? 'um dispositivo';

  /// Registro direto (Projetista/Administração), nasce aprovado.
  Future<void> addReutilizacao(Map<String, dynamic> data) async {
    if (!_podeEditar) {
      announce('Acesso negado: Engenharia deve utilizar a opção Solicitar Reutilização.');
      return;
    }
    final novoId = await deps.reutilizacoes.add({
      ...data,
      'status': (data['status'] as String?) ?? ReutilizacaoStatus.aprovada.valor,
    });
    final dispositivoId = data['dispositivoId'] as String? ?? '';
    await _auditar(AuditLogAcao.criacao, AuditLogTipoEntidade.reutilizacao, novoId,
        _dispPorId[dispositivoId]?.nome ?? dispositivoId, 'Cadastrou reutilização',
        conteudo: {'dispositivoId': dispositivoId, 'codigoPeca': data['codigoPeca'], 'hardSaving': data['hardSaving']});
    announce('Reutilização adicionada com sucesso');
  }

  /// Engenharia/Projetista/Admin: nasce na Fila da Engenharia.
  Future<void> solicitarReutilizacao(Map<String, dynamic> data) async {
    if (!auth.canSolicitar) {
      announce('Acesso negado: seu perfil possui acesso somente de consulta.');
      return;
    }
    final u = auth.userProfile;
    final novoId = await deps.reutilizacoes.add({
      ...data,
      'status': ReutilizacaoStatus.emAnaliseEngenharia.valor,
      'solicitanteNome': u?.nome ?? 'Engenharia',
      'solicitanteId': u?.uid ?? 'eng',
    });
    final dispositivoId = data['dispositivoId'] as String? ?? '';
    await _auditar(AuditLogAcao.criacao, AuditLogTipoEntidade.reutilizacao, novoId,
        _dispPorId[dispositivoId]?.nome ?? dispositivoId, 'Solicitou reutilização',
        conteudo: {
          'dispositivoId': dispositivoId,
          'codigoPeca': data['codigoPeca'],
          'descricaoAlteracao': data['descricaoAlteracao'],
          'hardSaving': data['hardSaving'],
        });
    announce('Solicitação registrada. Envie para a análise do Projetista na Fila da Engenharia.');
  }

  Future<void> _notificarFilaProjetista(Reutilizacao reu, String descricao) async {
    final eu = auth.userProfile?.uid;
    final aprovadores =
        auth.users.where((u) => u.ativo && (u.perfil == 'admin' || u.perfil == 'projetista') && u.uid != eu);
    for (final a in aprovadores) {
      try {
        await auth.criarNotificacao(Notificacao(
          id: idNotificacao(NotificacaoTipo.reutilizacaoNova, reu.id, a.uid),
          tipo: NotificacaoTipo.reutilizacaoNova,
          destinatarioUid: a.uid,
          remetenteUid: eu ?? '',
          titulo: 'Nova tarefa na Fila do Projetista',
          descricao: descricao,
          dataHora: agoraIso(),
          entidadeId: reu.id,
          dispositivoId: reu.dispositivoId,
        ));
      } catch (e) {
        debugPrint('Falha ao notificar Fila do Projetista: $e');
      }
    }
  }

  Future<void> _notificarSolicitante(Reutilizacao reu, String titulo, String descricao) async {
    final eu = auth.userProfile?.uid;
    if (reu.solicitanteId == null || reu.solicitanteId == eu) return;
    try {
      await auth.criarNotificacao(Notificacao(
        id: idNotificacao(NotificacaoTipo.reutilizacaoDecidida, '${reu.id}:$titulo', reu.solicitanteId!),
        tipo: NotificacaoTipo.reutilizacaoDecidida,
        destinatarioUid: reu.solicitanteId!,
        remetenteUid: eu ?? '',
        titulo: titulo,
        descricao: descricao,
        dataHora: agoraIso(),
        entidadeId: reu.id,
        dispositivoId: reu.dispositivoId,
      ));
    } catch (e) {
      debugPrint('Falha ao notificar solicitante: $e');
    }
  }

  /// Executa uma etapa do fluxo de reutilização (com auditoria e notificações).
  Future<void> transicionarReutilizacao(String id, ReutilizacaoStatus para, {String? motivo, String? numeroOs}) async {
    final reu = _reutilizacoes.where((r) => r.id == id).firstOrNull;
    if (reu == null) return;
    final de = reu.status;
    if (!transicaoReutilizacaoPermitida(_role, de, para)) {
      announce('Acesso negado: seu perfil não executa essa etapa do fluxo.');
      return;
    }

    final dados = <String, dynamic>{'status': para.valor};
    final decisaoProjetista = (de == ReutilizacaoStatus.emAnaliseProjetista &&
            (para == ReutilizacaoStatus.aprovada || para == ReutilizacaoStatus.naoAprovada)) ||
        (de == ReutilizacaoStatus.aguardandoNovoFiltro &&
            (para == ReutilizacaoStatus.emAnaliseProjetista || para == ReutilizacaoStatus.liberadoFabricacao));
    final u = auth.userProfile;
    if (decisaoProjetista) {
      dados['aprovadorNome'] = u?.nome ?? 'Projetista';
      dados['aprovadorId'] = u?.uid;
      dados['dataAprovacao'] = agoraIso();
      if (para == ReutilizacaoStatus.naoAprovada && motivo != null && motivo.isNotEmpty) {
        dados['motivoRejeicao'] = motivo;
      }
    }
    if (numeroOs != null) dados['numeroOs'] = numeroOs;

    await deps.reutilizacoes.update(id, dados);

    final nomeDisp = _nomeDisp(reu.dispositivoId);
    final descricao = descricaoTransicao(de, para);
    await _auditar(
      para == ReutilizacaoStatus.aprovada
          ? AuditLogAcao.aprovacao
          : para == ReutilizacaoStatus.naoAprovada
              ? AuditLogAcao.rejeicao
              : AuditLogAcao.transicao,
      AuditLogTipoEntidade.reutilizacao,
      id,
      nomeDisp,
      descricao,
      conteudo: {
        'statusDe': de.valor,
        'statusPara': para.valor,
        'dispositivoId': reu.dispositivoId,
        'motivo': motivo,
        'numeroOs': numeroOs,
      },
      dadosAnteriores: {'status': de.valor},
    );

    if (para == ReutilizacaoStatus.emAnaliseProjetista && de == ReutilizacaoStatus.emAnaliseEngenharia) {
      await _notificarFilaProjetista(
          reu, '${u?.nome ?? 'A Engenharia'} solicitou análise de reutilização de $nomeDisp (1º filtro).');
    } else if (para == ReutilizacaoStatus.emAnaliseProjetista && de == ReutilizacaoStatus.aguardandoNovoFiltro) {
      await _notificarFilaProjetista(reu, 'Similar encontrado para $nomeDisp: análise de reutilização retomada.');
      await _notificarSolicitante(reu, 'Similar encontrado',
          'O Projetista encontrou um similar para $nomeDisp; a análise de reutilização foi retomada.');
    } else if (para == ReutilizacaoStatus.aprovada) {
      await _notificarSolicitante(
          reu, 'Reutilização aprovada', 'Sua solicitação de reutilização de $nomeDisp foi aprovada.');
    } else if (para == ReutilizacaoStatus.naoAprovada) {
      await _notificarSolicitante(reu, 'Reutilização não aprovada',
          'Sua solicitação de reutilização de $nomeDisp não foi aprovada.${motivo != null && motivo.isNotEmpty ? ' Motivo: $motivo' : ''}');
    } else if (para == ReutilizacaoStatus.aguardandoNovoFiltro) {
      await _notificarFilaProjetista(
          reu, 'A Engenharia solicitou dispositivo novo para $nomeDisp (verificação de similares).');
    } else if (para == ReutilizacaoStatus.liberadoFabricacao) {
      await _notificarSolicitante(reu, 'Liberado para fabricação',
          'Nenhum similar encontrado para $nomeDisp: novo dispositivo liberado para fabricação.');
    }

    announce('Status atualizado: ${para.valor}');
  }

  Future<void> updateReutilizacao(String id, Map<String, dynamic> data) async {
    if (!_podeEditar) {
      announce('Acesso negado: seu perfil não possui permissão para editar reutilizações.');
      return;
    }
    final atual = _reutilizacoes.where((r) => r.id == id).firstOrNull;
    await deps.reutilizacoes.update(id, data);
    await _auditar(AuditLogAcao.edicao, AuditLogTipoEntidade.reutilizacao, id, atual?.descricaoAlteracao ?? id,
        'Editou reutilização',
        conteudo: {'valoresAlterados': data}, dadosAnteriores: atual?.toMap());
    announce('Reutilização atualizada com sucesso');
  }

  Future<void> deleteReutilizacao(String id, {bool silent = false}) async {
    if (!_isAdmin) {
      announce('Apenas Administradoras têm permissão para excluir reutilizações.');
      return;
    }
    final reu = _reutilizacoes.where((r) => r.id == id).firstOrNull;
    await deps.reutilizacoes.delete(id);
    await _auditar(AuditLogAcao.exclusao, AuditLogTipoEntidade.reutilizacao, id, reu?.descricaoAlteracao,
        'Exclusão de reutilizacao: ${reu?.descricaoAlteracao ?? id}',
        conteudo: reu?.toMap(), dadosAnteriores: reu?.toMap());
    if (!silent) announce('Reutilização removida com sucesso');
  }

  @override
  void dispose() {
    _disposed = true;
    auth.removeListener(_aoMudarSessao);
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}

/// Rótulo legível da etapa executada (auditoria e histórico).
String descricaoTransicao(ReutilizacaoStatus de, ReutilizacaoStatus para) {
  if (de == ReutilizacaoStatus.emAnaliseEngenharia && para == ReutilizacaoStatus.emAnaliseProjetista) {
    return 'Solicitou análise do Projetista (1º filtro)';
  }
  if (para == ReutilizacaoStatus.aprovada) return 'Aprovou Reutilização';
  if (para == ReutilizacaoStatus.naoAprovada) return 'Reprovou Reutilização';
  if (para == ReutilizacaoStatus.aguardandoNovoFiltro) return 'Solicitou Novo Filtro (dispositivo novo)';
  if (de == ReutilizacaoStatus.aguardandoNovoFiltro && para == ReutilizacaoStatus.emAnaliseProjetista) {
    return 'Marcou similar encontrado (análise retomada)';
  }
  if (para == ReutilizacaoStatus.liberadoFabricacao) return 'Liberou fabricação de novo dispositivo';
  return 'Alterou status de "${de.valor}" para "${para.valor}"';
}

/// Perfil do usuário atual pode ver a tela de classificações.
bool podeVerClassificacoes(RoleConfig c) => c.canCadastrar || c.canEditar;
