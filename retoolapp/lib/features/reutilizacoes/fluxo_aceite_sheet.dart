import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/entities/reutilizacao.dart';
import 'widgets/cartao_reutilizacao.dart';

/// "Como funciona o fluxo de aceite" (equivalente ao `FluxoReutilizacaoModal` do desktop).
Future<void> mostrarFluxoAceite(BuildContext context) => showAppSheet<void>(
      context,
      titulo: 'Como funciona o fluxo de aceite',
      builder: (ctx) => const FluxoAceiteConteudo(),
    );

const _tituloEtapa = TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF111827));
const _textoEtapa = TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.5);
const _tituloSecao = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827));

class _Chip extends StatelessWidget {
  final ReutilizacaoStatus status;
  const _Chip(this.status);

  @override
  Widget build(BuildContext context) {
    final cor = corDoStatusReutilizacao(status);
    return Pill(label: status.rotuloCurto, fundo: cor.fundo, texto: cor.texto);
  }
}

class _Cartao extends StatelessWidget {
  final Widget child;
  final Color fundo;
  final Color borda;
  const _Cartao({required this.child, this.fundo = const Color(0xFFFAFAFA), this.borda = AppColors.border});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: fundo,
          border: Border.all(color: borda),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: child,
      );
}

class _Conector extends StatelessWidget {
  const _Conector();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 2),
        child: Center(child: Icon(LucideIcons.arrowDown, size: 16, color: AppColors.textMuted)),
      );
}

class _Etapa extends StatelessWidget {
  final String titulo;
  final ReutilizacaoStatus? status;
  final InlineSpan texto;
  final List<Widget> extras;
  const _Etapa({required this.titulo, this.status, required this.texto, this.extras = const []});

  @override
  Widget build(BuildContext context) => _Cartao(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(titulo, style: _tituloEtapa),
            if (status != null) _Chip(status!),
          ]),
          const SizedBox(height: 4),
          Text.rich(texto, style: _textoEtapa),
          ...extras,
        ]),
      );
}

TextSpan _b(String t) => TextSpan(text: t, style: const TextStyle(fontWeight: FontWeight.w700));

class FluxoAceiteConteudo extends StatelessWidget {
  const FluxoAceiteConteudo({super.key});

  static const _estados = [
    (
      st: ReutilizacaoStatus.emAnaliseEngenharia,
      desc: 'Rascunho criado pela Engenharia, aguardando envio ao 1º filtro.',
      quem: 'Engenharia / Admin'
    ),
    (st: ReutilizacaoStatus.emAnaliseProjetista, desc: 'Em avaliação pelo Projetista (1º filtro).', quem: 'Projetista / Admin'),
    (st: ReutilizacaoStatus.aprovada, desc: 'Aprovada no 1º filtro — estado final.', quem: '—'),
    (
      st: ReutilizacaoStatus.naoAprovada,
      desc: 'Reprovada com motivo; pode ser enviado para solicitação de dispositivo novo.',
      quem: 'Engenharia / Admin'
    ),
    (
      st: ReutilizacaoStatus.aguardandoNovoFiltro,
      desc: 'Dispositivo novo solicitado; Projetista verifica similares (2º filtro).',
      quem: 'Projetista / Admin'
    ),
    (st: ReutilizacaoStatus.liberadoFabricacao, desc: 'Novo dispositivo liberado — estado final.', quem: '—'),
  ];

