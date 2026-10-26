import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retoolapp/domain/entities/audit_log.dart';
import 'package:retoolapp/domain/entities/classificacao.dart';
import 'package:retoolapp/domain/entities/reutilizacao.dart';
import 'package:retoolapp/features/dispositivos/dispositivo_detalhes_screen.dart';
import 'package:retoolapp/features/reutilizacoes/solicitar/solicitar_reutilizacao_sheet.dart';

import '../../../support/fakes.dart';
import '../../../support/harness.dart';

Finder campo(String key) => find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextFormField));

Future<void> digitar(WidgetTester tester, String key, String texto) async {
  final alvo = campo(key);
  await tester.ensureVisible(alvo);
  await tester.enterText(alvo, texto);
  await tester.pump();
}

FakeBackend _backend(String perfil) {
  final b = FakeBackend()..semearDadosFabris();
  b.criarUsuario('u1', perfil: perfil, nome: 'Eva Engenheira', logar: true);
  return b;
}

/// Tela mínima com um botão que abre o sheet pela função pública.
class _Abridor extends StatelessWidget {
  final String dispositivoId;
  final bool direto;
  const _Abridor({required this.dispositivoId, this.direto = false});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ElevatedButton(
        onPressed: () => mostrarSolicitarReutilizacao(context, dispositivoId: dispositivoId, registroDireto: direto),
        child: const Text('abrir'),
      ),
    ),
  );
}

List<Reutilizacao> _novas(FakeBackend b) => b.reutilizacoes.itens.values.where((r) => r.id.startsWith('reu-')).toList();

