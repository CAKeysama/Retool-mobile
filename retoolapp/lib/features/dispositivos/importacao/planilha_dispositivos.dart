import 'dart:typed_data';

import '../../../domain/entities/classificacao.dart';
import '../../../domain/entities/dispositivo.dart';
import 'leitura/celulas.dart';
import 'leitura/erros.dart';
import 'leitura/leitor_csv.dart';
import 'leitura/leitor_xlsx.dart';

export 'leitura/celulas.dart' show CelulaNumero, CelulaPlanilha, CelulaXlsx, textoCelula, textoDaCelula;
export 'leitura/erros.dart';
export 'leitura/leitor_csv.dart' show decodificarTexto, adivinharSeparador;

/// Porte de `src/application/importacao/planilhaDispositivos.ts` do desktop:
/// leitura de .xlsx/.csv e conversão das linhas em dispositivos com a regra de
/// unicidade Código + Dispositivo. Código puro (sem Flutter), roda em isolate.

/// Uma aba da planilha: cabeçalho + linhas de dados.
class AbaPlanilha {
  final String nome;
  final List<String> cabecalhos;
  final List<List<CelulaPlanilha>> linhas;
  const AbaPlanilha({required this.nome, required this.cabecalhos, required this.linhas});
}

class ResumoAba {
  final String nome;
  int linhas = 0;
  final String? colunaCodigo;
  final String? colunaDispositivo;

  /// Aba ignorada por não ter nenhuma das colunas-chave (Código / Dispositivo).
  final bool ignorada;
  ResumoAba({required this.nome, required this.colunaCodigo, required this.colunaDispositivo, required this.ignorada});
}

class ResumoImportacao {
  /// Linhas de dados lidas nas abas importáveis (linhas totalmente vazias não contam).
  int linhasLidas = 0;

  /// Combinações Código + Dispositivo distintas = registros que serão gravados.
  int combinacoesUnicas = 0;

  /// Linhas descartadas por repetirem uma combinação já vista.
  int duplicadasRemovidas = 0;

  /// Linhas sem Código e sem Dispositivo (não identificáveis).
  int linhasSemChave = 0;
  int linhasSemCodigo = 0;
  int linhasSemDispositivo = 0;
  final List<ResumoAba> abas = [];
  final List<String> avisos = [];
}

class ResultadoProcessamento {
  /// Mapas no formato gravado pelo desktop (`Partial<Dispositivo>`). Classificações
  /// novas vão pelo NOME em `categoriaId`/`familiaId`/`produtoId` (o repositório
  /// cria e troca pelo id).
  final List<Map<String, dynamic>> dispositivos;
  final List<String> novasCategorias;
  final List<String> novasFamilias;
  final List<String> novosProdutos;
  final ResumoImportacao resumo;
  const ResultadoProcessamento({
    required this.dispositivos,
    required this.novasCategorias,
    required this.novasFamilias,
    required this.novosProdutos,
    required this.resumo,
  });
}

class ContextoProcessamento {
  final List<Classificacao> categorias;
  final List<Classificacao> familias;
  final List<Classificacao> produtos;
  final String? defaultCategoriaId;
  const ContextoProcessamento({
    this.categorias = const [],
    this.familias = const [],
    this.produtos = const [],
    this.defaultCategoriaId,
  });
}

// ---------------------------------------------------------------------------
// Leitura do arquivo
// ---------------------------------------------------------------------------

bool ehCsv(String nomeArquivo) => RegExp(r'\.(csv|txt)$', caseSensitive: false).hasMatch(nomeArquivo);

bool _comeca(Uint8List b, List<int> magia) {
  if (b.length < magia.length) return false;
  for (var i = 0; i < magia.length; i++) {
    if (b[i] != magia[i]) return false;
  }
  return true;
}

