import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/classificacao.dart';
import '../../../presentation/state/auth_controller.dart';
import '../../../presentation/state/retool_controller.dart';
import '../classificacoes_regras.dart';
import 'acoes_em_massa_sheet.dart';
import 'classificacao_form_sheet.dart';

/// Painel de um tipo de classificação: cartão com cabeçalho (título, contador,
/// explicação conceitual, ações em massa e "+"), busca, filtro e linhas enxutas.
class PainelClassificacao extends StatefulWidget {
  final TipoClassificacao tipo;

  /// id → nº de dispositivos que usam a classificação (pré-calculado por snapshot).
  final Map<String, int> vinculos;

  const PainelClassificacao({super.key, required this.tipo, required this.vinculos});

  @override
  State<PainelClassificacao> createState() => _PainelClassificacaoState();
}

class _PainelClassificacaoState extends State<PainelClassificacao> {
  final _busca = TextEditingController();
  Timer? _debounce;
  String _q = '';
  FiltroSituacao _filtro = FiltroSituacao.todos;
  bool _infoAberta = false;

  // Memoização: refiltra só quando a lista (snapshot), a busca ou o filtro mudam.
  List<Classificacao>? _base;
  String? _qBase;
  FiltroSituacao? _filtroBase;
  List<Classificacao> _filtrados = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _busca.dispose();
    super.dispose();
  }

  void _aoBuscar(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _q = v);
    });
  }

  List<Classificacao> _filtrar(List<Classificacao> lista) {
    if (!identical(lista, _base) || _q != _qBase || _filtro != _filtroBase) {
      _base = lista;
      _qBase = _q;
      _filtroBase = _filtro;
      _filtrados = filtrarClassificacoes(lista, _q, _filtro);
    }
    return _filtrados;
  }

  Future<void> _gerenciar(Classificacao c) async {
    final retool = context.read<ReToolController>();
    final tipo = widget.tipo;
    final acao = await mostrarGerenciarClassificacao(context, tipo, c, widget.vinculos[c.id] ?? 0);
    if (acao == null) return;
    switch (acao) {
      case AcaoGerenciar.alternarAtivo:
        await retool.updateClassificacao(tipo, c.id, {'ativo': !c.ativo});
      case AcaoGerenciar.excluir:
        await retool.deleteClassificacao(tipo, c.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final retool = context.watch<ReToolController>();
    final tipo = widget.tipo;
    final todos = retool.classificacoes(tipo);
    final lista = _filtrar(todos);
    final filtrando = _q.trim().isNotEmpty || _filtro != FiltroSituacao.todos;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.sm,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Cabecalho(
                tipo: tipo,
                contagem: todos.length,
                infoAberta: _infoAberta,
                onInfo: () => setState(() => _infoAberta = !_infoAberta),
                onBulk: auth.canEditar && todos.isNotEmpty
                    ? () => abrirAcoesEmMassa(context, tipo, widget.vinculos)
                    : null,
                onAdd: auth.canCadastrar ? () => abrirFormularioClassificacao(context, tipo) : null,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.topCenter,
                child: _infoAberta ? _Explicacao(tipo: tipo) : const SizedBox(width: double.infinity),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: AppSearchField(controller: _busca, hint: 'Buscar ${tipo.pluralMin}...', onChanged: _aoBuscar),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  children: [
                    for (final f in FiltroSituacao.values) ...[
                      ChoiceChip(
                        label: Text(f.rotulo),
                        selected: _filtro == f,
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _filtro == f ? Colors.white : AppColors.textBody,
                        ),
                        onSelected: (_) => setState(() => _filtro = f),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (filtrando)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            '${lista.length} de ${todos.length}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: lista.isEmpty
                    ? SingleChildScrollView(
                        child: todos.isEmpty
                            ? EmptyState(
                                icon: LucideIcons.tags,
                                titulo:
                                    'Nenhum${tipo.feminino ? 'a' : ''} ${tipo.rotuloMin} cadastrad${tipo.feminino ? 'a' : 'o'}',
                                descricao: auth.canCadastrar ? 'Toque em "+" para criar o primeiro registro.' : null,
                              )
                            : const EmptyState(
                                icon: LucideIcons.searchX,
                                titulo: 'Nenhum resultado',
                                descricao: 'Ajuste a busca ou o filtro de situação.',
                              ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: lista.length,
                        separatorBuilder: (_, _) => const Divider(indent: 12, endIndent: 12, color: AppColors.gray03),
                        itemBuilder: (_, i) {
                          final c = lista[i];
                          return LinhaClassificacao(
                            key: ValueKey(c.id),
                            tipo: tipo,
                            item: c,
                            vinculos: widget.vinculos[c.id] ?? 0,
                            podeEditar: auth.canEditar,
                            podeExcluir: auth.canExcluir,
                            onEditar: () => abrirFormularioClassificacao(context, tipo, atual: c),
                            onAtivar: () =>
                                context.read<ReToolController>().updateClassificacao(tipo, c.id, {'ativo': true}),
                            onDesativar: () =>
                                context.read<ReToolController>().updateClassificacao(tipo, c.id, {'ativo': false}),
                            onGerenciar: () => _gerenciar(c),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  final TipoClassificacao tipo;
  final int contagem;
  final bool infoAberta;
  final VoidCallback onInfo;
  final VoidCallback? onBulk;
  final VoidCallback? onAdd;

  const _Cabecalho({
    required this.tipo,
    required this.contagem,
    required this.infoAberta,
    required this.onInfo,
    this.onBulk,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(AppSpacing.md, 10, 10, 10),
    decoration: const BoxDecoration(
      color: Color(0xFFFAFAFA),
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: [
        Flexible(
          child: Semantics(
            header: true,
            child: Text(
              tipo.tituloPainel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$contagem',
            semanticsLabel: tipo.contagem(contagem),
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSubtle),
          ),
        ),
        IconButton(
          tooltip: tipo.infoAria,
          visualDensity: VisualDensity.compact,
          onPressed: onInfo,
          icon: Icon(LucideIcons.info, size: 16, color: infoAberta ? AppColors.primary : AppColors.textMuted),
        ),
        const Spacer(),
        if (onBulk != null) ...[
          AppIconButton(
            icon: LucideIcons.listChecks,
            tooltip: 'Ações em massa para ${tipo.tituloPainel}',
            size: 36,
            onPressed: onBulk,
          ),
          const SizedBox(width: 6),
        ],
        if (onAdd != null)
          AppIconButton(
            icon: LucideIcons.plus,
            tooltip: 'Criar novo registro em ${tipo.tituloPainel}',
            primary: true,
            size: 36,
            onPressed: onAdd,
          ),
      ],
    ),
  );
}

/// Explicação conceitual do painel (tooltip "i" do desktop, aberto por toque).
class _Explicacao extends StatelessWidget {
  final TipoClassificacao tipo;
  const _Explicacao({required this.tipo});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: tipo.infoDestaque,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: '${tipo.infoResto}\n'),
          TextSpan(
            text: tipo.infoExemplos,
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      ),
      style: const TextStyle(fontSize: 13.5, color: AppColors.textDark, height: 1.5),
    ),
  );
}

/// Linha enxuta: nome, badge "Inativo", nº de dispositivos e ações discretas.
class LinhaClassificacao extends StatelessWidget {
  final TipoClassificacao tipo;
  final Classificacao item;
  final int vinculos;
  final bool podeEditar;
  final bool podeExcluir;
  final VoidCallback onEditar;
  final VoidCallback onAtivar;
  final VoidCallback onDesativar;
  final VoidCallback onGerenciar;

  const LinhaClassificacao({
    super.key,
    required this.tipo,
    required this.item,
    required this.vinculos,
    required this.podeEditar,
    required this.podeExcluir,
    required this.onEditar,
    required this.onAtivar,
    required this.onDesativar,
    required this.onGerenciar,
  });

  Widget _botao(IconData icon, String tooltip, Color cor, VoidCallback onTap) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints.tightFor(width: 36, height: 36),
    padding: EdgeInsets.zero,
    icon: Icon(icon, size: 16, color: cor, semanticLabel: tooltip),
  );

  @override
  Widget build(BuildContext context) {
    final nome = item.nome.isEmpty ? 'Sem Nome' : item.nome;
    final r = tipo.rotuloMin;
    return InkWell(
      onTap: podeEditar ? onEditar : null,
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.md, right: 6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              Expanded(
                child: Opacity(
                  opacity: item.ativo ? 1 : 0.55,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textDark),
                        ),
                      ),
                      if (!item.ativo) ...[
                        const SizedBox(width: 6),
                        const Pill(label: 'Inativo', fundo: AppColors.gray02, texto: AppColors.gray00),
                      ],
                    ],
                  ),
                ),
              ),
              if (vinculos > 0)
                Tooltip(
                  message: '$vinculos dispositivo${vinculos == 1 ? '' : 's'} vinculado${vinculos == 1 ? '' : 's'}',
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6, right: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.component, size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Text('$vinculos', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ),
              if (podeEditar) _botao(LucideIcons.pencil, 'Editar $r $nome', AppColors.textMuted, onEditar),
              if (podeEditar && !item.ativo) _botao(LucideIcons.check, 'Ativar $r $nome', AppColors.success, onAtivar),
              // Sem exclusão (Projetista): desativação direta, reversível pelo "Ativar".
              if (podeEditar && !podeExcluir && item.ativo)
                _botao(LucideIcons.ban, 'Desativar $r $nome', AppColors.avisoText, onDesativar),
              if (podeExcluir)
                _botao(
                  LucideIcons.trash,
                  item.ativo ? 'Excluir ou desativar $r $nome' : 'Excluir $r $nome',
                  AppColors.danger,
                  onGerenciar,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum AcaoGerenciar { alternarAtivo, excluir }

/// Modal "Gerenciar/Excluir Categoria" do desktop: desativar (ou ativar) ou excluir permanentemente.
/// Avisa quantos dispositivos usam a classificação (não bloqueia, como o desktop).
Future<AcaoGerenciar?> mostrarGerenciarClassificacao(
  BuildContext context,
  TipoClassificacao tipo,
  Classificacao c,
  int vinculos,
) {
  final inativo = !c.ativo;
  final r = tipo.rotuloMin;
  return showDialog<AcaoGerenciar>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        inativo ? 'Excluir ${tipo.rotulo}' : 'Gerenciar ${tipo.rotulo}',
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Deseja excluir permanentemente ${tipo.comArtigo} '),
                  TextSpan(
                    text: c.nome,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                  TextSpan(text: inativo ? '?' : ' ou prefere apenas desativá-${tipo.feminino ? 'la' : 'lo'}?'),
                ],
              ),
              style: const TextStyle(color: AppColors.textBody, height: 1.45, fontSize: 14.5),
            ),
            if (vinculos > 0) ...[
              const SizedBox(height: AppSpacing.md),
              InfoBox(
                tipo: InfoBoxTipo.aviso,
                titulo: '$vinculos dispositivo${vinculos == 1 ? ' usa' : 's usam'} est${tipo.feminino ? 'a' : 'e'} $r',
                mensagem:
                    'Ao excluir, ${vinculos == 1 ? 'ele continuará cadastrado' : 'eles continuarão cadastrados'}, '
                    'mas sem $r válid${tipo.feminino ? 'a' : 'o'}. Desativar preserva o vínculo.',
              ),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actionsOverflowButtonSpacing: AppSpacing.sm,
      actions: [
        AppButton(label: 'Cancelar', compact: true, onPressed: () => Navigator.pop(ctx)),
        AppButton(
          label: inativo ? 'Ativar' : 'Desativar',
          compact: true,
          onPressed: () => Navigator.pop(ctx, AcaoGerenciar.alternarAtivo),
        ),
        AppButton.danger(
          label: 'Excluir Permanente',
          compact: true,
          onPressed: () => Navigator.pop(ctx, AcaoGerenciar.excluir),
        ),
      ],
    ),
  );
}
