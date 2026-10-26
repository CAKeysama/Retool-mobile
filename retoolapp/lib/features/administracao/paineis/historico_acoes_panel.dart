import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_dependencies.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/busca.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/audit_log.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../presentation/state/auth_controller.dart';
import '../historico_auditoria_controller.dart';
import '../widgets/admin_comum.dart';

const Map<AuditLogCategoria, ({Color fundo, Color texto})> coresCategoria = {
  AuditLogCategoria.autenticacao: (fundo: Color(0xFFE0F2FE), texto: Color(0xFF0369A1)),
  AuditLogCategoria.usuarios: (fundo: Color(0xFFF3E8FF), texto: Color(0xFF6B21A8)),
  AuditLogCategoria.dados: (fundo: Color(0xFFFEF3C7), texto: Color(0xFF92400E)),
  AuditLogCategoria.fluxo: (fundo: Color(0xFFCCFBF1), texto: Color(0xFF0F766E)),
};

const Map<AuditLogResultado, ({String label, Color fundo, Color texto})> coresResultado = {
  AuditLogResultado.sucesso: (label: 'Sucesso', fundo: Color(0xFFDCFCE7), texto: Color(0xFF15803D)),
  AuditLogResultado.falha: (label: 'Falha', fundo: Color(0xFFFEE2E2), texto: Color(0xFFB91C1C)),
  AuditLogResultado.negado: (label: 'Negado', fundo: Color(0xFFFFEDD5), texto: Color(0xFFC2410C)),
};

final _momento = DateFormat('dd/MM/yyyy HH:mm:ss', 'pt_BR');

String _formatarMomento(String iso) {
  final d = DateTime.tryParse(iso);
  return d == null ? iso : _momento.format(d.toLocal());
}

/// Início/fim do dia local em ISO UTC (limites inclusivos do período).
String inicioDoDiaIso(DateTime d) => DateTime(d.year, d.month, d.day).toUtc().toIso8601String();
String fimDoDiaIso(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999).toUtc().toIso8601String();

/// JSON dos detalhes do registro (o `<pre>` expandido do desktop).
String detalhesJson(AuditLog log) {
  final mapa = <String, Object?>{
    'detalhes': log.detalhes,
    'conteudo': log.conteudo,
    'dadosAnteriores': log.dadosAnteriores,
    'registroId': log.id,
  }..removeWhere((_, v) => v == null);
  return JsonEncoder.withIndent('  ', (o) => o.toString()).convert(mapa);
}

/// Histórico completo de ações (exclusivo da Administração): paginação no
/// servidor, filtros por categoria/ação/usuário/recurso/resultado/período e
/// detalhes estruturados de cada operação (`HistoricoAcoesPanel` do desktop).
class HistoricoAcoesPanel extends StatefulWidget {
  /// Tamanho inicial da página (25, como no desktop).
  final int tamanhoPagina;
  const HistoricoAcoesPanel({super.key, this.tamanhoPagina = 25});

  @override
  State<HistoricoAcoesPanel> createState() => _HistoricoAcoesPanelState();
}

class _HistoricoAcoesPanelState extends State<HistoricoAcoesPanel> {
  late final HistoricoAuditoriaController _h;
  final _busca = TextEditingController();
  Timer? _debounce;
  String _termo = '';
  DateTime? _de;
  DateTime? _ate;
  final Set<String> _expandidos = {};

  @override
  void initState() {
    super.initState();
    _h = HistoricoAuditoriaController(context.read<AppDependencies>().audit, widget.tamanhoPagina);
    if (context.read<AuthController>().canVerLogs) _h.recarregar();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _busca.dispose();
    _h.dispose();
    super.dispose();
  }

