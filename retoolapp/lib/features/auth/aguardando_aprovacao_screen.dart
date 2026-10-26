import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/entities/user.dart';
import '../../presentation/state/auth_controller.dart';
import 'tela_acesso_restrito.dart';

/// Área do Convidado: a aprovação chega em tempo real e libera o acesso automaticamente.
class AguardandoAprovacaoScreen extends StatelessWidget {
  const AguardandoAprovacaoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final perfil = context.watch<AuthController>().userProfile;
    if (perfil == null) return const Scaffold(body: LoadingView());

    Widget linha(String rotulo, Widget valor) => Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
          child: Row(children: [
            Text(rotulo, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            Expanded(child: Align(alignment: Alignment.centerRight, child: valor)),
          ]),
        );
    Widget texto(String v) =>
        Text(v, textAlign: TextAlign.right, style: const TextStyle(fontSize: 13.5, color: AppColors.slate900));

    return TelaAcessoRestrito(
      icone: LucideIcons.hourglass,
      titulo: 'Cadastro em análise',
      subtitulo:
          'Sua conta foi criada como Convidado. A Administração já foi notificada e vai definir o seu cargo. Enquanto isso, o acesso aos dados do sistema permanece bloqueado.',
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.infoBorder),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(children: [
            linha('Nome', texto(perfil.nome)),
            linha('E-mail', texto(perfil.email)),
            linha('Cargo atual', RoleBadge(perfil: perfil.perfil)),
            linha('Situação', const SituacaoBadge(SituacaoUsuario.pendente)),
            linha('Cadastro em', texto(formatarDataHora(perfil.criadoEm))),
          ]),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.infoBg,
            border: Border.all(color: AppColors.infoBorder),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('O que acontece agora',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.slate900)),
            SizedBox(height: 6),
            Text(
              '1. A Administração analisa o seu cadastro.\n'
              '2. Se aprovado, você recebe o cargo adequado e esta tela libera o sistema automaticamente.\n'
              '3. Se recusado, o acesso permanece bloqueado e o motivo é exibido no próximo login.',
              style: TextStyle(fontSize: 13, color: AppColors.infoText, height: 1.6),
            ),
          ]),
        ),
      ]),
    );
  }
}
