import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../presentation/state/auth_controller.dart';
import '../../../presentation/state/retool_controller.dart';
import 'planilha_dispositivos.dart';

/// Arquivo escolhido pelo usuário (nome + conteúdo).
class ArquivoPlanilha {
  final String nome;
  final Uint8List bytes;
  const ArquivoPlanilha(this.nome, this.bytes);
}

/// Abre o seletor de arquivos; `null` = cancelado. Injetável para testes.
typedef SelecionarArquivoPlanilha = Future<ArquivoPlanilha?> Function();

/// Lê e processa a planilha. O padrão roda em outro isolate (não trava a UI).
typedef ProcessarPlanilha = Future<PreVisualizacaoImportacao> Function(EntradaImportacao entrada);

const extensoesPlanilha = ['csv', 'xlsx', 'xls'];

Future<ArquivoPlanilha?> selecionarArquivoPlanilha() async {
  final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: extensoesPlanilha);
  if (f == null) return null;
  return ArquivoPlanilha(f.name, await f.readAsBytes());
}

Future<PreVisualizacaoImportacao> processarPlanilhaEmIsolate(EntradaImportacao entrada) =>
    compute(prepararImportacao, entrada, debugLabel: 'importacao-planilha');

/// Importação em Lote (`ImportModal` do desktop): escolher arquivo → categoria
/// padrão opcional → pré-visualização → salvar. Só Administradora/Projetista.
Future<void> mostrarImportacaoPlanilha(
  BuildContext context, {
  SelecionarArquivoPlanilha? selecionarArquivo,
  ProcessarPlanilha? processar,
}) =>
    showAppSheet<void>(
      context,
      titulo: 'Importação em Lote',
      subtitulo: 'Planilha .xlsx ou .csv · regra Código + Dispositivo',
      builder: (_) => ImportacaoPlanilhaConteudo(
        selecionarArquivo: selecionarArquivo ?? selecionarArquivoPlanilha,
        processar: processar ?? processarPlanilhaEmIsolate,
      ),
    );

/// Linhas da amostra exibidas antes do "E mais N registros...".
const _linhasAmostra = 10;

class ImportacaoPlanilhaConteudo extends StatefulWidget {
  final SelecionarArquivoPlanilha selecionarArquivo;
  final ProcessarPlanilha processar;
  const ImportacaoPlanilhaConteudo({super.key, required this.selecionarArquivo, required this.processar});

  @override
  State<ImportacaoPlanilhaConteudo> createState() => _ImportacaoPlanilhaConteudoState();
}

class _ImportacaoPlanilhaConteudoState extends State<ImportacaoPlanilhaConteudo> {
  ArquivoPlanilha? _arquivo;
  String? _categoriaPadrao;
  bool _lendo = false;
  bool _importando = false;
  PreVisualizacaoImportacao? _preview;
  ResultadoImportacaoLote? _resultado;
  String _erro = '';

  void _reiniciar() {
    _arquivo = null;
    _preview = null;
    _resultado = null;
    _erro = '';
    _categoriaPadrao = null;
  }

  Future<void> _buscar() async {
    ArquivoPlanilha? escolhido;
    try {
      escolhido = await widget.selecionarArquivo();
    } catch (e) {
      debugPrint('Falha ao abrir o seletor de arquivos: $e');
      if (mounted) setState(() => _erro = 'Não foi possível abrir o arquivo selecionado.');
      return;
    }
    if (!mounted || escolhido == null) return;
    final ext = escolhido.nome.contains('.') ? escolhido.nome.split('.').last.toLowerCase() : '';
    setState(() {
      _reiniciar();
      if (!extensoesPlanilha.contains(ext)) {
        _erro = 'Formato inválido. Por favor, envie um arquivo .csv ou .xlsx.';
        return;
      }
      _arquivo = escolhido;
    });
  }

