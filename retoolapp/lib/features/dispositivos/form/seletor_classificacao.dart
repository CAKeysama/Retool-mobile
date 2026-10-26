import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/busca.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/classificacao.dart';
import '../../../presentation/state/retool_controller.dart';

/// Textos de cada tipo de classificação no formulário (copiados do desktop).
class TextosClassificacao {
  final String rotulo;
  final String placeholder;
  final String botaoNovo;
  final String hintNovo;
  final String helper;
  final String erroCriar;
  const TextosClassificacao({
    required this.rotulo,
    required this.placeholder,
    required this.botaoNovo,
    required this.hintNovo,
    required this.helper,
    required this.erroCriar,
  });

  static TextosClassificacao de(TipoClassificacao tipo) => switch (tipo) {
    TipoClassificacao.categoria => const TextosClassificacao(
      rotulo: 'CATEGORIA',
      placeholder: 'Selecione a Categoria',
      botaoNovo: 'Nova Categoria',
      hintNovo: 'Nome da categoria...',
      helper: 'Almoxarifado ou tipo de ativo',
      erroCriar: 'Erro ao cadastrar nova categoria.',
    ),
    TipoClassificacao.familia => const TextosClassificacao(
      rotulo: 'Família do Produto',
      placeholder: 'Selecione a Família',
      botaoNovo: 'Nova Família',
      hintNovo: 'Nome da família...',
      helper: 'Grupo de manufatura da peça (Substitui "Grupo")',
      erroCriar: 'Erro ao cadastrar nova família.',
    ),
    TipoClassificacao.produto => const TextosClassificacao(
      rotulo: 'Produto',
      placeholder: 'Selecione o Produto',
      botaoNovo: 'Novo Produto',
      hintNovo: 'Nome do produto...',
      helper: 'Nome comercial/modelo do produto associado',
      erroCriar: 'Erro ao cadastrar novo produto.',
    ),
  };
}

/// Seletor de Categoria/Família/Produto com busca e criação inline
/// (equivale ao `<select>` + "+ Nova ..." do `DispositivoForm.tsx`).
class SeletorClassificacao extends StatefulWidget {
  final TipoClassificacao tipo;
  final String? valor;
  final ValueChanged<String?> onChanged;
  final bool podeCriar;

  const SeletorClassificacao({
    super.key,
    required this.tipo,
    required this.valor,
    required this.onChanged,
    this.podeCriar = true,
  });

  @override
  State<SeletorClassificacao> createState() => _SeletorClassificacaoState();
}

class _ResultadoBusca {
  final String? id;
  final String? criarNome;
  const _ResultadoBusca({this.id, this.criarNome});
}

class _SeletorClassificacaoState extends State<SeletorClassificacao> {
  final _novoNome = TextEditingController();
  bool _mostrandoNovo = false;
  bool _salvando = false;

  /// Nomes recém-criados, exibidos até o snapshot do Firestore chegar.
  final Map<String, String> _criados = {};

  TextosClassificacao get _t => TextosClassificacao.de(widget.tipo);

  @override
  void dispose() {
    _novoNome.dispose();
    super.dispose();
  }

