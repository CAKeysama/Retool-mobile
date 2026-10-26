import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/app_dependencies.dart';
import '../../core/router/rotas.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/entities/classificacao.dart';
import '../../domain/entities/dispositivo.dart';
import '../../domain/entities/file_attachment.dart';
import '../../domain/errors.dart';
import '../../domain/services/file_validators.dart';
import '../../presentation/state/auth_controller.dart';
import '../../presentation/state/retool_controller.dart';
import 'detalhes/navegacao.dart';
import 'form/campo_tags.dart';
import 'form/seletor_arquivos.dart';
import 'form/seletor_classificacao.dart';
import 'form/upload_widgets.dart';

/// Cadastro/edição de dispositivo em tela cheia (equivalente a `DispositivoForm.tsx`).
/// `id` nulo = novo dispositivo.
class DispositivoFormScreen extends StatefulWidget {
  final String? id;

  /// Origem dos arquivos (padrão: [seletorArquivosPadrao]); injetável nos testes.
  final SeletorArquivos? seletor;

  const DispositivoFormScreen({super.key, this.id, this.seletor});

  @override
  State<DispositivoFormScreen> createState() => _DispositivoFormScreenState();
}

class _DispositivoFormScreenState extends State<DispositivoFormScreen> {
  static const _igualdade = DeepCollectionEquality();

  final _nome = TextEditingController();
  final _codigo = TextEditingController();
  final _peso = TextEditingController();
  final _descricao = TextEditingController();
  final _observacoes = TextEditingController();

  String _categoriaId = '';
  String _familiaId = '';
  String _produtoId = '';
  List<String> _palavrasChave = [];
  String _imagemPeca = '';
  String _imagemDispositivo = '';
  List<FileAttachment> _anexos = [];
  bool _ativo = true;

  /// Pasta estável no Storage: o id do novo dispositivo é gerado antes dos uploads.
  late final String _storageId = widget.id ?? const Uuid().v4();

  Map<String, dynamic>? _inicial;
  bool _salvando = false;
  bool _concluido = false;

  final Map<CampoImagemDispositivo, EnvioEmAndamento> _enviosImagem = {};
  final Map<CampoImagemDispositivo, String> _errosImagem = {};
  final Map<int, EnvioEmAndamento> _enviosPdf = {};
  int _seqPdf = 0;
  String? _erroPdf;

  bool get _editando => widget.id != null;
  SeletorArquivos get _seletor => widget.seletor ?? seletorArquivosPadrao;

  @override
  void initState() {
    super.initState();
    for (final c in [_nome, _codigo, _peso, _descricao, _observacoes]) {
      c.addListener(_aoEditarTexto);
    }
    if (!_editando) _inicial = _dados();
  }

