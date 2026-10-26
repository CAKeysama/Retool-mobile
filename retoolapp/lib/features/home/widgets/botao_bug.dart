import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';

/// Fases do botão de bug (mesma sequência do desktop).
enum FaseBotaoBug { visivel, explodindo, oculto, reconstruindo }

/// Partículas da explosão: deslocamento (x, y), diâmetro e cor (`BUG_EXPLOSION_PARTICLES`).
const _particulas = <(double, double, double, Color)>[
  (-50, -25, 12, Color(0xFF1F2937)),
  (40, -40, 10, AppColors.primary),
  (-60, 15, 14, Color(0xFF1F2937)),
  (55, 25, 16, AppColors.primary),
  (10, -60, 18, Color(0xFF1F2937)),
  (-30, 50, 10, AppColors.primary),
  (35, 55, 12, Color(0xFF1F2937)),
  (-15, 35, 14, AppColors.primary),
  (70, -15, 8, Color(0xFF1F2937)),
  (-70, -35, 12, AppColors.primary),
  (-20, -45, 14, Color(0xFF1F2937)),
  (25, -25, 16, AppColors.primary),
];

/// Botão flutuante "Encontrou algum bug?": flutua suavemente; ao toque "explode"
/// em partículas, abre o formulário após 0,5 s, some e se reconstrói ~5 s depois.
class BotaoBug extends StatefulWidget {
  final Future<void> Function() onAbrir;

  /// Tempo oculto entre o fim da explosão e o início da reconstrução.
  final Duration tempoOculto;

  const BotaoBug({super.key, required this.onAbrir, this.tempoOculto = const Duration(milliseconds: 4400)});

  @override
  State<BotaoBug> createState() => _BotaoBugState();
}

class _BotaoBugState extends State<BotaoBug> with TickerProviderStateMixin {
  static const _duracaoParticulas = Duration(milliseconds: 600);
  static const _curvaParticulas = Cubic(0.1, 0.8, 0.3, 1);

  FaseBotaoBug _fase = FaseBotaoBug.visivel;
  final List<Timer> _timers = [];

  late final AnimationController _flutuar = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1750),
  );
  late final AnimationController _particulasCtrl = AnimationController(vsync: this, duration: _duracaoParticulas);
  late final AnimationController _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 350))
    ..forward();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respeita "remover animações" do sistema.
    if (MediaQuery.disableAnimationsOf(context)) {
      _flutuar.stop();
      _flutuar.value = 0;
    } else if (!_flutuar.isAnimating) {
      _flutuar.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _flutuar.dispose();
    _particulasCtrl.dispose();
    _pop.dispose();
    super.dispose();
  }

  void _depois(Duration d, VoidCallback fn) => _timers.add(
    Timer(d, () {
      if (mounted) fn();
    }),
  );

  void _aoTocar() {
    if (_fase != FaseBotaoBug.visivel) return;
    setState(() => _fase = FaseBotaoBug.explodindo);
    _particulasCtrl.forward(from: 0);
    // Abre o formulário com atraso para a explosão ser vista.
    _depois(const Duration(milliseconds: 500), () => widget.onAbrir());
    _depois(_duracaoParticulas, () {
      setState(() => _fase = FaseBotaoBug.oculto);
      _depois(widget.tempoOculto, () {
        setState(() => _fase = FaseBotaoBug.reconstruindo);
        _particulasCtrl.forward(from: 0);
        _depois(_duracaoParticulas, () {
          setState(() => _fase = FaseBotaoBug.visivel);
          _pop.forward(from: 0);
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final flutuacao = CurvedAnimation(parent: _flutuar, curve: Curves.easeInOut);
    final popIn = CurvedAnimation(parent: _pop, curve: const Cubic(0.34, 1.56, 0.64, 1));
    return SizedBox(
      width: 48,
      height: 48,
      child: AnimatedBuilder(
        animation: flutuacao,
        builder: (_, child) => Transform.translate(offset: Offset(0, -10 * flutuacao.value), child: child),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            if (_fase == FaseBotaoBug.explodindo || _fase == FaseBotaoBug.reconstruindo)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _PintorParticulas(
                      progresso: CurvedAnimation(parent: _particulasCtrl, curve: _curvaParticulas),
                      reverso: _fase == FaseBotaoBug.reconstruindo,
                    ),
                  ),
                ),
              ),
            if (_fase == FaseBotaoBug.visivel)
              ScaleTransition(
                scale: popIn,
                child: Tooltip(
                  message: 'Encontrou algum bug?',
                  child: Semantics(
                    button: true,
                    label: 'Reportar um bug',
                    excludeSemantics: true,
                    child: Material(
                      key: const Key('botao-bug'),
                      color: AppColors.primary,
                      shape: const CircleBorder(),
                      elevation: 0,
                      clipBehavior: Clip.antiAlias,
                      child: Ink(
                        decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: AppShadows.primaryGlow),
                        child: InkWell(
                          onTap: _aoTocar,
                          customBorder: const CircleBorder(),
                          child: const SizedBox(
                            width: 48,
                            height: 48,
                            child: Icon(LucideIcons.bug, size: 22, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PintorParticulas extends CustomPainter {
  final Animation<double> progresso;
  final bool reverso;
  _PintorParticulas({required this.progresso, required this.reverso}) : super(repaint: progresso);

  @override
  void paint(Canvas canvas, Size size) {
    final t = progresso.value;
    // Explosão: sai do centro encolhendo; reconstrução: volta ao centro crescendo.
    final distancia = reverso ? 1 - t : t;
    final escala = reverso ? t : 1 - t;
    final opacidade = (reverso ? t : 1 - t).clamp(0.0, 1.0);
    final centro = size.center(Offset.zero);
    for (final (x, y, diametro, cor) in _particulas) {
      final c = centro + Offset(x * distancia, y * distancia);
      canvas.drawCircle(c, diametro / 2 * escala, Paint()..color = cor.withValues(alpha: opacidade));
    }
  }

  @override
  bool shouldRepaint(_PintorParticulas old) => old.reverso != reverso || old.progresso != progresso;
}
