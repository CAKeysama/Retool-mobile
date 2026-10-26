import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import 'logo_fatec.dart';

/// Equipe de desenvolvimento (FATEC Matão) — mesma ordem do desktop.
const desenvolvedoresRetool = [
  'Gustavo Domingues',
  'Miguel Moura',
  'Guilherme Pedroso',
  'Luiz Ramos',
  'Pedro Henrique',
  'Ana Beatriz Medeiros',
];
const orientadorRetool = 'Douglas Ribeiro';

/// Envolvidos da Baldan.
const envolvidosBaldan = ['Rodrigo Vidrich', 'Gabriela Carvalho', 'Vinicius Urbano', 'Flávio Gonella', 'Bruno Phelipe'];

/// Sobre o Projeto (`Sobre.tsx`): identificação, contexto, objetivos, equipes e parceiros.
class SobreScreen extends StatelessWidget {
  const SobreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sobre')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
          children: [
            const _Titulo(),
            const SizedBox(height: AppSpacing.xl),
            _Secao(
              titulo: '1. Identificação',
              children: [
                const Wrap(
                  runSpacing: 12,
                  children: [
                    _Campo(rotulo: 'Nome', valor: 'ReTool'),
                    _Campo(rotulo: 'Curso', valor: 'DSM'),
                    _Campo(rotulo: 'Instituição', valor: 'Fatec Matão'),
                    _Campo(rotulo: 'Parceira', valor: 'Baldan'),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const Text('Significado:', style: _rotulo),
                const SizedBox(height: 4),
                Text.rich(
                  const TextSpan(
                    children: [
                      TextSpan(text: 'O nome '),
                      TextSpan(
                        text: 'ReTool',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text:
                            ' associa o prefixo "Re" à ideia de reorganização, reutilização e revisão, juntamente ao '
                            'termo "Tool" (ferramenta). O projeto visa estruturar informações que hoje podem estar '
                            'dispersas ou depender de conhecimento tácito das equipes.',
                      ),
                    ],
                  ),
                  style: _corpo,
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text(
                    '"Onde o dispositivo atual vira o ponto de partida do futuro."',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const _Secao(
              titulo: '2. Contexto',
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text:
                            'No ambiente industrial, a organização de ferramentas e peças é vital para a eficiência, '
                            'preservação do conhecimento e redução de retrabalho. O ',
                      ),
                      TextSpan(
                        text: 'ReTool',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text:
                            ' centraliza essas informações para facilitar a consulta, atualização e rastreabilidade '
                            'na Baldan.',
                      ),
                    ],
                  ),
                  style: _corpo,
                ),
              ],
            ),
            const _Secao(
              titulo: '3. Objetivos',
              children: [
                _Topico('Estruturar o cadastro inicial das peças da ferramentaria.'),
                _Topico('Registrar a utilização de cada peça e sua aplicação.'),
                _Topico(
                  'Apoiar a padronização dos dados com evolução contínua, orientada pelas áreas técnicas (TI e Ferramentaria).',
                ),
              ],
            ),
            _Secao(
              titulo: '4. Equipe (Fatec)',
              children: [
                const Text('Desenvolvedores', style: _subtitulo),
                const SizedBox(height: AppSpacing.sm),
                for (final n in desenvolvedoresRetool) _Pessoa(n),
                const SizedBox(height: AppSpacing.md),
                const Text('Orientador', style: _subtitulo),
                const SizedBox(height: AppSpacing.sm),
                const _Pessoa(orientadorRetool),
              ],
            ),
            _Secao(titulo: '5. Envolvidos (Baldan)', children: [for (final n in envolvidosBaldan) _Pessoa(n)]),
            const SizedBox(height: AppSpacing.md),
            const _Logos(),
          ],
        ),
      ),
    );
  }
}

const _corpo = TextStyle(fontSize: 15, color: AppColors.textDark, height: 1.6);
const _rotulo = TextStyle(fontSize: 14.5, color: AppColors.textMuted, fontWeight: FontWeight.w600);
const _subtitulo = TextStyle(fontSize: 14.5, color: AppColors.primary, fontWeight: FontWeight.w700);

class _Titulo extends StatelessWidget {
  const _Titulo();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Icon(LucideIcons.info, size: 28, color: AppColors.primary),
      const SizedBox(height: 12),
      Semantics(
        header: true,
        child: const Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Sobre o',
                style: TextStyle(color: AppColors.gray00),
              ),
              TextSpan(
                text: ' Projeto',
                style: TextStyle(color: AppColors.primary),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1.15),
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'Identificação, Contexto e Objetivos do ReTool',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ],
  );
}

class _Secao extends StatelessWidget {
  final String titulo;
  final List<Widget> children;
  const _Secao({required this.titulo, required this.children});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Semantics(
            header: true,
            child: Text(
              titulo,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.gray00),
            ),
          ),
        ),
        ...children,
      ],
    ),
  );
}

/// Par "Rótulo: valor" da grade de identificação (2 colunas no celular).
class _Campo extends StatelessWidget {
  final String rotulo;
  final String valor;
  const _Campo({required this.rotulo, required this.valor});

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    widthFactor: 0.5,
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$rotulo: ', style: _rotulo),
          TextSpan(text: valor),
        ],
      ),
      style: const TextStyle(fontSize: 14.5, color: AppColors.textDark),
    ),
  );
}

class _Topico extends StatelessWidget {
  final String texto;
  const _Topico(this.texto);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 9, right: 10, left: 4),
          child: SizedBox(
            width: 5,
            height: 5,
            child: DecoratedBox(
              decoration: BoxDecoration(color: AppColors.textDark, shape: BoxShape.circle),
            ),
          ),
        ),
        Expanded(child: Text(texto, style: _corpo)),
      ],
    ),
  );
}

class _Pessoa extends StatelessWidget {
  final String nome;
  const _Pessoa(this.nome);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text('• $nome', style: const TextStyle(fontSize: 15, color: AppColors.textDark)),
  );
}

/// Rodapé com os logos: Baldan (empresa parceira) × FATEC Matão (instituição de ensino).
class _Logos extends StatelessWidget {
  const _Logos();

  static const _baldan = _Logo(
    rotulo: 'Empresa Parceira',
    child: Image(
      image: AssetImage('assets/images/baldan.png'),
      height: 50,
      fit: BoxFit.contain,
      semanticLabel: 'Baldan Implementos Agrícolas',
    ),
  );
  static const _fatec = _Logo(rotulo: 'Instituição de Ensino', child: LogoFatec(altura: 50));

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.md),
    child: LayoutBuilder(
      builder: (_, c) => c.maxWidth >= 420
          ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: _baldan),
                SizedBox(width: AppSpacing.x2l, height: 40, child: VerticalDivider(width: 1)),
                Flexible(child: _fatec),
              ],
            )
          : const Column(
              children: [
                _baldan,
                Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: SizedBox(width: 40, child: Divider()),
                ),
                _fatec,
              ],
            ),
    ),
  );
}

class _Logo extends StatelessWidget {
  final String rotulo;
  final Widget child;
  const _Logo({required this.rotulo, required this.child});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        rotulo.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textMuted,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      Opacity(opacity: 0.8, child: child),
    ],
  );
}
