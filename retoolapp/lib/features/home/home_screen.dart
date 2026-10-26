import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_dependencies.dart';
import '../../core/router/rotas.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../presentation/shell/app_shell.dart';
import '../../presentation/state/auth_controller.dart';
import '../../presentation/state/retool_controller.dart';
import 'widgets/botao_bug.dart';
import 'widgets/busca_omnibox.dart';
import 'widgets/home_card.dart';

/// Home (`Home.tsx` do desktop): logotipo, busca com sugestões, atalhos de cadastro,
/// cartões de contagem, "Sobre o Projeto" e o botão flutuante de bugs.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _busca = TextEditingController();

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  void _buscar(String q) {
    final t = q.trim();
    context.go(t.isEmpty ? Rotas.dispositivos : Rotas.buscarDispositivos(t));
  }

  Future<void> _abrirFormularioBugs() async {
    if (!mounted) return;
    final deps = context.read<AppDependencies>();
    final retool = context.read<ReToolController>();
    final uri = Uri.tryParse(deps.urlFormularioBugs);
    var aberto = false;
    if (uri != null && deps.urlFormularioBugs.isNotEmpty) {
      try {
        aberto = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('Falha ao abrir o formulário de bugs: $e');
      }
    }
    if (!aberto) retool.announce('Não foi possível abrir o formulário de bugs.');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final retool = context.watch<ReToolController>();
    final mostrarCategorias = auth.canCadastrar || auth.canEditar;

    return Scaffold(
      appBar: appBarPadrao(context, titulo: const _BotaoSobre()),
      body: Stack(
        children: [
          const Positioned.fill(child: _MarcaDagua()),
          LayoutBuilder(
            builder: (context, c) {
              return SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, 88),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: (c.maxHeight - AppSpacing.lg - 88).clamp(0, double.infinity)),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 650),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const ReToolLogo(fontSize: 40),
                          const SizedBox(height: AppSpacing.xs),
                          const Text(
                            'Gestão de Dispositivos e Ferramentas Industriais',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textMuted, fontSize: 14.4, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          BuscaOmnibox(
                            controller: _busca,
                            onSelecionar: (d) => context.push(Rotas.dispositivo(d.id)),
                            onBuscar: _buscar,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: AppSpacing.md,
                            runSpacing: AppSpacing.sm,
                            children: [
                              AppButton(
                                label: 'Buscar dispositivos',
                                compact: true,
                                onPressed: () => _buscar(_busca.text),
                              ),
                              if (auth.canCadastrar)
                                AppIconButton(
                                  icon: LucideIcons.plus,
                                  tooltip: 'Cadastrar novo dispositivo',
                                  primary: true,
                                  onPressed: () => context.push(Rotas.novoDispositivo),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.x2l),
                          _Cartoes(
                            cartoes: [
                              (
                                count: retool.dispositivos.length,
                                label: 'Dispositivos',
                                icon: LucideIcons.box,
                                rota: Rotas.dispositivos,
                              ),
                              (
                                count: retool.reutilizacoes.length,
                                label: 'Reutilizações',
                                icon: LucideIcons.wrench,
                                rota: Rotas.reutilizacoes,
                              ),
                              if (mostrarCategorias)
                                (
                                  count: retool.categorias.length,
                                  label: 'Categorias',
                                  icon: LucideIcons.tag,
                                  rota: Rotas.categorias,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            right: AppSpacing.md + 4,
            bottom: AppSpacing.md + 4,
            child: BotaoBug(onAbrir: _abrirFormularioBugs),
          ),
        ],
      ),
    );
  }
}

/// "Sobre o Projeto" (canto superior esquerdo no desktop).
class _BotaoSobre extends StatelessWidget {
  const _BotaoSobre();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: () => context.push(Rotas.sobre),
      icon: const Icon(LucideIcons.info, size: 16),
      label: const Text('Sobre o Projeto'),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textBody,
        textStyle: const TextStyle(fontSize: 13.6, fontWeight: FontWeight.w600),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    ),
  );
}

/// Marca d'água Baldan centralizada, quase transparente, atrás do conteúdo.
class _MarcaDagua extends StatelessWidget {
  const _MarcaDagua();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, c) {
          final largura = (c.maxWidth * 1.2).clamp(0.0, 1500.0);
          return OverflowBox(
            maxWidth: largura,
            child: Image.asset(
              'assets/images/baldan_mono.png',
              width: largura,
              fit: BoxFit.contain,
              opacity: const AlwaysStoppedAnimation(0.05),
              cacheWidth: (largura * MediaQuery.devicePixelRatioOf(context)).round().clamp(1, 3000),
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          );
        },
      ),
    ),
  );
}

typedef _DadosCartao = ({int count, String label, IconData icon, String rota});

/// Cartões lado a lado; encolhem (até ~96 px) para caber na largura do celular.
class _Cartoes extends StatelessWidget {
  final List<_DadosCartao> cartoes;
  const _Cartoes({required this.cartoes});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final n = cartoes.length;
      // Espaço do desktop (16) quando cabe; 8 em telas estreitas para os cartões não ficarem minúsculos.
      final gap = c.maxWidth >= 140 * n + AppSpacing.md * (n - 1) ? AppSpacing.md : AppSpacing.sm;
      final tamanho = ((c.maxWidth - gap * (n - 1)) / n).clamp(80.0, 140.0);
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final k in cartoes)
            HomeCard(count: k.count, label: k.label, icon: k.icon, tamanho: tamanho, onTap: () => context.go(k.rota)),
        ],
      );
    },
  );
}
