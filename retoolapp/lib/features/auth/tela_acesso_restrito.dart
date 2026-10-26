import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../presentation/state/auth_controller.dart';

/// Moldura das telas exibidas antes do acesso normal (convidado em análise,
/// troca obrigatória de senha): faixa escura com a marca e só a opção de sair.
class TelaAcessoRestrito extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String subtitulo;
  final Widget child;

  const TelaAcessoRestrito({
    super.key,
    required this.icone,
    required this.titulo,
    required this.subtitulo,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.infoBorder),
                  boxShadow: const [BoxShadow(color: Color(0x260F172A), blurRadius: 50, offset: Offset(0, 25), spreadRadius: -12)],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Container(
                    color: AppColors.slate900,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
                    child: Row(children: [
                      const ReToolLogo(fontSize: 21, corRe: Colors.white),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: () => auth.logout(),
                        icon: const Icon(LucideIcons.logOut, size: 14),
                        label: const Text('Sair'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE2E8F0),
                          side: const BorderSide(color: Color(0x40FFFFFF)),
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 28, AppSpacing.lg, 28),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
                          child: Icon(icone, size: 20, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(titulo,
                                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.slate900)),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Text(subtitulo, style: const TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.55)),
                      const SizedBox(height: 20),
                      child,
                      if (auth.userProfile != null) ...[
                        const SizedBox(height: 20),
                        Text('Conectado como ${auth.userProfile!.email}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      ],
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