  Future<void> _processar() async {
    final arquivo = _arquivo;
    if (arquivo == null) return;
    final retool = context.read<ReToolController>();
    setState(() {
      _lendo = true;
      _erro = '';
    });
    try {
      final p = await widget.processar(EntradaImportacao(
        bytes: arquivo.bytes,
        nomeArquivo: arquivo.nome,
        contexto: ContextoProcessamento(
          categorias: retool.categorias,
          familias: retool.familias,
          produtos: retool.produtos,
          defaultCategoriaId: _categoriaPadrao,
        ),
        existentes: [for (final d in retool.dispositivos) (d.codigo, d.nome)],
      ));
      if (!mounted) return;
      setState(() {
        if (p.total == 0) {
          _erro = 'Nenhum registro válido encontrado. Verifique se a planilha tem as colunas Código e Dispositivo.';
        } else {
          _preview = p;
        }
      });
    } on ErroLeituraPlanilha catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } catch (e) {
      debugPrint('Erro ao ler planilha: $e');
      if (mounted) setState(() => _erro = mensagemArquivoInvalido);
    } finally {
      if (mounted) setState(() => _lendo = false);
    }
  }

  Future<void> _confirmar() async {
    final p = _preview;
    if (p == null || p.total == 0) return;
    final retool = context.read<ReToolController>();
    setState(() {
      _importando = true;
      _erro = '';
    });
    try {
      final r = await retool.importarDispositivosEmLote(
        novosDispositivos: p.resultado.dispositivos,
        novasCategorias: p.resultado.novasCategorias,
        novasFamilias: p.resultado.novasFamilias,
        novosProdutos: p.resultado.novosProdutos,
      );
      if (!mounted) return;
      setState(() {
        if (r.erros > 0) {
          // Não fecha: o usuário precisa ver que nem tudo foi gravado.
          _erro = 'Importação parcial: ${r.sucesso} de ${p.total} registros gravados e ${r.erros} com erro. '
              'Toque em "Salvar Importação" novamente para gravar os restantes (os já gravados não serão duplicados).';
        } else {
          _resultado = r;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _erro = 'Falha ao importar registros.');
    } finally {
      if (mounted) setState(() => _importando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (!(auth.canCadastrar || auth.canEditar)) {
      return const InfoBox(
        tipo: InfoBoxTipo.aviso,
        titulo: 'Acesso restrito',
        mensagem: 'Apenas Administradoras e Projetistas podem importar dispositivos.',
      );
    }
    final retool = context.watch<ReToolController>();

    final filhos = <Widget>[];
    final resultado = _resultado;
    if (resultado != null) {
      filhos.add(_Concluido(
        resultado: resultado,
        enviados: _preview?.total ?? resultado.sucesso,
        onNovo: () => setState(_reiniciar),
      ));
    } else if (_preview != null) {
      filhos.add(_PreVisualizacao(
        preview: _preview!,
        nomeCategoria: (id) => retool.categoria(id)?.nome ?? id,
        importando: _importando,
        onVoltar: () => setState(() {
          _preview = null;
          _erro = '';
        }),
        onConfirmar: _confirmar,
      ));
    } else {
      filhos.addAll([
        _AreaArquivo(
          arquivo: _arquivo,
          lendo: _lendo,
          onBuscar: _lendo ? null : _buscar,
          seletorCategoria: _arquivo == null || _erro.isNotEmpty
              ? null
              : AppDropdown<String?>(
                  label: 'Categoria Padrão (Opcional)',
                  value: _categoriaPadrao,
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('-- Usar apenas da Planilha --')),
                    for (final c in retool.categorias) DropdownMenuItem<String?>(value: c.id, child: Text(c.nome)),
                  ],
                  onChanged: _lendo ? null : (v) => setState(() => _categoriaPadrao = v),
                ),
          onProcessar: _arquivo == null || _erro.isNotEmpty || _lendo ? null : _processar,
        ),
        if (_arquivo == null) ...[const SizedBox(height: AppSpacing.md), const _ColunasAceitas()],
      ]);
    }

    return PopScope(
      canPop: !_importando,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        if (_erro.isNotEmpty) ...[
          InfoBox(tipo: InfoBoxTipo.erro, mensagem: _erro),
          const SizedBox(height: AppSpacing.md),
        ],
        ...filhos,
      ]),
    );
  }
}

class _AreaArquivo extends StatelessWidget {
  final ArquivoPlanilha? arquivo;
  final bool lendo;
  final VoidCallback? onBuscar;
  final Widget? seletorCategoria;
  final VoidCallback? onProcessar;
  const _AreaArquivo({
    required this.arquivo,
    required this.lendo,
    required this.onBuscar,
    required this.seletorCategoria,
    required this.onProcessar,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border, width: 2),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Icon(LucideIcons.upload, size: 32, color: AppColors.primary),
          const SizedBox(height: AppSpacing.sm),
          const Text('Selecione um arquivo .csv / .xlsx',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          const SizedBox(height: AppSpacing.xs),
          const Text('As colunas devem seguir o padrão: Familia_do_Produto, PRODUTO, CATEGORIA, etc.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: AppColors.textBody)),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: AppButton.primary(
              label: arquivo == null ? 'Buscar Arquivo' : 'Trocar Arquivo',
              icon: LucideIcons.fileSpreadsheet,
              onPressed: onBuscar,
            ),
          ),
          if (arquivo != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text.rich(
              TextSpan(text: 'Arquivo carregado: ', children: [
                TextSpan(text: arquivo!.nome, style: const TextStyle(color: AppColors.primary)),
              ]),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
            ),
            if (seletorCategoria != null) ...[
              const SizedBox(height: AppSpacing.md),
              seletorCategoria!,
              const SizedBox(height: 4),
              const Text('Será aplicada a todos os registros que não tiverem uma coluna "Categoria".',
                  style: TextStyle(fontSize: 12, color: AppColors.textSubtle)),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: lendo ? 'Processando planilha...' : 'Processar Planilha',
                loading: lendo,
                expand: true,
                onPressed: onProcessar,
              ),
            ],
          ],
        ]),
      );
}