  Future<void> _criar(String nome) async {
    final n = nome.trim();
    if (n.isEmpty || _salvando) return;
    final retool = context.read<ReToolController>();
    setState(() => _salvando = true);
    try {
      final id = await retool.addClassificacao(widget.tipo, n);
      if (!mounted) return;
      if (id.isNotEmpty) {
        _criados[id] = n;
        widget.onChanged(id);
        _novoNome.clear();
        _mostrandoNovo = false;
      }
    } catch (_) {
      retool.announce(_t.erroCriar);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _abrirBusca(List<Classificacao> opcoes) async {
    final r = await showAppSheet<_ResultadoBusca>(
      context,
      titulo: _t.placeholder,
      rolavel: false,
      builder: (_) => _BuscaClassificacao(
        opcoes: opcoes,
        selecionado: widget.valor,
        placeholder: _t.placeholder,
        podeCriar: widget.podeCriar,
      ),
    );
    if (r == null || !mounted) return;
    if (r.criarNome != null) {
      await _criar(r.criarNome!);
    } else {
      widget.onChanged(r.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final todas = context.select<ReToolController, List<Classificacao>>((r) => r.classificacoes(widget.tipo));
    // Inativas só aparecem se já estiverem selecionadas (regra do desktop).
    final opcoes = todas.where((c) => c.ativo || c.id == widget.valor).toList();
    final atual = todas.where((c) => c.id == widget.valor).firstOrNull;
    final valorVazio = widget.valor == null || widget.valor!.isEmpty;
    final texto = valorVazio
        ? null
        : atual != null
        ? '${atual.nome}${atual.ativo ? '' : ' (Inativo)'}'
        : _criados[widget.valor] ?? 'Não encontrado';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: FieldLabel(_t.rotulo)),
            if (widget.podeCriar)
              TextButton.icon(
                key: Key('novo_${widget.tipo.name}'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                onPressed: () => setState(() {
                  _mostrandoNovo = !_mostrandoNovo;
                  if (!_mostrandoNovo) _novoNome.clear();
                }),
                icon: const Icon(LucideIcons.plus, size: 14),
                label: Text(_t.botaoNovo),
              ),
          ],
        ),
        if (_mostrandoNovo) ...[
          TextField(
            key: Key('novo_${widget.tipo.name}_nome'),
            controller: _novoNome,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: _criar,
            decoration: InputDecoration(hintText: _t.hintNovo),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppButton(
                label: 'Cancelar',
                compact: true,
                onPressed: () => setState(() {
                  _mostrandoNovo = false;
                  _novoNome.clear();
                }),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton.primary(
                key: Key('salvar_novo_${widget.tipo.name}'),
                label: 'Salvar',
                compact: true,
                loading: _salvando,
                onPressed: _novoNome.text.trim().isEmpty ? null : () => _criar(_novoNome.text),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Semantics(
          button: true,
          label: '${_t.rotulo}: ${texto ?? _t.placeholder}',
          excludeSemantics: true,
          child: InkWell(
            key: Key('seletor_${widget.tipo.name}'),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: () => _abrirBusca(opcoes),
            child: InputDecorator(
              decoration: const InputDecoration(suffixIcon: Icon(LucideIcons.chevronDown, size: 18)),
              child: Text(
                texto ?? _t.placeholder,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, color: texto == null ? AppColors.textMuted : AppColors.textDark),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(_t.helper, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ),
      ],
    );
  }
}

class _BuscaClassificacao extends StatefulWidget {
  final List<Classificacao> opcoes;
  final String? selecionado;
  final String placeholder;
  final bool podeCriar;
  const _BuscaClassificacao({
    required this.opcoes,
    required this.selecionado,
    required this.placeholder,
    required this.podeCriar,
  });

  @override
  State<_BuscaClassificacao> createState() => _BuscaClassificacaoState();
}

class _BuscaClassificacaoState extends State<_BuscaClassificacao> {
  final _busca = TextEditingController();
  late final List<String> _chaves = [for (final o in widget.opcoes) normalizarBusca(o.nome)];
  String _q = '';

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtradas = <Classificacao>[
      for (var i = 0; i < widget.opcoes.length; i++)
        if (_q.isEmpty || _chaves[i].contains(_q)) widget.opcoes[i],
    ];
    final textoBusca = _busca.text.trim();
    final existeIgual = _chaves.contains(normalizarBusca(textoBusca));
    final mostrarCriar = widget.podeCriar && textoBusca.isNotEmpty && !existeIgual;
    final temLimpar = widget.selecionado != null && widget.selecionado!.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
          child: AppSearchField(
            controller: _busca,
            hint: 'Buscar...',
            onChanged: (v) => setState(() => _q = normalizarBusca(v).trim()),
          ),
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            itemCount: filtradas.length + (temLimpar ? 1 : 0) + (mostrarCriar ? 1 : 0),
            itemBuilder: (context, i) {
              if (mostrarCriar) {
                if (i == 0) {
                  return ListTile(
                    leading: const Icon(LucideIcons.plus, color: AppColors.primary),
                    title: Text(
                      'Cadastrar "$textoBusca"',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                    onTap: () => Navigator.of(context).pop(_ResultadoBusca(criarNome: textoBusca)),
                  );
                }
                i--;
              }
              if (temLimpar) {
                if (i == 0) {
                  return ListTile(
                    leading: const Icon(LucideIcons.circleX, color: AppColors.textMuted),
                    title: Text(widget.placeholder, style: const TextStyle(color: AppColors.textSubtle)),
                    subtitle: const Text('Limpar seleção'),
                    onTap: () => Navigator.of(context).pop(const _ResultadoBusca()),
                  );
                }
                i--;
              }
              final c = filtradas[i];
              final sel = c.id == widget.selecionado;
              return ListTile(
                title: Text(
                  '${c.nome}${c.ativo ? '' : ' (Inativo)'}',
                  style: TextStyle(
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    color: sel ? AppColors.primary : AppColors.textDark,
                  ),
                ),
                trailing: sel ? const Icon(LucideIcons.check, color: AppColors.primary, size: 18) : null,
                onTap: () => Navigator.of(context).pop(_ResultadoBusca(id: c.id)),
              );
            },
          ),
        ),
        if (filtradas.isEmpty && !mostrarCriar)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Nenhum resultado encontrado.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
      ],
    );
  }
}
