import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/classificacao.dart';
import '../../../presentation/state/retool_controller.dart';
import '../classificacoes_regras.dart';

/// Abre o formulário "Nova/Editar Categoria|Família|Produto" (modal do desktop → bottom sheet).
Future<void> abrirFormularioClassificacao(BuildContext context, TipoClassificacao tipo, {Classificacao? atual}) =>
    showAppSheet<void>(
      context,
      titulo: atual == null ? tipo.tituloNovo : tipo.tituloEditar,
      builder: (_) => ClassificacaoForm(tipo: tipo, atual: atual),
    );

class ClassificacaoForm extends StatefulWidget {
  final TipoClassificacao tipo;
  final Classificacao? atual;
  const ClassificacaoForm({super.key, required this.tipo, this.atual});

  @override
  State<ClassificacaoForm> createState() => _ClassificacaoFormState();
}

class _ClassificacaoFormState extends State<ClassificacaoForm> {
  late final _nome = TextEditingController(text: widget.atual?.nome ?? '');
  String? _erro;
  bool _salvando = false;

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_salvando) return;
    final retool = context.read<ReToolController>();
    final tipo = widget.tipo;
    final atual = widget.atual;
    final erro = validarNomeClassificacao(tipo, retool.classificacoes(tipo), _nome.text, ignorarId: atual?.id);
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }
    final nome = limparNomeClassificacao(_nome.text);
    final navigator = Navigator.of(context);
    setState(() {
      _erro = null;
      _salvando = true;
    });
    try {
      if (atual == null) {
        await retool.addClassificacao(tipo, nome);
      } else if (nome != atual.nome) {
        await retool.updateClassificacao(tipo, atual.id, {'nome': nome});
      }
      if (mounted) navigator.pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _salvando = false;
          _erro = 'Não foi possível salvar. Verifique a conexão e tente novamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTextField(
          label: widget.tipo.rotuloCampoNome,
          controller: _nome,
          autofocus: true,
          obrigatorio: true,
          maxLength: 120,
          textInputAction: TextInputAction.done,
          onChanged: (_) {
            if (_erro != null) setState(() => _erro = null);
          },
          onSubmitted: (_) => _salvar(),
        ),
        if (_erro != null) ...[
          const SizedBox(height: AppSpacing.sm),
          InfoBox(tipo: InfoBoxTipo.erro, mensagem: _erro!),
        ],
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AppButton(label: 'Cancelar', onPressed: _salvando ? null : () => Navigator.of(context).maybePop()),
            const SizedBox(width: AppSpacing.sm),
            AppButton.primary(label: 'Salvar', loading: _salvando, onPressed: _salvar),
          ],
        ),
      ],
    );
  }
}