class _ColunasAceitas extends StatelessWidget {
  const _ColunasAceitas();

  static const _colunas = [
    ('Código', 'Código, Código da Peça'),
    ('Dispositivo', 'Dispositivo, Nº Dispositivo, Nome'),
    ('Peso', 'Peso, Peso (Kg), Peso Dispositivo (Kg)'),
    ('Tipo de Dispositivo', 'Categoria, Tipo de Dispositivo, Tipo'),
    ('Família', 'Família, Família do Produto'),
    ('Produto', 'Produto'),
    ('Descrição', 'Descrição, Descrição da Peça'),
    ('Palavras-chave', 'Palavras-chave (separadas por vírgula)'),
  ];

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionLabel('Colunas aceitas'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Column(children: [
            for (final (campo, nomes) in _colunas) InfoRow(label: campo, valor: nomes),
          ]),
        ),
        const SizedBox(height: AppSpacing.md),
        const InfoBox(
          mensagem: 'Acento, maiúsculas e pontuação do cabeçalho não importam. Linhas com o mesmo Código + Dispositivo '
              'viram um único registro; se a combinação já existir no acervo, o cadastro é atualizado (imagens '
              'existentes são mantidas). Tipos, Famílias e Produtos que ainda não existem são criados. '
              'Arquivos .xls antigos devem ser salvos como .xlsx ou .csv.',
        ),
      ]);
}

class _Contador extends StatelessWidget {
  final String rotulo;
  final int valor;
  final Color cor;
  const _Contador(this.rotulo, this.valor, this.cor);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Semantics(
          label: '$rotulo: $valor',
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(children: [
              Text(formatarNumero(valor), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: cor)),
              const SizedBox(height: 2),
              Text(rotulo, style: const TextStyle(fontSize: 12, color: AppColors.textSubtle, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
}

class _PreVisualizacao extends StatelessWidget {
  final PreVisualizacaoImportacao preview;
  final String Function(String id) nomeCategoria;
  final bool importando;
  final VoidCallback onVoltar;
  final VoidCallback onConfirmar;
  const _PreVisualizacao({
    required this.preview,
    required this.nomeCategoria,
    required this.importando,
    required this.onVoltar,
    required this.onConfirmar,
  });

  @override
  Widget build(BuildContext context) {
    final r = preview.resultado;
    final resumo = r.resumo;
    String fmt(int n) => formatarNumero(n);
    const corpo = TextStyle(fontSize: 13, color: AppColors.textBody, height: 1.45);

    final novasClassificacoes = [
      if (r.novasCategorias.isNotEmpty) '${r.novasCategorias.length} tipo(s) de dispositivo: ${r.novasCategorias.join(', ')}',
      if (r.novasFamilias.isNotEmpty) '${r.novasFamilias.length} família(s): ${r.novasFamilias.join(', ')}',
      if (r.novosProdutos.isNotEmpty) '${r.novosProdutos.length} produto(s): ${r.novosProdutos.join(', ')}',
    ];
    final problemas = [
      if (resumo.duplicadasRemovidas > 0) '${fmt(resumo.duplicadasRemovidas)} repetições da mesma combinação removidas',
      if (resumo.linhasSemChave > 0) '${fmt(resumo.linhasSemChave)} linhas sem Código e Dispositivo ignoradas',
      if (resumo.linhasSemCodigo > 0) '${fmt(resumo.linhasSemCodigo)} linhas sem Código',
      if (resumo.linhasSemDispositivo > 0) '${fmt(resumo.linhasSemDispositivo)} linhas sem Dispositivo',
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        const Icon(LucideIcons.circleCheck, size: 20, color: AppColors.success),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text('${fmt(preview.total)} combinações únicas Código + Dispositivo',
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark, fontSize: 15)),
        ),
      ]),
      const SizedBox(height: AppSpacing.md),
      Row(children: [
        _Contador('Total', preview.total, AppColors.textDark),
        const SizedBox(width: AppSpacing.sm),
        _Contador('Novos', preview.novos, AppColors.success),
        const SizedBox(width: AppSpacing.sm),
        _Contador('Atualizados', preview.atualizados, AppColors.various02),
      ]),
      const SizedBox(height: AppSpacing.md),
      Text('${fmt(resumo.linhasLidas)} linhas lidas · ${fmt(resumo.duplicadasRemovidas)} repetições da mesma combinação removidas',
          style: corpo),
      for (final a in resumo.abas.where((a) => !a.ignorada))
        Text(
          'Aba "${a.nome}": ${fmt(a.linhas)} linhas · Código = ${a.colunaCodigo != null ? '"${a.colunaCodigo}"' : 'não encontrada'} · '
          'Dispositivo = ${a.colunaDispositivo != null ? '"${a.colunaDispositivo}"' : 'não encontrada'}',
          style: corpo,
        ),
      if (novasClassificacoes.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.md),
        InfoBox(tipo: InfoBoxTipo.aviso, titulo: 'Serão criadas', mensagem: novasClassificacoes.join('\n')),
      ],
      if (problemas.isNotEmpty || resumo.avisos.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.md),
        InfoBox(
          tipo: InfoBoxTipo.aviso,
          titulo: 'Linhas com problema',
          mensagem: [...problemas, ...resumo.avisos].join('\n'),
        ),
      ],
      const SizedBox(height: AppSpacing.md),
      const SectionLabel('Amostra'),
      AppCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (final (i, d) in r.dispositivos.take(_linhasAmostra).indexed) ...[
            if (i > 0) const Divider(),
            _LinhaAmostra(dispositivo: d, nomeCategoria: nomeCategoria),
          ],
          if (preview.total > _linhasAmostra) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('E mais ${fmt(preview.total - _linhasAmostra)} registros...',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.textBody)),
            ),
          ],
        ]),
      ),
      const SizedBox(height: AppSpacing.lg),
      if (importando) ...[
        const LinearProgressIndicator(),
        const SizedBox(height: AppSpacing.sm),
        Text('Gravando ${fmt(preview.total)} registros em lotes de 500...',
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: AppColors.textSubtle)),
        const SizedBox(height: AppSpacing.md),
      ],
      Wrap(alignment: WrapAlignment.end, spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
        AppButton(label: 'Voltar e Alterar', icon: LucideIcons.arrowLeft, onPressed: importando ? null : onVoltar),
        AppButton.primary(
          label: importando ? 'Importando...' : 'Salvar Importação (${fmt(preview.total)})',
          loading: importando,
          onPressed: importando ? null : onConfirmar,
        ),
      ]),
    ]);
  }
}

