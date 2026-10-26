import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/classificacao.dart';
import '../../../domain/entities/dispositivo.dart';
import '../../../presentation/state/auth_controller.dart';
import '../../../presentation/state/retool_controller.dart';

/// Laranja do botão "Solicitar Reutilização" do desktop (`#ea580c`).
const corSolicitarReutilizacao = Color(0xFFEA580C);

/// Abre o formulário de reutilização de um dispositivo em bottom sheet.
///
/// - `registroDireto: false` (padrão): equivale ao `SolicitarReutilizacaoModal` do desktop —
///   a solicitação nasce "Em análise (Engenharia)" na Fila da Engenharia.
/// - `registroDireto: true`: equivale ao modal "Nova Reutilização" da página de detalhes
///   (Projetista/Administração) — o registro nasce "Reutilização aprovada".
Future<void> mostrarSolicitarReutilizacao(
  BuildContext context, {
  required String dispositivoId,
  bool registroDireto = false,
}) async {
  final auth = context.read<AuthController>();
  final retool = context.read<ReToolController>();
  final disp = retool.dispositivo(dispositivoId);
  if (disp == null) {
    Toasts.mostrar('Dispositivo não encontrado.', erro: true);
    return;
  }
  if (registroDireto ? !auth.canCadastrar : !auth.canSolicitar) {
    Toasts.mostrar(
      registroDireto
          ? 'Acesso negado: seu perfil não tem permissão para cadastrar reutilizações diretamente.'
          : 'Acesso negado: seu perfil possui acesso somente de consulta.',
      erro: true,
    );
    return;
  }
  final idCurto = disp.id.substring(0, math.min(8, disp.id.length));
  await showAppSheet<void>(
    context,
    titulo: registroDireto ? 'Nova Reutilização' : 'Solicitar Reutilização de Dispositivo',
    subtitulo: 'Dispositivo: ${disp.nome ?? 'Sem Nome'} (ID: $idCurto)',
    builder: (_) => SolicitarReutilizacaoForm(dispositivo: disp, registroDireto: registroDireto),
  );
}

/// Converte texto numérico digitado no celular em `double`, aceitando vírgula decimal
/// e separador de milhar (`1.234,56`). Vazio ou inválido = null.
double? lerNumeroBr(String? texto) {
  final t = (texto ?? '').trim().replaceAll(' ', '').replaceAll(r'R$', '');
  if (t.isEmpty) return null;
  final normalizado = t.contains(',') ? t.replaceAll('.', '').replaceAll(',', '.') : t;
  return double.tryParse(normalizado);
}

String _numeroParaCampo(double? v) {
  if (v == null || v == 0) return '';
  final texto = v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
  return texto.replaceAll('.', ',');
}

final _formatoDataIso = DateFormat('yyyy-MM-dd');