  void _aoBuscar(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _termo = normalizarBusca(v.trim()));
    });
  }

  void _limpar() {
    _debounce?.cancel();
    _busca.clear();
    setState(() {
      _termo = '';
      _de = _ate = null;
    });
    _h.aplicarFiltros(const FiltrosAuditoria());
  }

  Future<void> _abrirFiltros() async {
    final users = [...context.read<AuthController>().users]
      ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    final r = await showAppSheet<_ResultadoFiltros>(
      context,
      titulo: 'Filtrar histórico',
      builder: (_) => _FiltrosSheet(
        inicial: _h.filtros,
        de: _de,
        ate: _ate,
        tamanhoPagina: _h.tamanhoPagina,
        usuarios: users,
      ),
    );
    if (r == null || !mounted) return;
    setState(() {
      _de = r.de;
      _ate = r.ate;
    });
    if (r.tamanhoPagina != _h.tamanhoPagina) {
      _h.setTamanhoPagina(r.tamanhoPagina);
    }
    _h.aplicarFiltros(r.filtros);
  }

  List<AuditLog> _visiveis() {
    if (_termo.isEmpty) return _h.logs;
    return _h.logs
        .where((l) => [l.usuarioNome, l.usuarioEmail, l.entidadeNome, l.entidadeId, l.acaoDescricao, l.detalhes]
            .any((v) => v != null && normalizarBusca(v).contains(_termo)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final canVerLogs = context.select<AuthController, bool>((a) => a.canVerLogs);
    if (!canVerLogs) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: _h,
      builder: (context, _) {
        final visiveis = _visiveis();
        final temFiltros = _h.temFiltros || _termo.isNotEmpty;
        final total = _h.total;
        return RefreshIndicator(
          onRefresh: _h.recarregar,
          child: CustomScrollView(slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
              sliver: SliverList.list(children: [
                if (_h.haNovos) ...[
                  AvisoAdmin(
                    tipo: TipoAviso.info,
                    texto: 'Há novos registros no histórico.',
                    acao: GestureDetector(
                      onTap: _h.recarregar,
                      child: const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('Atualizar lista',
                            style: TextStyle(
                                color: Color(0xFF1D4ED8),
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline)),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Row(children: [
                  Expanded(
                    child: AppSearchField(
                      controller: _busca,
                      hint: 'Buscar nos registros carregados...',
                      onChanged: _aoBuscar,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Badge(
                    isLabelVisible: _h.quantidadeFiltros > 0,
                    backgroundColor: AppColors.primary,
                    label: Text('${_h.quantidadeFiltros}'),
                    child: AppIconButton(
                      icon: LucideIcons.funnel,
                      tooltip: 'Filtros',
                      size: 44,
                      onPressed: _abrirFiltros,
                    ),
                  ),
                ]),
                const SizedBox(height: AppSpacing.sm),
                Row(children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: total == null ? 'Contando registros...' : '$total ${total == 1 ? 'registro' : 'registros'}'),
                        if (_termo.isNotEmpty && _h.estado == EstadoConsulta.pronto)
                          TextSpan(
                            text: ' · ${visiveis.length} após a busca',
                            style: const TextStyle(color: AppColors.textSubtle, fontWeight: FontWeight.w500),
                          ),
                      ]),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                    ),
                  ),
                  if (temFiltros) ...[
                    BotaoAcao(label: 'Limpar filtros', onPressed: _limpar),
                    const SizedBox(width: 4),
                  ],
                  IconButton(
                    tooltip: 'Atualizar histórico',
                    icon: const Icon(LucideIcons.refreshCw, size: 18),
                    onPressed: _h.recarregar,
                  ),
                ]),
              ]),
            ),
            ..._conteudo(visiveis, temFiltros),
          ]),
        );
      },
    );
  }

  List<Widget> _conteudo(List<AuditLog> visiveis, bool temFiltros) {
    switch (_h.estado) {
      case EstadoConsulta.carregando:
        return const [SliverToBoxAdapter(child: EstadoCarregando(mensagem: 'Carregando histórico de ações...'))];
      case EstadoConsulta.erro:
        return [SliverToBoxAdapter(child: EstadoErro(mensagem: _h.erro, onTentarNovamente: _h.recarregar))];
      case EstadoConsulta.pronto:
        if (visiveis.isEmpty) {
          return [
            SliverToBoxAdapter(
              child: FilaVazia(_h.logs.isEmpty
                  ? (temFiltros ? 'Nenhum registro encontrado para os filtros atuais.' : 'Nenhuma ação registrada até o momento.')
                  : 'Nenhum registro carregado corresponde à busca.'),
            ),
            ..._rodape(),
          ];
        }
        return [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            sliver: SliverList.separated(
              itemCount: visiveis.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) {
                final log = visiveis[i];
                final aberto = _expandidos.contains(log.id);
                return _CartaoLog(
                  key: ValueKey('log-${log.id}'),
                  log: log,
                  aberto: aberto,
                  onTap: () => setState(() => aberto ? _expandidos.remove(log.id) : _expandidos.add(log.id)),
                );
              },
            ),
          ),
          ..._rodape(),
        ];
    }
  }

  List<Widget> _rodape() {
    final total = _h.total;
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
        sliver: SliverToBoxAdapter(
          child: Column(children: [
            if (_h.erroMais != null) ...[
              AvisoAdmin(tipo: TipoAviso.erro, texto: _h.erroMais!),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (_h.temMais)
              BotaoAcao(
                label: _h.carregandoMais ? 'Carregando...' : 'Carregar mais',
                icon: LucideIcons.chevronDown,
                loading: _h.carregandoMais,
                onPressed: _h.carregarMais,
              ),
            if (_h.logs.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              TextoSecundario(
                'Exibindo ${_h.logs.length}${total != null ? ' de $total' : ''} ${(total ?? _h.logs.length) == 1 ? 'registro' : 'registros'}',
                tamanho: 12.5,
              ),
            ],
          ]),
        ),
      ),
    ];
  }
}

