import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/errors.dart';
import '../../domain/services/senha_temporaria.dart';
import '../../presentation/state/auth_controller.dart';
import 'tela_acesso_restrito.dart';

/// Primeiro acesso de conta criada pela Administração: substitui a senha temporária.
class TrocaSenhaScreen extends StatefulWidget {
  const TrocaSenhaScreen({super.key});

  @override
  State<TrocaSenhaScreen> createState() => _TrocaSenhaScreenState();
}

class _TrocaSenhaScreenState extends State<TrocaSenhaScreen> {
  final _atual = TextEditingController();
  final _nova = TextEditingController();
  final _confirmacao = TextEditingController();
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _atual.dispose();
    _nova.dispose();
    _confirmacao.dispose();
    super.dispose();
  }

  List<({bool ok, String texto})> get _requisitos {
    final n = _nova.text;
    return [
      (ok: n.length >= tamanhoMinimoSenha, texto: 'Mínimo de $tamanhoMinimoSenha caracteres'),
      (ok: RegExp(r'[A-Za-z]').hasMatch(n) && RegExp(r'\d').hasMatch(n), texto: 'Letras e números'),
      (ok: n.isNotEmpty && n == _confirmacao.text, texto: 'Confirmação igual à nova senha'),
      (ok: n.isNotEmpty && n != _atual.text, texto: 'Diferente da senha temporária'),
    ];
  }

  Future<void> _salvar() async {
    setState(() {
      _erro = null;
      _salvando = true;
    });
    try {
      await context.read<AuthController>().concluirTrocaSenha(_atual.text, _nova.text, _confirmacao.text);
      // O perfil atualizado libera o sistema automaticamente (redirect do router).
    } catch (e) {
      final codigo = e is ErroAmigavel ? e.codigo : null;
      setState(() {
        _erro = codigo == 'invalid-credential' || codigo == 'wrong-password'
            ? 'A senha temporária informada está incorreta.'
            : mensagemDoErro(e);
        _salvando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final requisitos = _requisitos;
    final podeSalvar = !_salvando && requisitos.every((r) => r.ok) && _atual.text.isNotEmpty;
    void atualizar(String _) => setState(() {});

    return TelaAcessoRestrito(
      icone: LucideIcons.keyRound,
      titulo: 'Defina sua nova senha',
      subtitulo:
          'Esta conta foi criada pela Administração com uma senha temporária. Para continuar, substitua-a por uma senha pessoal — ela não será exibida nem registrada em nenhum lugar.',
      child: AutofillGroup(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_erro != null) ...[InfoBox(mensagem: _erro!, tipo: InfoBoxTipo.erro), const SizedBox(height: 14)],
          AppTextField(
            label: 'Senha temporária',
            controller: _atual,
            obscure: true,
            autofillHints: const [AutofillHints.password],
            onChanged: atualizar,
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Nova senha',
            controller: _nova,
            obscure: true,
            autofillHints: const [AutofillHints.newPassword],
            onChanged: atualizar,
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Confirmar nova senha',
            controller: _confirmacao,
            obscure: true,
            autofillHints: const [AutofillHints.newPassword],
            onChanged: atualizar,
            onSubmitted: (_) => podeSalvar ? _salvar() : null,
          ),
          const SizedBox(height: 14),
          for (final r in requisitos)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Icon(r.ok ? LucideIcons.check : LucideIcons.circle,
                    size: r.ok ? 14 : 12, color: r.ok ? AppColors.sucessoText : const Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(r.texto,
                      style: TextStyle(fontSize: 12.5, color: r.ok ? AppColors.sucessoText : const Color(0xFF64748B))),
                ),
              ]),
            ),
          const SizedBox(height: 10),
          AppButton.primary(
            label: _salvando ? 'Salvando nova senha...' : 'Salvar nova senha e continuar',
            loading: _salvando,
            expand: true,
            onPressed: podeSalvar ? _salvar : null,
          ),
        ]),
      ),
    );
  }
}
