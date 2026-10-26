import 'package:flutter_test/flutter_test.dart';
import 'package:retoolapp/domain/entities/dispositivo.dart';
import 'package:retoolapp/domain/entities/reutilizacao.dart';
import 'package:retoolapp/features/reutilizacoes/reutilizacoes_logica.dart';

void main() {
  group('abas por perfil', () {
    test('mesma ordem e regras do desktop', () {
      expect(abasDoPerfil('admin'),
          [AbaReutilizacoes.filaProjetista, AbaReutilizacoes.filaEngenharia, AbaReutilizacoes.historico]);
      expect(abasDoPerfil('projetista'), [AbaReutilizacoes.filaProjetista, AbaReutilizacoes.historico]);
      expect(abasDoPerfil('engenharia'), [AbaReutilizacoes.filaEngenharia, AbaReutilizacoes.historico]);
      expect(abasDoPerfil('gerencia'), [AbaReutilizacoes.historico]);
    });

    test('aba do destaque', () {
      expect(abaParaDestaque('projetista', ReutilizacaoStatus.emAnaliseProjetista), AbaReutilizacoes.filaProjetista);
      expect(abaParaDestaque('engenharia', ReutilizacaoStatus.emAnaliseProjetista), AbaReutilizacoes.historico);
      expect(abaParaDestaque('engenharia', ReutilizacaoStatus.naoAprovada), AbaReutilizacoes.filaEngenharia);
      expect(abaParaDestaque('admin', ReutilizacaoStatus.aprovada), AbaReutilizacoes.filaEngenharia);
      expect(abaParaDestaque('admin', ReutilizacaoStatus.liberadoFabricacao), AbaReutilizacoes.historico);
      expect(abaParaDestaque('gerencia', ReutilizacaoStatus.emAnaliseEngenharia), AbaReutilizacoes.historico);
    });
  });

  test('ações de fluxo com os rótulos do desktop', () {
    List<String> rotulos(String p, ReutilizacaoStatus s) => acoesDeFluxo(p, s).map((a) => a.rotulo).toList();
    expect(rotulos('engenharia', ReutilizacaoStatus.emAnaliseEngenharia), ['Solicitar Análise (1º Filtro)']);
    expect(rotulos('projetista', ReutilizacaoStatus.emAnaliseProjetista), ['Aprovar', 'Não Aprovar']);
    expect(rotulos('engenharia', ReutilizacaoStatus.emAnaliseProjetista), isEmpty);
    expect(rotulos('engenharia', ReutilizacaoStatus.naoAprovada), ['Solicitar Dispositivo Novo']);
    expect(rotulos('projetista', ReutilizacaoStatus.aguardandoNovoFiltro), ['Similar Encontrado', 'Liberar Fabricação']);
    expect(rotulos('admin', ReutilizacaoStatus.aprovada), isEmpty);
    expect(rotulos('gerencia', ReutilizacaoStatus.emAnaliseProjetista), isEmpty);
    expect(acoesDeFluxo('admin', ReutilizacaoStatus.emAnaliseProjetista).last.exigeMotivo, isTrue);
  });

  group('ListasReutilizacoes', () {
    final hoje = DateTime(2026, 10, 22);
    String dia(int atras) => hoje.subtract(Duration(days: atras)).toIso8601String().substring(0, 10);
    final reus = [
      Reutilizacao(id: 'a', dispositivoId: 'd1', data: dia(5), codigoPeca: 'PC-1', produtoId: 'p1',
          descricaoAlteracao: 'Furação', status: ReutilizacaoStatus.emAnaliseProjetista, dataCriacao: '2026-10-17T00:00:00Z'),
      Reutilizacao(id: 'b', dispositivoId: 'd2', data: dia(60), codigoPeca: 'PC-2', produtoId: 'p2',
          descricaoAlteracao: 'Usinagem', status: ReutilizacaoStatus.aprovada, dataCriacao: '2026-08-23T00:00:00Z'),
      Reutilizacao(id: 'c', dispositivoId: 'd1', data: dia(400), codigoPeca: 'PC-3',
          descricaoAlteracao: 'Solda', status: ReutilizacaoStatus.emAnaliseEngenharia, dataCriacao: '2025-09-17T00:00:00Z'),
    ];
    const disps = [Dispositivo(id: 'd1', nome: 'Gabarito Ágil', codigo: 'GAB-1'), Dispositivo(id: 'd2', nome: 'Válvula')];
    Dispositivo? porId(String? id) => disps.where((d) => d.id == id).firstOrNull;

    test('filas, ordenação e memoização por snapshot', () {
      final l = ListasReutilizacoes()..atualizar(reus, disps, porId);
      expect(l.filaProjetista.map((r) => r.id), ['a']);
      expect(l.filaEngenharia.map((r) => r.id), ['b', 'c']);
      expect(l.todas.map((r) => r.id), ['a', 'b', 'c']);
      l.atualizar(reus, disps, porId);
      expect(l.recalculos, 1, reason: 'mesmo snapshot não recalcula');
      final h1 = l.historico(const FiltrosHistorico(), agora: hoje);
      expect(identical(h1, l.historico(const FiltrosHistorico(), agora: hoje)), isTrue);
      l.atualizar([...reus], disps, porId);
      expect(l.recalculos, 2);
    });

    test('filtros do histórico', () {
      final l = ListasReutilizacoes()..atualizar(reus, disps, porId);
      List<String> ids(FiltrosHistorico f) => l.historico(f, agora: hoje).map((r) => r.id).toList();
      expect(ids(const FiltrosHistorico(texto: 'pc-2')), ['b']);
      expect(ids(const FiltrosHistorico(texto: 'gabarito agil')), ['a', 'c'], reason: 'busca pelo dispositivo sem acento');
      expect(ids(const FiltrosHistorico(status: ReutilizacaoStatus.aprovada)), ['b']);
      expect(ids(const FiltrosHistorico(dispositivoId: 'd1')), ['a', 'c']);
      expect(ids(const FiltrosHistorico(produtoId: 'p2')), ['b']);
      expect(ids(const FiltrosHistorico(periodo: PeriodoFiltro.dias30)), ['a']);
      expect(ids(const FiltrosHistorico(periodo: PeriodoFiltro.dias90)), ['a', 'b']);
      expect(ids(const FiltrosHistorico(periodo: PeriodoFiltro.meses12)), ['a', 'b']);
      expect(const FiltrosHistorico(status: ReutilizacaoStatus.aprovada, produtoId: 'x').ativos, 2);
      expect(l.dispositivosReferenciados, ['d1', 'd2']);
    });

    test('pendências por perfil', () {
      final l = ListasReutilizacoes()..atualizar(reus, disps, porId);
      expect(l.pendentes(AbaReutilizacoes.filaProjetista, 'projetista'), 1);
      expect(l.pendentes(AbaReutilizacoes.filaEngenharia, 'engenharia'), 1);
      expect(l.pendentes(AbaReutilizacoes.filaProjetista, 'gerencia'), 0);
    });
  });
}