class _CartaoLog extends StatelessWidget {
  final AuditLog log;
  final bool aberto;
  final VoidCallback onTap;
  const _CartaoLog({super.key, required this.log, required this.aberto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cat = coresCategoria[log.categoria]!;
    final res = coresResultado[log.resultado]!;
    final temDetalhes = log.conteudo != null || log.dadosAnteriores != null || log.detalhes != null;
    return CartaoAdmin(
      cor: aberto ? const Color(0xFFFAFAFA) : null,
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Flexible(
            child: Pill(label: log.acao.rotulo, fundo: cat.fundo, texto: cat.texto, tooltip: log.categoria.rotulo),
          ),
          const SizedBox(width: 6),
          Pill(label: res.label, fundo: res.fundo, texto: res.texto),
          const Spacer(),
          AnimatedRotation(
            turns: aberto ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: Icon(LucideIcons.chevronDown, size: 18, color: AppColors.textMuted,
                semanticLabel: aberto ? 'Recolher detalhes' : 'Expandir detalhes'),
          ),
        ]),
        const SizedBox(height: 6),
        Text(log.acaoDescricao ?? log.detalhes ?? log.acao.rotulo,
            style: const TextStyle(fontSize: 14, color: Color(0xFF111827), fontWeight: FontWeight.w500, height: 1.4)),
        const SizedBox(height: 8),
        _Linha(icon: LucideIcons.clock, child: TextoSecundario(_formatarMomento(log.dataHora), tamanho: 12.5)),
        const SizedBox(height: 4),
        _Linha(
          icon: LucideIcons.userRound,
          child: Wrap(spacing: 6, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(log.usuarioNome.isEmpty ? '—' : log.usuarioNome,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
            RoleBadge(perfil: log.usuarioPerfil, curto: true),
            TextoSecundario(log.usuarioEmail.isEmpty ? 'sistema' : log.usuarioEmail, tamanho: 12),
          ]),
        ),
        const SizedBox(height: 4),
        _Linha(
          icon: LucideIcons.fileText,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(
              TextSpan(children: [
                TextSpan(text: log.tipoEntidade.rotulo, style: const TextStyle(fontWeight: FontWeight.w600)),
                if ((log.entidadeNome ?? '').isNotEmpty) TextSpan(text: ' · ${log.entidadeNome}'),
              ]),
              style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
            ),
            if (log.entidadeId.isNotEmpty) TextoSecundario('ID: ${log.entidadeId}', cor: AppColors.textMuted, tamanho: 11.5),
          ]),
        ),
        if (aberto) ...[
          const SizedBox(height: 10),
          if (temDetalhes)
            Container(
              key: ValueKey('detalhes-${log.id}'),
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 260),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  detalhesJson(log),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: Color(0xFF1F2937), height: 1.4),
                ),
              ),
            )
          else
            TextoSecundario('Sem informações adicionais. ID do registro: ${log.id}', tamanho: 12.5),
        ],
      ]),
    );
  }
}