/// Lê .xlsx/.csv e devolve cada aba como texto. CSV é decodificado
/// explicitamente (UTF-8/Windows-1252) e lido como texto puro, para que
/// "0041" continue "0041" e o cabeçalho "Código" não vire "CÃ³digo".
/// .xls (Excel 97-2003, binário) gera [ErroLeituraPlanilha] com orientação.
List<AbaPlanilha> lerPlanilha(Uint8List bytes, String nomeArquivo) {
  final List<AbaBruta> brutas;
  if (ehCsv(nomeArquivo)) {
    brutas = lerCsv(bytes);
  } else if (_comeca(bytes, const [0x50, 0x4B, 0x03, 0x04])) {
    brutas = lerXlsx(bytes);
  } else if (_comeca(bytes, const [0xD0, 0xCF, 0x11, 0xE0]) || nomeArquivo.toLowerCase().endsWith('.xls')) {
    throw const ErroLeituraPlanilha(mensagemXlsNaoSuportado);
  } else {
    throw const ErroLeituraPlanilha(mensagemArquivoInvalido);
  }
  return brutas.map(_montarAba).toList();
}

/// Intervalo real ocupado pela aba, calculado a partir das células existentes
/// (não confia na tag `<dimension>`, que pode estar desatualizada).
AbaPlanilha _montarAba(AbaBruta aba) {
  var linhas = aba.linhas.where((l) => l.colunas.isNotEmpty).toList();
  if (linhas.isEmpty) return AbaPlanilha(nome: aba.nome, cabecalhos: const [], linhas: const []);

  var ordenada = true;
  for (var i = 1; i < linhas.length; i++) {
    if (linhas[i].r <= linhas[i - 1].r) {
      ordenada = false;
      break;
    }
  }
  if (!ordenada) {
    final porLinha = <int, LinhaBruta>{};
    for (final l in linhas) {
      final destino = porLinha.putIfAbsent(l.r, () => LinhaBruta(l.r));
      destino.colunas.addAll(l.colunas);
      destino.valores.addAll(l.valores);
    }
    linhas = porLinha.values.toList()..sort((a, b) => a.r.compareTo(b.r));
  }

  var minC = 1 << 30, maxC = -1;
  for (final l in linhas) {
    for (final c in l.colunas) {
      if (c < minC) minC = c;
      if (c > maxC) maxC = c;
    }
  }
  final largura = maxC - minC + 1;
  List<CelulaPlanilha> densa(LinhaBruta l) {
    final v = List<CelulaPlanilha>.filled(largura, '');
    for (var k = 0; k < l.colunas.length; k++) {
      v[l.colunas[k] - minC] = l.valores[k];
    }
    return v;
  }

  final cabecalhos = densa(linhas.first).map(textoCelula).toList();
  final dados = [for (final l in linhas.skip(1)) densa(l)];
  return AbaPlanilha(nome: aba.nome, cabecalhos: cabecalhos, linhas: dados);
}

// ---------------------------------------------------------------------------
// Processamento (regra Código + Dispositivo)
// ---------------------------------------------------------------------------

/// Normaliza um cabeçalho: sem acento, caixa, pontuação ou espaços extras.
String normalizarCabecalho(String? cabecalho) => removerAcentos(cabecalho ?? '')
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim();

/// Apelidos aceitos para cada coluna (já normalizados) — mesmos do desktop.
const colunasAceitas = <String, List<String>>{
  'codigo': ['codigo', 'codigo da peca', 'codigo peca'],
  'nome': ['dispositivo', 'n dispositivo', 'nome'],
  'peso': ['peso', 'peso kg', 'peso dispositivo kg'],
  'familia': ['familia', 'familia do produto'],
  'produto': ['produto'],
  // Usuário pediu para trocar Categoria por Tipo de Dispositivo
  'categoria': ['categoria', 'tipo de dispositivo', 'tipo dispositivo', 'tipo'],
  'descricao': ['descricao', 'descricao da peca'],
  'palavrasChave': ['palavra chave', 'palavras chaves', 'palavras chave'],
};

Map<String, int> _mapearColunas(List<String> cabecalhos) {
  final normalizados = cabecalhos.map(normalizarCabecalho).toList();
  final mapa = <String, int>{};
  colunasAceitas.forEach((campo, apelidos) {
    mapa[campo] = -1;
    for (final alias in apelidos) {
      final idx = normalizados.indexOf(alias);
      if (idx >= 0) {
        mapa[campo] = idx;
        break;
      }
    }
  });
  return mapa;
}