class _LinhaAmostra extends StatelessWidget {
  final Map<String, dynamic> dispositivo;
  final String Function(String id) nomeCategoria;
  const _LinhaAmostra({required this.dispositivo, required this.nomeCategoria});

  @override
  Widget build(BuildContext context) {
    final nome = (dispositivo['nome'] as String?) ?? '';
    final codigo = (dispositivo['codigo'] as String?) ?? '';
    final categoriaId = (dispositivo['categoriaId'] as String?) ?? '';
    final peso = (dispositivo['peso'] as String?) ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(nome.isEmpty ? 'Não informado' : nome,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: nome.isEmpty ? AppColors.textMuted : AppColors.textDark)),
        const SizedBox(height: 2),
        Text('Código: ${ouNaoInformado(codigo)} · Peso: ${formatarPeso(peso)}',
            style: const TextStyle(fontSize: 12.5, color: AppColors.textBody)),
        const SizedBox(height: 2),
        categoriaId.isEmpty
            ? const Text('Sem Categoria',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontStyle: FontStyle.italic))
            : Text('Categoria: ${nomeCategoria(categoriaId)}', style: const TextStyle(fontSize: 12.5, color: AppColors.textBody)),
      ]),
    );
  }
}

class _Concluido extends StatelessWidget {
  final ResultadoImportacaoLote resultado;
  final int enviados;
  final VoidCallback onNovo;
  const _Concluido({required this.resultado, required this.enviados, required this.onNovo});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        InfoBox(
          tipo: InfoBoxTipo.sucesso,
          titulo: 'Importação concluída!',
          mensagem: '${formatarNumero(resultado.inseridos)} inseridos e ${formatarNumero(resultado.atualizados)} atualizados '
              '(${formatarNumero(resultado.sucesso)} de ${formatarNumero(enviados)}).',
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(alignment: WrapAlignment.end, spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
          AppButton(label: 'Importar outro arquivo', icon: LucideIcons.rotateCcw, onPressed: onNovo),
          AppButton.primary(label: 'Fechar', onPressed: () => Navigator.of(context).maybePop()),
        ]),
      ]);
}