class _Linha extends StatelessWidget {
  final IconData icon;
  final Widget child;
  const _Linha({required this.icon, required this.child});

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 14, color: AppColors.textMuted)),
        const SizedBox(width: 6),
        Expanded(child: child),
      ]);
}

typedef _ResultadoFiltros = ({FiltrosAuditoria filtros, DateTime? de, DateTime? ate, int tamanhoPagina});

class _FiltrosSheet extends StatefulWidget {
  final FiltrosAuditoria inicial;
  final DateTime? de;
  final DateTime? ate;
  final int tamanhoPagina;
  final List<UserProfile> usuarios;
  const _FiltrosSheet({
    required this.inicial,
    required this.de,
    required this.ate,
    required this.tamanhoPagina,
    required this.usuarios,
  });

  @override
  State<_FiltrosSheet> createState() => _FiltrosSheetState();
}

class _FiltrosSheetState extends State<_FiltrosSheet> {
  late AuditLogCategoria? _categoria = widget.inicial.categoria;
  late AuditLogAcao? _acao = widget.inicial.acao;
  late String? _usuarioUid = widget.inicial.usuarioUid;
  late AuditLogTipoEntidade? _tipo = widget.inicial.tipoEntidade;
  late bool _somenteFalhas = widget.inicial.somenteFalhas;
  late DateTime? _de = widget.de;
  late DateTime? _ate = widget.ate;
  late int _tamanho = widget.tamanhoPagina;
  int _versao = 0;

  Future<void> _escolherData(bool inicio) async {
    final agora = DateTime.now();
    final atual = inicio ? _de : _ate;
    final escolhida = await showDatePicker(
      context: context,
      initialDate: atual ?? (inicio ? (_ate ?? agora) : agora),
      firstDate: inicio ? DateTime(2020) : (_de ?? DateTime(2020)),
      lastDate: inicio ? (_ate ?? DateTime(agora.year + 1, 12, 31)) : DateTime(agora.year + 1, 12, 31),
      helpText: inicio ? 'De' : 'Até',
    );
    if (escolhida == null || !mounted) return;
    setState(() => inicio ? _de = escolhida : _ate = escolhida);
  }

  void _limpar() => setState(() {
        _categoria = null;
        _acao = null;
        _usuarioUid = null;
        _tipo = null;
        _somenteFalhas = false;
        _de = _ate = null;
        _versao++;
      });

  void _aplicar() {
    Navigator.of(context).pop<_ResultadoFiltros>((
      filtros: FiltrosAuditoria(
        categoria: _categoria,
        acao: _acao,
        usuarioUid: _usuarioUid,
        tipoEntidade: _tipo,
        somenteFalhas: _somenteFalhas,
        de: _de == null ? null : inicioDoDiaIso(_de!),
        ate: _ate == null ? null : fimDoDiaIso(_ate!),
      ),
      de: _de,
      ate: _ate,
      tamanhoPagina: _tamanho,
    ));
  }