final _espacos = RegExp(r'\s+');

/// Texto ASCII visível com espaços simples só no meio: nada a normalizar.
bool _asciiLimpo(String s) {
  final n = s.length;
  if (n == 0) return true;
  if (s.codeUnitAt(0) == 32 || s.codeUnitAt(n - 1) == 32) return false;
  var anteriorEspaco = false;
  for (var i = 0; i < n; i++) {
    final c = s.codeUnitAt(i);
    if (c == 32) {
      if (anteriorEspaco) return false;
      anteriorEspaco = true;
    } else if (c < 33 || c > 126) {
      return false;
    } else {
      anteriorEspaco = false;
    }
  }
  return true;
}

String _limparTexto(String? v) {
  final s = v ?? '';
  return _asciiLimpo(s) ? s : s.replaceAll(_espacos, ' ').trim();
}
String _chaveNome(String v) => v.toLowerCase().trim();

/// Resolve um nome de classificação para o id existente ou, se ainda não
/// existir, para o próprio nome (que o repositório cria e substitui pelo id).
/// Busca O(1) e insensível a caixa/espaços.
class _Resolvedor {
  final Map<String, String> _porNome = {};
  final Map<String, String> _novos = {};
  _Resolvedor(List<Classificacao> existentes) {
    for (final e in existentes) {
      if (e.nome.isNotEmpty) _porNome[_chaveNome(e.nome)] = e.id;
    }
  }

  String resolver(String nome) {
    final k = _chaveNome(nome);
    final existente = _porNome[k];
    if (existente != null) return existente;
    return _novos.putIfAbsent(k, () => nome);
  }

  List<String> get novos => _novos.values.toList();
}

final _numeroJs = RegExp(r'^[\t\n\v\f\r  ﻿]*([+-]?(?:Infinity|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?))');

/// `parseFloat` do JavaScript: lê o prefixo numérico ("2.5 kg" → 2.5); sem número → NaN.
double parseFloatJs(String s) {
  final m = _numeroJs.firstMatch(s);
  if (m == null) return double.nan;
  final t = m.group(1)!;
  if (t.endsWith('Infinity')) return t.startsWith('-') ? double.negativeInfinity : double.infinity;
  return double.parse(t);
}

/// `String(numero)` do JavaScript.
String _numeroJs2Texto(double v) {
  if (v.isInfinite) return v > 0 ? 'Infinity' : '-Infinity';
  if (v == 0) return '0';
  if (v == v.truncateToDouble() && v.abs() < 1e21) return v.toStringAsFixed(0);
  return v.toString();
}

const _compostos = <int, Map<String, String>>{
  0x0300: {'A': 'À', 'a': 'à', 'E': 'È', 'e': 'è', 'I': 'Ì', 'i': 'ì', 'O': 'Ò', 'o': 'ò', 'U': 'Ù', 'u': 'ù'},
  0x0301: {
    'A': 'Á', 'a': 'á', 'E': 'É', 'e': 'é', 'I': 'Í', 'i': 'í', 'O': 'Ó', 'o': 'ó', 'U': 'Ú', 'u': 'ú',
    'Y': 'Ý', 'y': 'ý', 'C': 'Ć', 'c': 'ć', 'N': 'Ń', 'n': 'ń',
  },
  0x0302: {'A': 'Â', 'a': 'â', 'E': 'Ê', 'e': 'ê', 'I': 'Î', 'i': 'î', 'O': 'Ô', 'o': 'ô', 'U': 'Û', 'u': 'û'},
  0x0303: {'A': 'Ã', 'a': 'ã', 'O': 'Õ', 'o': 'õ', 'N': 'Ñ', 'n': 'ñ'},
  0x0308: {'A': 'Ä', 'a': 'ä', 'E': 'Ë', 'e': 'ë', 'I': 'Ï', 'i': 'ï', 'O': 'Ö', 'o': 'ö', 'U': 'Ü', 'u': 'ü', 'y': 'ÿ'},
  0x030A: {'A': 'Å', 'a': 'å'},
  0x0327: {'C': 'Ç', 'c': 'ç'},
};
final _marcaCombinante = RegExp('[̀-ͯ]');

