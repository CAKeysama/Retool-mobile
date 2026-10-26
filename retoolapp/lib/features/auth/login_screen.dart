import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/errors.dart';
import '../../presentation/state/auth_controller.dart';

/// Login e autocadastro. No mobile o painel institucional escuro do desktop
/// vira um cabeçalho compacto acima do formulário.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _confirmacao = TextEditingController();
  bool _cadastrando = false;
  bool _carregando = false;
  String? _erro;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _senha.dispose();
    _confirmacao.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _carregando = true;
      _erro = null;
    });
    final auth = context.read<AuthController>();
    try {
      if (_cadastrando) {
        if (_nome.text.trim().isEmpty) throw const ErroValidacao('Por favor, informe seu nome completo.');
        if (_senha.text.length < 6) throw const ErroValidacao('A senha deve conter no mínimo 6 caracteres.');
        if (_senha.text != _confirmacao.text) throw const ErroValidacao('As senhas informadas não coincidem.');
        // O cargo nunca é escolhido aqui: a conta nasce como Convidado.
        await auth.register(_email.text, _senha.text, _nome.text);
      } else {
        await auth.login(_email.text, _senha.text);
      }
    } catch (e) {
      if (mounted) setState(() => _erro = mensagemDoErro(e));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  String? _obrigatorio(String? v) => (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.infoBorder),
                  boxShadow: const [BoxShadow(color: Color(0x260F172A), blurRadius: 50, offset: Offset(0, 25), spreadRadius: -12)],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _PainelInstitucional(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 28, AppSpacing.lg, AppSpacing.lg),
                    child: _formulario(),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formulario() {
    return Form(
      key: _form,
      child: AutofillGroup(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Semantics(
            header: true,
            child: Text(_cadastrando ? 'Criar Nova Conta' : 'Acesse o Sistema',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.slate900)),
          ),
          const SizedBox(height: 6),
          Text(
            _cadastrando
                ? 'Cadastre seu usuário institucional. Você entra como Convidado e o cargo é definido pela Administração na aprovação.'
                : 'Informe seu e-mail institucional e senha para entrar.',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13.5, height: 1.45),
          ),
          const SizedBox(height: 20),
          const InfoBox(
            mensagem:
                'Contas institucionais são provisionadas e aprovadas pela Administração do sistema. Novos cadastros entram como Convidado, sem acesso aos dados, até a aprovação.',
          ),
          const SizedBox(height: 18),
          if (_erro != null) ...[InfoBox(mensagem: _erro!, tipo: InfoBoxTipo.erro), const SizedBox(height: 18)],
          if (_cadastrando) ...[
            AppTextField(
              label: 'Nome Completo',
              hint: 'Seu nome completo',
              controller: _nome,
              prefixIcon: LucideIcons.user,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              validator: _obrigatorio,
            ),
            const SizedBox(height: 16),
          ],
          AppTextField(
            label: 'E-mail Institucional',
            hint: 'usuario@empresa.com',
            controller: _email,
            prefixIcon: LucideIcons.mail,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email, AutofillHints.username],
            validator: _obrigatorio,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Senha',
            hint: '••••••••',
            controller: _senha,
            prefixIcon: LucideIcons.lock,
            obscure: true,
            textInputAction: _cadastrando ? TextInputAction.next : TextInputAction.done,
            autofillHints: [_cadastrando ? AutofillHints.newPassword : AutofillHints.password],
            validator: _obrigatorio,
            onSubmitted: (_) => _cadastrando ? null : _enviar(),
          ),
          if (_cadastrando) ...[
            const SizedBox(height: 16),
            AppTextField(
              label: 'Confirmar Senha',
              hint: 'Repita a senha',
              controller: _confirmacao,
              prefixIcon: LucideIcons.lock,
              obscure: true,
              textInputAction: TextInputAction.done,
              validator: _obrigatorio,
              onSubmitted: (_) => _enviar(),
            ),
          ],
          const SizedBox(height: 22),
          AppButton.primary(
            label: _carregando
                ? 'Processando autenticação...'
                : (_cadastrando ? 'Cadastrar e Aguardar Aprovação' : 'Entrar no ReTool'),
            trailingIcon: _carregando ? null : LucideIcons.arrowRight,
            loading: _carregando,
            expand: true,
            onPressed: _enviar,
          ),
          const SizedBox(height: 20),
          Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(_cadastrando ? 'Já possui uma conta institucional?' : 'Novo colaborador na indústria?',
                style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B))),
            TextButton(
              onPressed: _carregando
                  ? null
                  : () => setState(() {
                        _cadastrando = !_cadastrando;
                        _erro = null;
                      }),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              child: Text(_cadastrando ? 'Faça login' : 'Cadastre-se aqui',
                  style: const TextStyle(fontWeight: FontWeight.w700, decoration: TextDecoration.underline)),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _PainelInstitucional extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.slate900,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              boxShadow: const [BoxShadow(color: Color(0x66E11D48), blurRadius: 10, offset: Offset(0, 4))],
            ),
            child: const Text('R', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
          ),
          const ReToolLogo(fontSize: 24, corRe: Colors.white),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0x26FFFFFF), borderRadius: BorderRadius.circular(6)),
            child: const Text('GESTAO INDUSTRIAL',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFF8FAFC), letterSpacing: 0.6)),
          ),
        ]),
        const SizedBox(height: 18),
        const Text('Gestão de Dispositivos e Reutilização Industrial',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white, height: 1.3)),
        const SizedBox(height: 8),
        const Text(
          'O ReTool centraliza o cadastro de dispositivos, famílias, categorias e produtos da ferramentaria e o fluxo de reutilização de peças, com rastreabilidade das operações.',
          style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.5),
        ),
      ]),
    );
  }
}