  Widget _data(String rotulo, DateTime? valor, bool inicio) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FieldLabel(rotulo),
          OutlinedButton.icon(
            key: ValueKey('periodo-$rotulo'),
            onPressed: () => _escolherData(inicio),
            icon: const Icon(LucideIcons.calendar, size: 16),
            label: Text(valor == null ? 'dd/mm/aaaa' : formatarData(valor.toIso8601String()),
                overflow: TextOverflow.ellipsis),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              alignment: Alignment.centerLeft,
              foregroundColor: valor == null ? AppColors.textMuted : AppColors.textDark,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
            ),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final acoes = _categoria != null ? acoesPorCategoria[_categoria]! : AuditLogAcao.values;
    const espaco = SizedBox(height: AppSpacing.md);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppDropdown<AuditLogCategoria?>(
        key: ValueKey('f-categoria-$_versao'),
        label: 'Categoria',
        value: _categoria,
        onChanged: (v) => setState(() {
          _categoria = v;
          _acao = null;
        }),
        items: [
          const DropdownMenuItem(value: null, child: Text('Todas as categorias')),
          for (final c in AuditLogCategoria.values) DropdownMenuItem(value: c, child: Text(c.rotulo)),
        ],
      ),
      espaco,
      AppDropdown<AuditLogAcao?>(
        key: ValueKey('f-acao-$_versao-$_categoria'),
        label: 'Ação',
        value: _acao,
        onChanged: (v) => setState(() => _acao = v),
        items: [
          const DropdownMenuItem(value: null, child: Text('Todas as ações')),
          for (final a in acoes) DropdownMenuItem(value: a, child: Text(a.rotulo)),
        ],
      ),
      espaco,
      AppDropdown<String?>(
        key: ValueKey('f-usuario-$_versao'),
        label: 'Usuário',
        value: widget.usuarios.any((u) => u.uid == _usuarioUid) ? _usuarioUid : null,
        onChanged: (v) => setState(() => _usuarioUid = v),
        items: [
          const DropdownMenuItem(value: null, child: Text('Todos os usuários')),
          for (final u in widget.usuarios)
            DropdownMenuItem(value: u.uid, child: Text('${u.nome} (${u.email})', overflow: TextOverflow.ellipsis)),
        ],
      ),
      espaco,
      AppDropdown<AuditLogTipoEntidade?>(
        key: ValueKey('f-recurso-$_versao'),
        label: 'Recurso',
        value: _tipo,
        onChanged: (v) => setState(() => _tipo = v),
        items: [
          const DropdownMenuItem(value: null, child: Text('Todos os recursos')),
          for (final t in AuditLogTipoEntidade.values) DropdownMenuItem(value: t, child: Text(t.rotulo)),
        ],
      ),
      espaco,
      AppDropdown<bool>(
        key: ValueKey('f-resultado-$_versao'),
        label: 'Resultado',
        value: _somenteFalhas,
        onChanged: (v) => setState(() => _somenteFalhas = v ?? false),
        items: const [
          DropdownMenuItem(value: false, child: Text('Todos os resultados')),
          DropdownMenuItem(value: true, child: Text('Somente falhas e acessos negados', overflow: TextOverflow.ellipsis)),
        ],
      ),
      espaco,
      Row(children: [
        _data('De', _de, true),
        const SizedBox(width: AppSpacing.sm),
        _data('Até', _ate, false),
      ]),
      espaco,
      AppDropdown<int>(
        label: 'Registros por carga',
        value: _tamanho,
        onChanged: (v) => setState(() => _tamanho = v ?? _tamanho),
        items: [for (final n in const [25, 50, 100]) DropdownMenuItem(value: n, child: Text('$n por carga'))],
      ),
      const SizedBox(height: AppSpacing.lg),
      Row(children: [
        Expanded(child: AppButton(label: 'Limpar', expand: true, onPressed: _limpar)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 2,
          child: AppButton.primary(label: 'Aplicar filtros', icon: LucideIcons.check, expand: true, onPressed: _aplicar),
        ),
      ]),
    ]);
  }
}