/// Botão laranja "Solicitar Reutilização" (mesma cor do desktop).
class BotaoSolicitarReutilizacao extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool expand;
  const BotaoSolicitarReutilizacao({super.key, required this.onPressed, this.expand = false});

  @override
  Widget build(BuildContext context) => Material(
    color: corSolicitarReutilizacao,
    shape: const StadiumBorder(),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(LucideIcons.send, size: 16, color: Colors.white),
              SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  'Solicitar Reutilização',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Formulário de solicitação (Engenharia) ou registro direto (Projetista/Admin) de reutilização.
class SolicitarReutilizacaoForm extends StatefulWidget {
  final Dispositivo dispositivo;
  final bool registroDireto;

  /// Data inicial (testes); padrão = hoje.
  final DateTime? dataInicial;

  const SolicitarReutilizacaoForm({
    super.key,
    required this.dispositivo,
    this.registroDireto = false,
    this.dataInicial,
  });

  @override
  State<SolicitarReutilizacaoForm> createState() => _SolicitarReutilizacaoFormState();
}

class _SolicitarReutilizacaoFormState extends State<SolicitarReutilizacaoForm> {
  static const _novoProduto = '__novo__';

  final _form = GlobalKey<FormState>();
  late final _codigo = TextEditingController();
  late final _descricaoPeca = TextEditingController();
  late final _peso = TextEditingController();
  late final _hardSaving = TextEditingController();
  late final _responsavel = TextEditingController();
  late final _numeroOs = TextEditingController();
  late final _descricaoAlteracao = TextEditingController();
  late final _nomeNovoProduto = TextEditingController();

  late DateTime _data;
  String? _produtoId;
  String? _erro;
  bool _enviando = false;

  bool get _direto => widget.registroDireto;

  @override
  void initState() {
    super.initState();
    final agora = widget.dataInicial ?? DateTime.now();
    _data = DateTime(agora.year, agora.month, agora.day);
    final retool = context.read<ReToolController>();
    final auth = context.read<AuthController>();
    final d = widget.dispositivo;
    if (_direto) {
      // Mesmo pré-preenchimento do "Nova Reutilização" do desktop.
      _codigo.text = d.codigo ?? '';
      _descricaoPeca.text = d.nome ?? '';
      _produtoId = retool.produto(d.produtoId) != null ? d.produtoId : null;
      _peso.text = _numeroParaCampo(lerNumeroBr(d.peso));
    } else {
      _produtoId = retool.produtos.firstOrNull?.id;
      _responsavel.text = auth.userProfile?.nome ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [
      _codigo,
      _descricaoPeca,
      _peso,
      _hardSaving,
      _responsavel,
      _numeroOs,
      _descricaoAlteracao,
      _nomeNovoProduto,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _obrigatorio(String? v) => _direto && (v == null || v.trim().isEmpty) ? 'Preencha este campo.' : null;

  String? _numero(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return _obrigatorio(v);
    final n = lerNumeroBr(t);
    if (n == null || n < 0) return 'Informe um número válido.';
    // No desktop, 0 em campo obrigatório equivale a vazio (`value || ''`).
    if (_direto && n == 0) return 'Preencha este campo.';
    return null;
  }

  Future<void> _escolherData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Data da Reutilização',
    );
    if (escolhida != null && mounted) setState(() => _data = escolhida);
  }

  Future<void> _enviar() async {
    if (_enviando) return;
    setState(() => _erro = null);
    final valido = _form.currentState?.validate() ?? false;
    if (!_direto && (_codigo.text.trim().isEmpty || _descricaoAlteracao.text.trim().isEmpty)) {
      setState(() => _erro = 'Preencha o código da peça e a descrição da alteração pretendida.');
      return;
    }
    if (!valido) return;
    if (_direto && _produtoId == null) {
      setState(() => _erro = 'Selecione um produto.');
      return;
    }
    if (_direto && _produtoId == _novoProduto && _nomeNovoProduto.text.trim().isEmpty) {
      setState(() => _erro = 'Por favor, digite o nome do novo produto.');
      return;
    }

    final retool = context.read<ReToolController>();
    final auth = context.read<AuthController>();
    final navegador = Navigator.of(context);
    setState(() => _enviando = true);
    try {
      var produtoId = _produtoId;
      if (produtoId == _novoProduto) {
        produtoId = await retool.addClassificacao(TipoClassificacao.produto, _nomeNovoProduto.text.trim());
        if (produtoId.isEmpty) return;
      }
      final d = widget.dispositivo;
      final solicitante = auth.userProfile?.nome ?? 'Engenharia de Processo';
      final dados = <String, dynamic>{
        'dispositivoId': d.id,
        'data': _formatoDataIso.format(_data),
        'codigoPeca': _codigo.text.trim(),
        'descricaoPeca': _direto
            ? _descricaoPeca.text.trim()
            : (_descricaoPeca.text.trim().isNotEmpty ? _descricaoPeca.text.trim() : (d.nome ?? '')),
        'produtoId': _direto ? produtoId : (produtoId ?? retool.produtos.firstOrNull?.id ?? 'padrao'),
        'pesoPeca': lerNumeroBr(_peso.text) ?? 0.0,
        'hardSaving': lerNumeroBr(_hardSaving.text) ?? 0.0,
        'responsavel': _direto
            ? _responsavel.text.trim()
            : (_responsavel.text.trim().isNotEmpty ? _responsavel.text.trim() : solicitante),
        'numeroOs': _numeroOs.text.trim(),
        'descricaoAlteracao': _descricaoAlteracao.text.trim(),
      };
      if (_direto) {
        await retool.addReutilizacao(dados);
      } else {
        await retool.solicitarReutilizacao(dados);
      }
      if (navegador.canPop()) navegador.pop();
    } catch (e) {
      if (mounted) setState(() => _erro = 'Erro ao enviar solicitação.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Widget _par(Widget a, Widget b) => LayoutBuilder(
    builder: (context, c) => c.maxWidth < 420
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

  @override
  Widget build(BuildContext context) {
    final produtos = context.select<ReToolController, List<Classificacao>>((r) => r.produtos);
    final teclado = const TextInputType.numberWithOptions(decimal: true);
    final soNumeros = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    final produtoValido = _produtoId == _novoProduto || produtos.any((p) => p.id == _produtoId);

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_erro != null) ...[
            InfoBox(tipo: InfoBoxTipo.erro, mensagem: _erro!),
            const SizedBox(height: AppSpacing.md),
          ],
          if (!_direto) ...[
            const InfoBox(
              tipo: InfoBoxTipo.aviso,
              titulo: 'Fluxo de Aprovação',
              mensagem:
                  'A Engenharia formula a solicitação de reutilização. Ela entrará com status '
                  'Em análise (Engenharia) e será analisada e aprovada pelo Projetista da Ferramentaria.',
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          _par(
            _CampoData(data: _data, onTap: _escolherData),
            AppTextField(
              key: const Key('reu_os'),
              label: _direto ? 'Nº OS (Ordem de Serviço)' : 'Número da O.S. (Ordem de Serviço)',
              hint: _direto ? 'Ex: OS-24567' : 'Ex: OS-2026-104',
              controller: _numeroOs,
              obrigatorio: _direto,
              validator: _obrigatorio,
              textInputAction: TextInputAction.next,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _par(
            AppTextField(
              key: const Key('reu_codigo'),
              label: _direto ? 'Código da Peça' : 'Código da Nova Peça',
              hint: _direto ? 'Ex: 51500101580' : 'Ex: PC-9842',
              controller: _codigo,
              obrigatorio: true,
              validator: _obrigatorio,
              textInputAction: TextInputAction.next,
            ),
            AppTextField(
              key: const Key('reu_descricao_peca'),
              label: 'Descrição da Peça',
              hint: _direto ? 'Ex: SUP DIR LONGO DIANT' : 'Descrição da nova peça ou modelo',
              controller: _descricaoPeca,
              obrigatorio: _direto,
              validator: _obrigatorio,
              textInputAction: TextInputAction.next,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _par(
            AppDropdown<String>(
              key: ValueKey('reu_produto_${produtos.length}_$_produtoId'),
              label: _direto ? 'Produto' : 'Produto / Projeto Destino',
              hint: produtos.isEmpty && !_direto ? 'Nenhum produto cadastrado' : 'Selecione um produto',
              obrigatorio: _direto,
              value: produtoValido ? _produtoId : null,
              items: [
                for (final p in produtos)
                  DropdownMenuItem(
                    value: p.id,
                    child: Text(p.nome, overflow: TextOverflow.ellipsis),
                  ),
                if (_direto) const DropdownMenuItem(value: _novoProduto, child: Text('Outro (cadastrar novo)...')),
              ],
              onChanged: (v) => setState(() => _produtoId = v),
            ),
            AppTextField(
              key: const Key('reu_peso'),
              label: _direto ? 'Peso da Peça (kg)' : 'Peso Estimado (kg)',
              hint: _direto ? 'Ex: 2,150' : '0,00',
              controller: _peso,
              obrigatorio: _direto,
              keyboardType: teclado,
              inputFormatters: soNumeros,
              validator: _numero,
              textInputAction: TextInputAction.next,
            ),
          ),
          if (_direto && _produtoId == _novoProduto) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: AppTextField(
                key: const Key('reu_novo_produto'),
                label: 'Nome do Novo Produto',
                hint: 'Ex: SPE5500',
                controller: _nomeNovoProduto,
                obrigatorio: true,
                validator: _obrigatorio,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _par(
            AppTextField(
              key: const Key('reu_hard_saving'),
              label: _direto ? 'Hard Saving (R\$)' : 'Hard Saving Estimado (R\$)',
              hint: _direto ? 'Ex: 22300,00' : '0,00',
              controller: _hardSaving,
              obrigatorio: _direto,
              keyboardType: teclado,
              inputFormatters: soNumeros,
              validator: _numero,
              textInputAction: TextInputAction.next,
            ),
            AppTextField(
              key: const Key('reu_responsavel'),
              label: 'Responsável',
              hint: 'Ex: João Silva',
              controller: _responsavel,
              obrigatorio: _direto,
              validator: _obrigatorio,
              textInputAction: TextInputAction.next,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            key: const Key('reu_descricao_alteracao'),
            label: _direto ? 'Descrição da Alteração Realizada' : 'Descrição da Alteração / Justificativa Técnica',
            hint: _direto
                ? 'Descreva as adaptações no dispositivo...'
                : 'Descreva as modificações mecânicas/elétricas necessárias para reaproveitar este dispositivo...',
            controller: _descricaoAlteracao,
            obrigatorio: true,
            maxLines: 4,
            validator: _obrigatorio,
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppButton(label: 'Cancelar', onPressed: _enviando ? null : () => Navigator.of(context).maybePop()),
              if (_direto)
                AppButton.primary(
                  label: 'Registrar Reutilização',
                  icon: LucideIcons.plus,
                  loading: _enviando,
                  onPressed: _enviar,
                )
              else
                _BotaoEnviar(enviando: _enviando, onPressed: _enviar),
            ],
          ),
        ],
      ),
    );
  }
}

class _BotaoEnviar extends StatelessWidget {
  final bool enviando;
  final VoidCallback onPressed;
  const _BotaoEnviar({required this.enviando, required this.onPressed});

  @override
  Widget build(BuildContext context) => Material(
    color: corSolicitarReutilizacao,
    shape: const StadiumBorder(),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: enviando ? null : onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (enviando)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            else
              const Icon(LucideIcons.send, size: 16, color: Colors.white),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                enviando ? 'Enviando...' : 'Enviar Solicitação',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CampoData extends StatelessWidget {
  final DateTime data;
  final VoidCallback onTap;
  const _CampoData({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      const FieldLabel('Data da Reutilização', obrigatorio: true),
      InkWell(
        key: const Key('reu_data'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InputDecorator(
          decoration: const InputDecoration(suffixIcon: Icon(LucideIcons.calendar, size: 18)),
          child: Text(
            formatarData(_formatoDataIso.format(data)),
            style: const TextStyle(fontSize: 15, color: AppColors.textDark),
          ),
        ),
      ),
    ],
  );
}