/// Composição NFC das letras acentuadas do pt-BR ("C" + U+0327 → "Ç"), para
/// que texto decomposto (NFD, comum em arquivos vindos do macOS) gere a mesma
/// chave que o texto composto — como o `normalize('NFC')` do desktop.
String comporNfc(String s) {
  if (!_marcaCombinante.hasMatch(s)) return s;
  final sb = StringBuffer();
  final runas = s.runes.toList();
  for (var i = 0; i < runas.length; i++) {
    final atual = String.fromCharCode(runas[i]);
    if (i + 1 < runas.length) {
      final composto = _compostos[runas[i + 1]]?[atual];
      if (composto != null) {
        sb.write(composto);
        i++;
        continue;
      }
    }
    sb.write(atual);
  }
  return sb.toString();
}

String _normalizarParaChave(Object? v) {
  if (v is String && _asciiLimpo(v)) return v.toLowerCase(); // caminho rápido, mesmo resultado
  return normalizarValorChave(v is String ? comporNfc(v) : v);
}

/// Chave de unicidade usada na importação: mesma regra de `chaveCodigoDispositivo`
/// (Código + Dispositivo normalizados) + composição NFC, num formato mais barato
/// para milhares de linhas. O separador U+0000 nunca sobra após a normalização
/// (controles são removidos), então campos não colidem.
String chaveImportacao(Object? codigo, Object? nome) => '${_normalizarParaChave(codigo)}\u0000${_normalizarParaChave(nome)}';

/// Converte as abas lidas em dispositivos, aplicando a regra de unicidade
/// Código + Dispositivo. Linhas com a mesma combinação geram um único registro
/// (Código/Dispositivo da 1ª ocorrência; demais campos da última); combinações
/// diferentes nunca são fundidas. Tudo o que é descartado entra no `resumo`.
ResultadoProcessamento processarPlanilhaDispositivos(List<AbaPlanilha> abas, ContextoProcessamento ctx) {
  final categorias = _Resolvedor(ctx.categorias);
  final familias = _Resolvedor(ctx.familias);
  final produtos = _Resolvedor(ctx.produtos);

  final porChave = <String, Map<String, dynamic>>{};
  final resumo = ResumoImportacao();

  for (final aba in abas) {
    final col = _mapearColunas(aba.cabecalhos);
    final iCodigo = col['codigo']!, iNome = col['nome']!;
    final resumoAba = ResumoAba(
      nome: aba.nome,
      colunaCodigo: iCodigo >= 0 ? aba.cabecalhos[iCodigo] : null,
      colunaDispositivo: iNome >= 0 ? aba.cabecalhos[iNome] : null,
      ignorada: iCodigo < 0 && iNome < 0,
    );
    resumo.abas.add(resumoAba);
    if (resumoAba.ignorada) continue;

    if (iCodigo < 0) {
      resumo.avisos.add('Aba "${aba.nome}": coluna Código não encontrada — os registros dessa aba ficarão sem Código.');
    }
    if (iNome < 0) {
      resumo.avisos
          .add('Aba "${aba.nome}": coluna Dispositivo não encontrada — os registros dessa aba ficarão sem Dispositivo.');
    }

    String valor(List<CelulaPlanilha> linha, int idx) =>
        idx >= 0 && idx < linha.length ? _limparTexto(textoCelula(linha[idx])) : '';

    for (final linha in aba.linhas) {
      if (linha.every((c) => textoCelula(c).trim().isEmpty)) continue; // linha totalmente vazia
      resumoAba.linhas++;
      resumo.linhasLidas++;

      final codigo = valor(linha, iCodigo);
      final nome = valor(linha, iNome);
      if (codigo.isEmpty && nome.isEmpty) {
        resumo.linhasSemChave++;
        continue;
      }
      if (codigo.isEmpty) resumo.linhasSemCodigo++;
      if (nome.isEmpty) resumo.linhasSemDispositivo++;

      final iPeso = col['peso']!;
      final celulaPeso = iPeso >= 0 && iPeso < linha.length ? linha[iPeso] : null;
      final rawPeso = valor(linha, iPeso);
      final pesoConvertido = celulaPeso is CelulaNumero
          ? celulaPeso.numero
          : (rawPeso.isNotEmpty ? parseFloatJs(rawPeso.replaceFirst(',', '.')) : 0.0);
      final categoriaNome = valor(linha, col['categoria']!);
      final familiaNome = valor(linha, col['familia']!);
      final produtoNome = valor(linha, col['produto']!);
      final palavrasRaw = valor(linha, col['palavrasChave']!);

      final dispositivo = <String, dynamic>{
        'familiaId': familiaNome.isNotEmpty ? familias.resolver(familiaNome) : '',
        'produtoId': produtoNome.isNotEmpty ? produtos.resolver(produtoNome) : '',
        'categoriaId': categoriaNome.isNotEmpty ? categorias.resolver(categoriaNome) : (ctx.defaultCategoriaId ?? ''),
        'codigo': codigo,
        'descricao': valor(linha, col['descricao']!),
        'nome': nome,
        'peso': pesoConvertido.isNaN ? '' : _numeroJs2Texto(pesoConvertido),
        'palavrasChave': palavrasRaw.isNotEmpty
            ? palavrasRaw.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList()
            : <String>[],
        'imagemPeca': '',
        'imagemDispositivo': '',
      };

      final chave = chaveImportacao(codigo, nome);
      final anterior = porChave[chave];
      if (anterior != null) {
        resumo.duplicadasRemovidas++;
        // Mantém Código/Dispositivo da primeira ocorrência; demais campos da última.
        porChave[chave] = {...anterior, ...dispositivo, 'codigo': anterior['codigo'], 'nome': anterior['nome']};
      } else {
        porChave[chave] = dispositivo;
      }
    }
  }

  final dispositivos = porChave.values.toList();
  resumo.combinacoesUnicas = dispositivos.length;
  if (resumo.linhasSemChave > 0) {
    resumo.avisos.add('${resumo.linhasSemChave} linha(s) sem Código e sem Dispositivo foram ignoradas.');
  }

  return ResultadoProcessamento(
    dispositivos: dispositivos,
    novasCategorias: categorias.novos,
    novasFamilias: familias.novos,
    novosProdutos: produtos.novos,
    resumo: resumo,
  );
}