  void _aoEditarTexto() {
    // Ignora o preenchimento inicial da edição (feito durante o build).
    if (mounted && _inicial != null) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [_nome, _codigo, _peso, _descricao, _observacoes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _carregar(Dispositivo d) {
    _nome.text = d.nome ?? '';
    _codigo.text = d.codigo ?? '';
    _peso.text = d.peso ?? '';
    _descricao.text = d.descricao ?? '';
    _observacoes.text = d.observacoes ?? '';
    _categoriaId = d.categoriaId ?? '';
    _familiaId = d.familiaId ?? '';
    _produtoId = d.produtoId ?? '';
    _palavrasChave = [...d.palavrasChave];
    _imagemPeca = d.imagemPeca ?? '';
    _imagemDispositivo = d.imagemDispositivo ?? '';
    _anexos = [...d.anexos];
    _ativo = d.ativo;
    _inicial = _dados();
  }

  /// Mapa gravado no Firestore, com exatamente os nomes de campo do desktop.
  Map<String, dynamic> _dados() => {
    'nome': _nome.text.trim(),
    'codigo': _codigo.text.trim(),
    'categoriaId': _categoriaId,
    'familiaId': _familiaId,
    'produtoId': _produtoId,
    'peso': _peso.text.trim(),
    'descricao': _descricao.text.trim(),
    'observacoes': _observacoes.text.trim(),
    'palavrasChave': [..._palavrasChave],
    'imagemPeca': _imagemPeca,
    'imagemDispositivo': _imagemDispositivo,
    'anexos': [for (final a in _anexos) a.toMap()],
    'ativo': _ativo,
  };

  bool get _enviando => _enviosImagem.isNotEmpty || _enviosPdf.isNotEmpty;
  bool get _alterado => _inicial != null && !_igualdade.equals(_inicial, _dados());

  // ------------------------------------------------------------------ uploads

  String _mensagemFalha(Object e) => (e is ErroValidacao || e is ErroAmigavel || e is ErroPermissao)
      ? mensagemDoErro(e)
      : 'Falha ao enviar o arquivo para o servidor.';

  Future<void> _enviarImagem(CampoImagemDispositivo campo) async {
    final origem = await perguntarOrigemImagem(context);
    if (origem == null || !mounted) return;
    final deps = context.read<AppDependencies>();
    final retool = context.read<ReToolController>();
    setState(() => _errosImagem.remove(campo));

    ArquivoEscolhido? arquivo;
    try {
      arquivo = await _seletor.escolherImagem(origem);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errosImagem[campo] = origem == OrigemImagem.camera
              ? 'Não foi possível acessar a câmera.'
              : 'Não foi possível acessar a galeria.',
        );
      }
      return;
    }
    if (arquivo == null || !mounted) return;

    final categoria = campo == CampoImagemDispositivo.imagemPeca
        ? CategoriaAnexo.imagemPeca
        : CategoriaAnexo.imagemDispositivo;
    final erro = validarArquivo(contentType: arquivo.contentType, size: arquivo.tamanho, categoria: categoria);
    if (erro != null) {
      setState(() => _errosImagem[campo] = erro);
      return;
    }

    final nome = arquivo.nome;
    setState(() => _enviosImagem[campo] = EnvioEmAndamento(nome, 0));
    try {
      final anexo = await deps.storage.uploadFile(
        baseStoragePath: 'retool/dispositivos/$_storageId',
        bytes: arquivo.bytes,
        nomeOriginal: nome,
        contentType: arquivo.contentType,
        categoria: categoria,
        onProgress: (p) {
          if (mounted && _enviosImagem.containsKey(campo)) {
            setState(() => _enviosImagem[campo] = EnvioEmAndamento(nome, p));
          }
        },
      );
      if (!mounted) return;
      setState(() {
        _enviosImagem.remove(campo);
        if (campo == CampoImagemDispositivo.imagemPeca) {
          _imagemPeca = anexo.downloadURL;
        } else {
          _imagemDispositivo = anexo.downloadURL;
        }
      });
      retool.announce(
        campo == CampoImagemDispositivo.imagemPeca
            ? 'Imagem da peça enviada com sucesso.'
            : 'Imagem do dispositivo enviada com sucesso.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enviosImagem.remove(campo);
        _errosImagem[campo] = _mensagemFalha(e);
      });
    }
  }

  void _removerImagem(CampoImagemDispositivo campo) {
    // Como no desktop, só limpa o campo (o arquivo permanece na pasta do dispositivo).
    setState(() {
      if (campo == CampoImagemDispositivo.imagemPeca) {
        _imagemPeca = '';
      } else {
        _imagemDispositivo = '';
      }
      _errosImagem.remove(campo);
    });
    context.read<ReToolController>().announce(
      campo == CampoImagemDispositivo.imagemPeca ? 'Imagem da peça removida.' : 'Imagem do dispositivo removida.',
    );
  }

  Future<void> _enviarPdfs() async {
    final deps = context.read<AppDependencies>();
    final retool = context.read<ReToolController>();
    setState(() => _erroPdf = null);
    List<ArquivoEscolhido> arquivos;
    try {
      arquivos = await _seletor.escolherPdfs();
    } catch (_) {
      if (mounted) setState(() => _erroPdf = 'Não foi possível abrir o seletor de arquivos.');
      return;
    }
    if (arquivos.isEmpty || !mounted) return;

    Future<void> enviar(ArquivoEscolhido a) async {
      final erro = validarArquivo(contentType: a.contentType, size: a.tamanho, categoria: CategoriaAnexo.documentoPdf);
      if (erro != null) {
        setState(() => _erroPdf = erro);
        return;
      }
      final chave = _seqPdf++;
      setState(() => _enviosPdf[chave] = EnvioEmAndamento(a.nome, 0));
      try {
        final anexo = await deps.storage.uploadFile(
          baseStoragePath: 'retool/dispositivos/$_storageId',
          bytes: a.bytes,
          nomeOriginal: a.nome,
          contentType: a.contentType,
          categoria: CategoriaAnexo.documentoPdf,
          onProgress: (p) {
            if (mounted && _enviosPdf.containsKey(chave)) {
              setState(() => _enviosPdf[chave] = EnvioEmAndamento(a.nome, p));
            }
          },
        );
        if (!mounted) return;
        setState(() {
          _enviosPdf.remove(chave);
          _anexos = [..._anexos, anexo];
        });
        retool.announce('Documento ${anexo.originalName} anexado com sucesso.');
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _enviosPdf.remove(chave);
          _erroPdf = _mensagemFalha(e);
        });
      }
    }

    await Future.wait(arquivos.map(enviar));
  }

  void _removerAnexo(FileAttachment a) {
    setState(() => _anexos = _anexos.where((x) => x.id != a.id).toList());
    context.read<ReToolController>().announce('Documento removido dos anexos.');
  }

  // ------------------------------------------------------------------ salvar / sair

  Future<void> _salvar() async {
    if (_salvando) return;
    if (_enviando) {
      Toasts.mostrar('Aguarde o envio dos arquivos terminar.');
      return;
    }
    final retool = context.read<ReToolController>();
    final router = GoRouter.maybeOf(context);
    final dados = _dados();
    setState(() => _salvando = true);
    try {
      if (_editando) {
        await retool.updateDispositivo(widget.id!, dados);
        if (!mounted) return;
        setState(() => _concluido = true);
        voltarDaTelaDeDispositivo(context);
      } else {
        final novoId = await retool.addDispositivo(dados, id: _storageId);
        if (!mounted || novoId == null) return;
        setState(() => _concluido = true);
        if (router != null) {
          router.go(Rotas.dispositivo(novoId));
        } else {
          Navigator.of(context).maybePop();
        }
      }
    } catch (_) {
      Toasts.mostrar('Erro ao salvar o dispositivo.', erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _confirmarSaida() async {
    final sair = await confirmar(
      context,
      titulo: 'Descartar alterações?',
      mensagem: 'Você tem alterações não salvas. Deseja sair sem salvar?',
      confirmarLabel: 'Sair sem salvar',
      perigoso: true,
    );
    if (!sair || !mounted) return;
    setState(() => _concluido = true);
    voltarDaTelaDeDispositivo(context);
  }

  // ------------------------------------------------------------------ UI

  Widget _par(Widget a, Widget b) => LayoutBuilder(
    builder: (context, c) => c.maxWidth < 520
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              a,
              const SizedBox(height: AppSpacing.md),
              b,
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: a),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: b),
            ],
          ),
  );

  Scaffold _telaSimples(Widget corpo) => Scaffold(
    appBar: AppBar(title: Text(_editando ? 'Editar dispositivo' : 'Novo dispositivo')),
    body: corpo,
  );

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final permitido = _editando ? auth.canEditar : auth.canCadastrar;
    if (!permitido) {
      return _telaSimples(
        EmptyState(
          icon: LucideIcons.lock,
          titulo: 'Acesso restrito',
          descricao: _editando
              ? 'Seu perfil não tem permissão para editar dispositivos.'
              : 'Seu perfil não tem permissão para cadastrar dispositivos.',
          acao: AppButton.primary(label: 'Voltar', onPressed: () => voltarDaTelaDeDispositivo(context)),
        ),
      );
    }

    if (_editando && _inicial == null) {
      final retool = context.watch<ReToolController>();
      final d = retool.dispositivo(widget.id);
      if (d != null) {
        _carregar(d);
      } else if (!retool.dispositivosCarregados) {
        return _telaSimples(const LoadingView(mensagem: 'Carregando dispositivo...'));
      } else {
        return _telaSimples(
          EmptyState(
            icon: LucideIcons.searchX,
            titulo: 'Dispositivo não encontrado',
            acao: AppButton.primary(label: 'Voltar', onPressed: () => voltarDaTelaDeDispositivo(context)),
          ),
        );
      }
    }

    final alterado = _alterado;
    return PopScope(
      canPop: _concluido || !alterado,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmarSaida();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_editando ? 'Editar dispositivo' : 'Novo dispositivo'),
          leading: IconButton(
            tooltip: 'Fechar',
            icon: const Icon(LucideIcons.x),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
          children: [
            _par(
              AppTextField(
                key: const Key('campo_nome'),
                label: 'Nº dispositivo',
                hint: 'Ex: Dispositivo 12',
                helper: 'Nome ou identificação do dispositivo',
                controller: _nome,
                textInputAction: TextInputAction.next,
              ),
              AppTextField(
                key: const Key('campo_codigo'),
                label: 'CÓDIGO PEÇA',
                hint: 'Ex: DMP00011',
                helper: 'Código único de fabricação ou catálogo',
                controller: _codigo,
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _par(
              SeletorClassificacao(
                tipo: TipoClassificacao.familia,
                valor: _familiaId,
                onChanged: (v) => setState(() => _familiaId = v ?? ''),
              ),
              SeletorClassificacao(
                tipo: TipoClassificacao.produto,
                valor: _produtoId,
                onChanged: (v) => setState(() => _produtoId = v ?? ''),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _par(
              SeletorClassificacao(
                tipo: TipoClassificacao.categoria,
                valor: _categoriaId,
                onChanged: (v) => setState(() => _categoriaId = v ?? ''),
              ),
              AppTextField(
                key: const Key('campo_peso'),
                label: 'PESO dispositivo',
                hint: 'Ex: 35000',
                helper: 'Peso em gramas (Ex: 1000)',
                controller: _peso,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            CampoPalavrasChave(tags: _palavrasChave, onChanged: (t) => setState(() => _palavrasChave = t)),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              key: const Key('campo_descricao'),
              label: 'DESCRIÇÃO PEÇA',
              hint: 'Descreva fisicamente a peça, seu formato, dimensões ou finalidade...',
              controller: _descricao,
              maxLines: 4,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              key: const Key('campo_observacoes'),
              label: 'Observações (Legado)',
              hint: 'Observações complementares do dispositivo',
              controller: _observacoes,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.sm),
            Material(
              color: Colors.transparent,
              child: SwitchListTile(
                key: const Key('campo_ativo'),
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Dispositivo ativo',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
                ),
                subtitle: Text(
                  _ativo ? 'Disponível para reutilização.' : 'Marcado como inativo.',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSubtle),
                ),
                value: _ativo,
                onChanged: (v) => setState(() => _ativo = v),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.only(bottom: 4),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: const Text(
                'ARQUIVOS FÍSICOS E FOTOS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppColors.primary,
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, c) {
                final peca = CampoImagemUpload(
                  key: const Key('upload_imagem_peca'),
                  rotulo: 'IMAGEM PEÇA',
                  url: _imagemPeca,
                  envio: _enviosImagem[CampoImagemDispositivo.imagemPeca],
                  erro: _errosImagem[CampoImagemDispositivo.imagemPeca],
                  onEscolher: () => _enviarImagem(CampoImagemDispositivo.imagemPeca),
                  onRemover: () => _removerImagem(CampoImagemDispositivo.imagemPeca),
                );
                final disp = CampoImagemUpload(
                  key: const Key('upload_imagem_dispositivo'),
                  rotulo: 'Imagem dispositivo',
                  url: _imagemDispositivo,
                  envio: _enviosImagem[CampoImagemDispositivo.imagemDispositivo],
                  erro: _errosImagem[CampoImagemDispositivo.imagemDispositivo],
                  onEscolher: () => _enviarImagem(CampoImagemDispositivo.imagemDispositivo),
                  onRemover: () => _removerImagem(CampoImagemDispositivo.imagemDispositivo),
                );
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: peca),
                    const SizedBox(width: 12),
                    Expanded(child: disp),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            CampoAnexosPdf(
              anexos: _anexos,
              envios: _enviosPdf.values.toList(),
              erro: _erroPdf,
              onEscolher: _enviarPdfs,
              onRemover: _removerAnexo,
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 10, AppSpacing.md, 10),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            // Altura fixa: o AppButton expandido centraliza com `Center` e ocuparia a tela toda.
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Cancelar',
                      expand: true,
                      onPressed: _salvando ? null : () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: AppButton.primary(
                      key: const Key('salvar_dispositivo'),
                      label: _editando ? 'Salvar alterações' : 'Cadastrar dispositivo',
                      icon: LucideIcons.check,
                      expand: true,
                      loading: _salvando,
                      onPressed: _salvar,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