  static const _permissoes = [
    ('Engenharia', 'solicita, envia ao 1º filtro e solicita dispositivo novo.'),
    ('Projetista', 'aprova/reprova no 1º filtro e decide similar/liberação no 2º filtro.'),
    ('Admin', 'todas as transições do fluxo.'),
    ('Gerência', 'somente leitura (consulta o histórico).'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // ETAPAS DO FLUXO
      _Etapa(
        titulo: '1. Solicitação',
        status: ReutilizacaoStatus.emAnaliseEngenharia,
        texto: TextSpan(children: [
          const TextSpan(
              text: 'A Engenharia cria a solicitação no formulário "Nova Solicitação" (peça, descrição da alteração, '
                  'hard saving). O registro nasce neste status e fica na '),
          _b('Fila da Engenharia'),
          const TextSpan(text: '.'),
        ]),
      ),
      const _Conector(),
      _Etapa(
        titulo: '2. Envio para análise (1º filtro)',
        status: ReutilizacaoStatus.emAnaliseProjetista,
        texto: TextSpan(children: [
          const TextSpan(text: 'Ainda na Fila da Engenharia, a solicitação é enviada com o botão '),
          _b('"Solicitar Análise"'),
          const TextSpan(text: '. Ela passa para a '),
          _b('Fila do Projetista'),
          const TextSpan(text: ', e o Projetista e o Admin são notificados.'),
        ]),
      ),
      const _Conector(),
      _Etapa(
        titulo: '3. Decisão do Projetista',
        texto: const TextSpan(
            text: 'Na Fila do Projetista, a solicitação é avaliada e o resultado segue por um dos caminhos:'),
        extras: [
          const SizedBox(height: 10),
          _Cartao(
            fundo: const Color(0xFFF0FDF4),
            borda: const Color(0xFFBBF7D0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Icon(LucideIcons.check, size: 15, color: AppColors.success),
                Text('Aprovada', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                _Chip(ReutilizacaoStatus.aprovada),
              ]),
              const SizedBox(height: 4),
              const Text('O solicitante é notificado e o dispositivo está liberado para reutilização — fluxo encerrado.',
                  style: _textoEtapa),
            ]),
          ),
          const SizedBox(height: 10),
          _Cartao(
            fundo: const Color(0xFFFEF2F2),
            borda: const Color(0xFFFECACA),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Icon(LucideIcons.x, size: 15, color: AppColors.danger),
                Text('Não aprovada', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                _Chip(ReutilizacaoStatus.naoAprovada),
              ]),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(children: [
                  const TextSpan(
                      text: 'O motivo é registrado e o solicitante é notificado. A Engenharia pode'),
                  _b(' solicitar um dispositivo novo'),
                  const TextSpan(text: ' (2º filtro).'),
                ]),
                style: _textoEtapa,
              ),
            ]),
          ),
        ],
      ),
      const _Conector(),
      _Etapa(
        titulo: '4. Novo dispositivo (2º filtro)',
        status: ReutilizacaoStatus.aguardandoNovoFiltro,
        texto: TextSpan(children: [
          const TextSpan(text: 'Quando um dispositivo novo é solicitado, o registro volta à '),
          _b('Fila do Projetista'),
          const TextSpan(text: ' para verificação de similares:'),
        ]),
        extras: [
          const SizedBox(height: 8),
          _Ramo(children: [
            _b('Similar encontrado:'),
            const TextSpan(text: ' retorna à análise do Projetista (etapa 3) e o solicitante é avisado.'),
          ]),
          const SizedBox(height: 6),
          _Ramo(
            children: [
              _b('Sem similar:'),
              const TextSpan(text: ' fabricação do dispositivo novo liberada — fluxo encerrado.'),
            ],
            chip: ReutilizacaoStatus.liberadoFabricacao,
          ),
        ],
      ),

      // TODOS OS ESTADOS
      const _Secao(titulo: 'Todos os estados'),
      for (final e in _estados)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              ChipStatusReutilizacao(e.st),
              Text('Quem avança: ${e.quem}', style: const TextStyle(fontSize: 12, color: AppColors.textSubtle)),
            ]),
            const SizedBox(height: 4),
            Text(e.desc, style: _textoEtapa),
          ]),
        ),

      // PERMISSÕES
      const _Secao(titulo: 'Permissões por perfil'),
      for (final p in _permissoes) ...[
        _Cartao(
          child: Text.rich(TextSpan(children: [_b('${p.$1}: '), TextSpan(text: p.$2)]), style: _textoEtapa),
        ),
        const SizedBox(height: 8),
      ],
      const SizedBox(height: 2),
      const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: EdgeInsets.only(top: 2), child: Icon(LucideIcons.bell, size: 14, color: AppColors.textSubtle)),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Notificações: Projetista e Admin recebem as entradas nas filas; o solicitante é avisado nas decisões '
            '(aprovação, não aprovação, similar encontrado e liberação de fabricação).',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSubtle, height: 1.5),
          ),
        ),
      ]),
      const SizedBox(height: AppSpacing.lg),
      Align(
        alignment: Alignment.centerRight,
        child: AppButton.primary(label: 'Entendi', onPressed: () => Navigator.of(context).maybePop()),
      ),
    ]);
  }
}

class _Secao extends StatelessWidget {
  final String titulo;
  const _Secao({required this.titulo});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: AppSpacing.lg),
        padding: const EdgeInsets.only(top: AppSpacing.md, bottom: 4),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
        child: Semantics(header: true, child: Text(titulo, style: _tituloSecao)),
      );
}

class _Ramo extends StatelessWidget {
  final List<InlineSpan> children;
  final ReutilizacaoStatus? chip;
  const _Ramo({required this.children, this.chip});

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(LucideIcons.cornerDownRight, size: 14, color: AppColors.textMuted),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (chip != null) ...[_Chip(chip!), const SizedBox(height: 4)],
            Text.rich(TextSpan(children: children), style: _textoEtapa),
          ]),
        ),
      ]);
}