void main() {
  group('lerNumeroBr', () {
    test('aceita vírgula, ponto e milhar', () {
      expect(lerNumeroBr('2,15'), 2.15);
      expect(lerNumeroBr('2.15'), 2.15);
      expect(lerNumeroBr('1.234,56'), 1234.56);
      expect(lerNumeroBr(' 22300 '), 22300);
      expect(lerNumeroBr(''), isNull);
      expect(lerNumeroBr('abc'), isNull);
    });
  });

  testWidgets('engenharia solicita: nasce "Em análise (Engenharia)" com os campos do desktop', (tester) async {
    final b = _backend('engenharia');
    final c = await pumpTela(tester, b, const DispositivoDetalhesScreen(id: 'd1'), tamanho: const Size(412, 1400));

    await tocar(tester, find.text('Solicitar Reutilização'));
    expect(find.text('Solicitar Reutilização de Dispositivo'), findsOneWidget);
    expect(find.text('Fluxo de Aprovação'), findsOneWidget);
    expect(tester.widget<TextFormField>(campo('reu_responsavel')).controller!.text, 'Eva Engenheira');

    await digitar(tester, 'reu_codigo', ' PC-9842 ');
    await digitar(tester, 'reu_os', 'OS-2026-104');
    await digitar(tester, 'reu_peso', '2,15');
    await digitar(tester, 'reu_hard_saving', '1.234,50');
    await digitar(tester, 'reu_descricao_alteracao', 'Trocar pinos de centragem');
    await tocar(tester, find.text('Enviar Solicitação'));

    expect(find.text('Solicitar Reutilização de Dispositivo'), findsNothing);
    final r = _novas(b).single;
    expect(r.status, ReutilizacaoStatus.emAnaliseEngenharia);
    expect(r.dispositivoId, 'd1');
    expect(r.codigoPeca, 'PC-9842');
    expect(r.numeroOs, 'OS-2026-104');
    expect(r.pesoPeca, 2.15);
    expect(r.hardSaving, 1234.5);
    expect(r.descricaoPeca, 'Gabarito de Furação Lateral'); // vazio = nome do dispositivo
    expect(r.produtoId, 'prod-2'); // primeiro produto em ordem alfabética (AVOLA 2500)
    expect(r.responsavel, 'Eva Engenheira');
    expect(r.solicitanteId, 'u1');
    expect(r.solicitanteNome, 'Eva Engenheira');
    expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(r.data), isTrue);
    expect(c.anuncios.last, contains('Solicitação registrada'));
    final log = b.audit.registros.last;
    expect(log.acao, AuditLogAcao.criacao);
    expect(log.acaoDescricao, 'Solicitou reutilização');
  });

  testWidgets('valida código e descrição da alteração (mensagem do desktop)', (tester) async {
    final b = _backend('engenharia');
    await pumpTela(tester, b, const _Abridor(dispositivoId: 'd1'));
    await tocar(tester, find.text('abrir'));

    await tocar(tester, find.text('Enviar Solicitação'));
    expect(find.text('Preencha o código da peça e a descrição da alteração pretendida.'), findsOneWidget);
    expect(_novas(b), isEmpty);

    await digitar(tester, 'reu_codigo', 'PC-1');
    await digitar(tester, 'reu_descricao_alteracao', 'Ajuste');
    await digitar(tester, 'reu_hard_saving', '1,2,3');
    await tocar(tester, find.text('Enviar Solicitação'));
    expect(find.text('Informe um número válido.'), findsOneWidget);
    expect(_novas(b), isEmpty);
  });

  testWidgets('registro direto (admin) nasce "Reutilização aprovada" com pré-preenchimento', (tester) async {
    final b = _backend('admin');
    final c = await pumpTela(tester, b, const DispositivoDetalhesScreen(id: 'd1'), tamanho: const Size(412, 1400));

    await tocar(tester, find.text('Nova Reutilização'));
    expect(find.text('Registrar Reutilização'), findsOneWidget);
    expect(tester.widget<TextFormField>(campo('reu_codigo')).controller!.text, 'GAB-0042');
    expect(tester.widget<TextFormField>(campo('reu_descricao_peca')).controller!.text, 'Gabarito de Furação Lateral');
    expect(tester.widget<TextFormField>(campo('reu_peso')).controller!.text, '14,5');
    expect(find.text('SPE 5500'), findsWidgets); // produto do dispositivo pré-selecionado

    // Campos obrigatórios do desktop bloqueiam o envio.
    await tocar(tester, find.text('Registrar Reutilização'));
    expect(find.text('Preencha este campo.'), findsWidgets);
    expect(_novas(b), isEmpty);

    await digitar(tester, 'reu_os', 'OS-24567');
    await digitar(tester, 'reu_hard_saving', '22300,00');
    await digitar(tester, 'reu_responsavel', 'João Silva');
    await digitar(tester, 'reu_descricao_alteracao', 'Novos furos');
    await tocar(tester, find.text('Registrar Reutilização'));

    final r = _novas(b).single;
    expect(r.status, ReutilizacaoStatus.aprovada);
    expect(r.codigoPeca, 'GAB-0042');
    expect(r.produtoId, 'prod-1');
    expect(r.pesoPeca, 14.5);
    expect(r.hardSaving, 22300);
    expect(r.responsavel, 'João Silva');
    expect(r.numeroOs, 'OS-24567');
    expect(c.anuncios, contains('Reutilização adicionada com sucesso'));
    // O histórico do dispositivo já mostra o novo registro.
    expect(find.text('Novos furos'), findsNothing); // cartão recolhido
    expect(find.text(r.codigoPeca), findsWidgets);
  });

  testWidgets('registro direto com produto novo cadastra o produto', (tester) async {
    final b = _backend('projetista');
    await pumpTela(tester, b, const _Abridor(dispositivoId: 'd3', direto: true));
    await tocar(tester, find.text('abrir'));

    await tocar(tester, find.byKey(const ValueKey('reu_produto_2_null')));
    await tocar(tester, find.text('Outro (cadastrar novo)...').last);
    await digitar(tester, 'reu_novo_produto', 'SPE 7000');
    await digitar(tester, 'reu_os', 'OS-1');
    await digitar(tester, 'reu_descricao_peca', 'Suporte');
    await digitar(tester, 'reu_peso', '1');
    await digitar(tester, 'reu_hard_saving', '100');
    await digitar(tester, 'reu_responsavel', 'Ana');
    await digitar(tester, 'reu_descricao_alteracao', 'Ajuste');
    await tocar(tester, find.text('Registrar Reutilização'));

    final novo = b.classificacoes.itens(TipoClassificacao.produto).values.firstWhere((p) => p.nome == 'SPE 7000');
    final r = _novas(b).single;
    expect(r.produtoId, novo.id);
    expect(r.status, ReutilizacaoStatus.aprovada);
  });

  testWidgets('gerência não abre o formulário', (tester) async {
    final b = _backend('gerencia');
    await pumpTela(tester, b, const _Abridor(dispositivoId: 'd1'));
    await tocar(tester, find.text('abrir'));
    expect(find.text('Solicitar Reutilização de Dispositivo'), findsNothing);
    expect(find.text('Acesso negado: seu perfil possui acesso somente de consulta.'), findsOneWidget);
  });

  testWidgets('engenharia não faz registro direto', (tester) async {
    final b = _backend('engenharia');
    await pumpTela(tester, b, const _Abridor(dispositivoId: 'd1', direto: true));
    await tocar(tester, find.text('abrir'));
    expect(find.text('Nova Reutilização'), findsNothing);
    expect(find.textContaining('cadastrar reutilizações diretamente'), findsOneWidget);
  });

  testWidgets('sem overflow em 360px (registro direto)', (tester) async {
    final b = _backend('admin');
    await pumpTela(tester, b, const _Abridor(dispositivoId: 'd1', direto: true), tamanho: const Size(360, 740));
    await tocar(tester, find.text('abrir'));
    await tocar(tester, find.text('Registrar Reutilização'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sem overflow em 360px (solicitação)', (tester) async {
    await pumpTela(tester, _backend('engenharia'), const _Abridor(dispositivoId: 'd1'), tamanho: const Size(360, 740));
    await tocar(tester, find.text('abrir'));
    await tocar(tester, find.text('Enviar Solicitação'));
    expect(tester.takeException(), isNull);
  });
}