// ---------------------------------------------------------------------------
// Pré-visualização (roda em isolate)
// ---------------------------------------------------------------------------

/// Tudo o que o isolate precisa (objetos simples, copiáveis entre isolates).
class EntradaImportacao {
  final Uint8List bytes;
  final String nomeArquivo;
  final ContextoProcessamento contexto;

  /// (codigo, nome) dos dispositivos já cadastrados, para contar novos × atualizados.
  final List<(String?, String?)> existentes;
  const EntradaImportacao({
    required this.bytes,
    required this.nomeArquivo,
    required this.contexto,
    this.existentes = const [],
  });
}

class PreVisualizacaoImportacao {
  final ResultadoProcessamento resultado;

  /// Combinações que ainda não existem no acervo (serão criadas).
  final int novos;

  /// Combinações que já existem (o documento será atualizado).
  final int atualizados;
  const PreVisualizacaoImportacao({required this.resultado, required this.novos, required this.atualizados});

  int get total => resultado.dispositivos.length;
}

/// Lê + processa + compara com o acervo. Função de topo para `compute`.
PreVisualizacaoImportacao prepararImportacao(EntradaImportacao e) {
  final resultado = processarPlanilhaDispositivos(lerPlanilha(e.bytes, e.nomeArquivo), e.contexto);
  final chaves = {for (final (c, n) in e.existentes) chaveImportacao(c, n)};
  var atualizados = 0;
  for (final d in resultado.dispositivos) {
    if (chaves.contains(chaveImportacao(d['codigo'], d['nome']))) atualizados++;
  }
  return PreVisualizacaoImportacao(
    resultado: resultado,
    novos: resultado.dispositivos.length - atualizados,
    atualizados: atualizados,
  );
}
