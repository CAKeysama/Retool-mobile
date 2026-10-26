import 'dart:convert';
import 'dart:typed_data';

import 'celulas.dart';
import 'erros.dart';
import 'formato_excel.dart';
import 'inflar_stub.dart' if (dart.library.io) 'inflar_io.dart';

/// Leitor enxuto de .xlsx (ZIP + XML) feito para planilhas grandes: lê só as
/// partes necessárias (workbook, rels, styles, sharedStrings e abas), varre o
/// XML sem montar árvore e devolve, por célula, o mesmo que o SheetJS do
/// desktop entrega (`t`, `v`, `z`). O intervalo é calculado pelas células
/// existentes, não pela tag `<dimension>`.
List<AbaBruta> lerXlsx(Uint8List bytes) {
  final zip = _Zip.abrir(bytes);
  final workbook = zip.texto('xl/workbook.xml');
  if (workbook == null) throw const ErroLeituraPlanilha(mensagemArquivoInvalido);

  final rels = <String, ({String tipo, String alvo})>{};
  final relsXml = zip.texto('xl/_rels/workbook.xml.rels');
  if (relsXml != null) {
    for (final tag in _tags(relsXml, 'Relationship')) {
      final id = tag.atributo('Id');
      final alvo = tag.atributo('Target');
      if (id != null && alvo != null) rels[id] = (tipo: tag.atributo('Type') ?? '', alvo: _resolverAlvo(alvo));
    }
  }

  String? alvoDoTipo(String sufixo) {
    for (final r in rels.values) {
      if (r.tipo.endsWith(sufixo)) return r.alvo;
    }
    return null;
  }

  final compartilhadas = _lerCompartilhadas(zip.texto(alvoDoTipo('/sharedStrings') ?? 'xl/sharedStrings.xml'));
  final formatos = _lerFormatos(zip.texto(alvoDoTipo('/styles') ?? 'xl/styles.xml'));

  final abas = <AbaBruta>[];
  var n = 0;
  for (final tag in _tags(workbook, 'sheet')) {
    n++;
    final nome = decodificarXml(tag.atributo('name') ?? 'Sheet$n');
    final rid = tag.atributo('r:id') ?? tag.atributoComSufixo(':id');
    final rel = rid == null ? null : rels[rid];
    if (rel != null && !rel.tipo.endsWith('/worksheet')) continue; // chartsheet etc.
    final caminho = rel?.alvo ?? 'xl/worksheets/sheet$n.xml';
    final xml = zip.texto(caminho);
    abas.add(AbaBruta(nome, xml == null ? const [] : _lerCelulas(xml, compartilhadas, formatos)));
  }
  return abas;
}

String _resolverAlvo(String alvo) {
  final partes = <String>[];
  final base = alvo.startsWith('/') ? alvo.substring(1) : 'xl/$alvo';
  for (final p in base.split('/')) {
    if (p == '..') {
      if (partes.isNotEmpty) partes.removeLast();
    } else if (p.isNotEmpty && p != '.') {
      partes.add(p);
    }
  }
  return partes.join('/');
}

// ---------------------------------------------------------------------------
// ZIP (diretório central + DEFLATE cru)
// ---------------------------------------------------------------------------

class _Zip {
  final Uint8List bytes;
  final Map<String, ({int metodo, int tamanhoCompactado, int offsetLocal})> entradas;
  final Map<String, String> _porNomeMinusculo;

  _Zip(this.bytes, this.entradas) : _porNomeMinusculo = {for (final k in entradas.keys) k.toLowerCase(): k};

  static _Zip abrir(Uint8List bytes) {
    final bd = ByteData.sublistView(bytes);
    final minimo = bytes.length - 22 - 0xFFFF;
    var eocd = -1;
    for (var i = bytes.length - 22; i >= 0 && i >= minimo; i--) {
      if (bd.getUint32(i, Endian.little) == 0x06054b50) {
        eocd = i;
        break;
      }
    }
    if (eocd < 0) throw const ErroLeituraPlanilha(mensagemArquivoInvalido);
    final total = bd.getUint16(eocd + 10, Endian.little);
    var p = bd.getUint32(eocd + 16, Endian.little);
    final entradas = <String, ({int metodo, int tamanhoCompactado, int offsetLocal})>{};
    for (var k = 0; k < total; k++) {
      if (p + 46 > bytes.length || bd.getUint32(p, Endian.little) != 0x02014b50) {
        throw const ErroLeituraPlanilha(mensagemArquivoInvalido);
      }
      final metodo = bd.getUint16(p + 10, Endian.little);
      final compactado = bd.getUint32(p + 20, Endian.little);
      final lenNome = bd.getUint16(p + 28, Endian.little);
      final lenExtra = bd.getUint16(p + 30, Endian.little);
      final lenComentario = bd.getUint16(p + 32, Endian.little);
      final offset = bd.getUint32(p + 42, Endian.little);
      final nome = utf8.decode(Uint8List.sublistView(bytes, p + 46, p + 46 + lenNome), allowMalformed: true);
      entradas[nome.replaceAll(r'\', '/')] = (metodo: metodo, tamanhoCompactado: compactado, offsetLocal: offset);
      p += 46 + lenNome + lenExtra + lenComentario;
    }
    return _Zip(bytes, entradas);
  }

  Uint8List? ler(String nome) {
    final chave = entradas.containsKey(nome) ? nome : _porNomeMinusculo[nome.toLowerCase()];
    final e = chave == null ? null : entradas[chave];
    if (e == null) return null;
    final bd = ByteData.sublistView(bytes);
    final o = e.offsetLocal;
    if (o + 30 > bytes.length || bd.getUint32(o, Endian.little) != 0x04034b50) {
      throw const ErroLeituraPlanilha(mensagemArquivoInvalido);
    }
    final inicio = o + 30 + bd.getUint16(o + 26, Endian.little) + bd.getUint16(o + 28, Endian.little);
    final fim = inicio + e.tamanhoCompactado;
    if (fim > bytes.length) throw const ErroLeituraPlanilha(mensagemArquivoInvalido);
    final dados = Uint8List.sublistView(bytes, inicio, fim);
    return switch (e.metodo) {
      0 => dados,
      8 => inflarDeflate(dados),
      _ => throw const ErroLeituraPlanilha(mensagemArquivoInvalido),
    };
  }

  String? texto(String nome) {
    final b = ler(nome);
    return b == null ? null : utf8.decode(b, allowMalformed: true);
  }
}

// ---------------------------------------------------------------------------
// Varredura de XML (sem árvore)
// ---------------------------------------------------------------------------

class _Tag {
  final String xml;
  final int inicio; // posição do '<'
  final int fim; // posição do '>'
  final String nome; // nome qualificado (com prefixo, se houver)
  final bool autoFechada;
  const _Tag(this.xml, this.inicio, this.fim, this.nome, this.autoFechada);

  String get prefixo {
    final i = nome.indexOf(':');
    return i < 0 ? '' : nome.substring(0, i + 1);
  }

  String? atributo(String nomeAttr) => _atributo(xml, inicio + 1 + nome.length, fim, nomeAttr);

  String? atributoComSufixo(String sufixo) {
    final m = RegExp('\\s([\\w.-]+$sufixo)\\s*=\\s*["\']([^"\']*)["\']').firstMatch(xml.substring(inicio, fim));
    return m?.group(2);
  }

  /// Fim (exclusivo) do conteúdo e posição logo após `</nome>`.
  ({int conteudoFim, int depois}) fechamento() {
    final fechar = '</$nome>';
    final i = xml.indexOf(fechar, fim + 1);
    if (i < 0) return (conteudoFim: xml.length, depois: xml.length);
    return (conteudoFim: i, depois: i + fechar.length);
  }
}

bool _ehEspaco(int c) => c == 32 || c == 9 || c == 10 || c == 13;

String? _atributo(String s, int ini, int fim, String nome) {
  final n = nome.length;
  final primeiro = nome.codeUnitAt(0);
  var aspas = 0; // dentro de um valor: código da aspa
  for (var j = ini; j < fim; j++) {
    final ch = s.codeUnitAt(j);
    if (aspas != 0) {
      if (ch == aspas) aspas = 0;
      continue;
    }
    if (ch == 34 || ch == 39) {
      aspas = ch;
      continue;
    }
    if (ch != primeiro || j == 0 || !_ehEspaco(s.codeUnitAt(j - 1)) || !s.startsWith(nome, j)) continue;
    var q = j + n;
    while (q < fim && _ehEspaco(s.codeUnitAt(q))) {
      q++;
    }
    if (q >= fim || s.codeUnitAt(q) != 61) continue; // '='
    q++;
    while (q < fim && _ehEspaco(s.codeUnitAt(q))) {
      q++;
    }
    if (q >= fim) return null;
    final aspa = s[q];
    final fimValor = s.indexOf(aspa, q + 1);
    if (fimValor < 0) return null;
    return s.substring(q + 1, fimValor);
  }
  return null;
}

/// Próxima tag de abertura a partir de [pos] (ignora fechamentos, comentários e instruções).
_Tag? _proximaTag(String xml, int pos, [int? limite]) {
  final lim = limite ?? xml.length;
  var i = pos;
  while (true) {
    i = xml.indexOf('<', i);
    if (i < 0 || i >= lim) return null;
    final c = i + 1 < xml.length ? xml.codeUnitAt(i + 1) : 0;
    if (c == 47 || c == 63 || c == 33) {
      // '/', '?', '!'
      if (xml.startsWith('<!--', i)) {
        final f = xml.indexOf('-->', i);
        i = f < 0 ? xml.length : f + 3;
      } else if (xml.startsWith('<![CDATA[', i)) {
        final f = xml.indexOf(']]>', i);
        i = f < 0 ? xml.length : f + 3;
      } else {
        i++;
      }
      continue;
    }
    final fim = xml.indexOf('>', i);
    if (fim < 0) return null;
    var j = i + 1;
    while (j < fim) {
      final ch = xml.codeUnitAt(j);
      if (_ehEspaco(ch) || ch == 47) break;
      j++;
    }
    return _Tag(xml, i, fim, xml.substring(i + 1, j), xml.codeUnitAt(fim - 1) == 47);
  }
}

String _local(String nome) {
  final i = nome.indexOf(':');
  return i < 0 ? nome : nome.substring(i + 1);
}

Iterable<_Tag> _tags(String xml, String local, [int ini = 0, int? fim]) sync* {
  var pos = ini;
  while (true) {
    final t = _proximaTag(xml, pos, fim);
    if (t == null) return;
    if (_local(t.nome) == local) yield t;
    pos = t.fim + 1;
  }
}

/// Conteúdo de texto do primeiro elemento [local] dentro de [ini, fim).
String? _textoFilho(String xml, int ini, int fim, String local) {
  for (final t in _tags(xml, local, ini, fim)) {
    if (t.autoFechada) return '';
    final f = t.fechamento();
    return xml.substring(t.fim + 1, f.conteudoFim);
  }
  return null;
}

/// Concatena os `<t>` de um `<si>`/`<is>` (texto rico), ignorando a fonética `<rPh>`.
String _textoRico(String xml, int ini, int fim) {
  final sb = StringBuffer();
  var pos = ini;
  while (true) {
    final t = _proximaTag(xml, pos, fim);
    if (t == null) break;
    final local = _local(t.nome);
    if (local == 'rPh' && !t.autoFechada) {
      pos = t.fechamento().depois;
      continue;
    }
    if (local == 't' && !t.autoFechada) {
      final f = t.fechamento();
      sb.write(xml.substring(t.fim + 1, f.conteudoFim));
      pos = f.depois;
      continue;
    }
    pos = t.fim + 1;
  }
  return decodificarXml(sb.toString());
}

final _entidade = RegExp(r'&(lt|gt|amp|quot|apos|#x[0-9a-fA-F]+|#[0-9]+);');
final _escapeOoxml = RegExp(r'_x([0-9a-fA-F]{4})_');

/// Entidades XML e escapes `_xHHHH_` do OOXML.
String decodificarXml(String s) {
  var r = s;
  if (r.contains('&')) {
    r = r.replaceAllMapped(_entidade, (m) {
      final e = m.group(1)!;
      switch (e) {
        case 'lt':
          return '<';
        case 'gt':
          return '>';
        case 'amp':
          return '&';
        case 'quot':
          return '"';
        case 'apos':
          return "'";
      }
      final codigo = e.startsWith('#x') ? int.parse(e.substring(2), radix: 16) : int.parse(e.substring(1));
      return String.fromCharCode(codigo);
    });
  }
  if (r.contains('_x')) {
    r = r.replaceAllMapped(_escapeOoxml, (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)));
  }
  return r;
}

List<String> _lerCompartilhadas(String? xml) {
  if (xml == null) return const [];
  final lista = <String>[];
  var pos = 0;
  while (true) {
    final t = _proximaTag(xml, pos);
    if (t == null) break;
    if (_local(t.nome) == 'si') {
      if (t.autoFechada) {
        lista.add('');
        pos = t.fim + 1;
      } else {
        final f = t.fechamento();
        lista.add(_textoRico(xml, t.fim + 1, f.conteudoFim));
        pos = f.depois;
      }
      continue;
    }
    pos = t.fim + 1;
  }
  return lista;
}

/// Código de formato de cada estilo de célula (`cellXfs`), indexado pelo atributo `s`.
List<String> _lerFormatos(String? xml) {
  if (xml == null) return const [];
  final personalizados = <int, String>{};
  for (final t in _tags(xml, 'numFmt')) {
    final id = int.tryParse(t.atributo('numFmtId') ?? '');
    final codigo = t.atributo('formatCode');
    if (id != null && codigo != null) personalizados[id] = decodificarXml(codigo);
  }
  final formatos = <String>[];
  for (final bloco in _tags(xml, 'cellXfs')) {
    if (bloco.autoFechada) break;
    final f = bloco.fechamento();
    for (final xf in _tags(xml, 'xf', bloco.fim + 1, f.conteudoFim)) {
      final id = int.tryParse(xf.atributo('numFmtId') ?? '0') ?? 0;
      formatos.add(personalizados[id] ?? formatosPadraoExcel[id] ?? 'General');
    }
    break;
  }
  return formatos;
}

/// Converte "AB12" em (linha 11, coluna 27) — base zero.
(int, int)? _decodificarRef(String ref) {
  var col = 0, i = 0;
  while (i < ref.length) {
    final c = ref.codeUnitAt(i);
    if (c >= 65 && c <= 90) {
      col = col * 26 + (c - 64);
    } else if (c >= 97 && c <= 122) {
      col = col * 26 + (c - 96);
    } else if (c != 36) {
      break; // '$'
    }
    i++;
  }
  if (col == 0 || i >= ref.length) return null;
  final linha = int.tryParse(ref.substring(i).replaceAll(r'$', ''));
  if (linha == null) return null;
  return (linha - 1, col - 1);
}

List<LinhaBruta> _lerCelulas(String xml, List<String> compartilhadas, List<String> formatos) {
  final linhas = <LinhaBruta>[];
  var inicio = 0;
  var fimDados = xml.length;
  var prefixo = '';
  for (final t in _tags(xml, 'sheetData')) {
    if (t.autoFechada) return linhas;
    inicio = t.fim + 1;
    fimDados = t.fechamento().conteudoFim;
    prefixo = t.prefixo;
    break;
  }
  // Varredura especializada (caminho quente: milhões de células).
  final abreRow = '<${prefixo}row', abreC = '<${prefixo}c';
  final fechaC = '</${prefixo}c>', abreV = '<${prefixo}v>', fechaV = '</${prefixo}v>';
  bool fimDeNome(int p) {
    if (p >= xml.length) return false;
    final ch = xml.codeUnitAt(p);
    return _ehEspaco(ch) || ch == 62 || ch == 47; // espaço, '>' ou '/'
  }

  var linhaAtual = -1, colAtual = -1;
  LinhaBruta? linha;
  var pos = inicio;
  while (true) {
    final i = xml.indexOf('<', pos);
    if (i < 0 || i >= fimDados) break;
    final fimTag = xml.indexOf('>', i);
    if (fimTag < 0) break;
    if (xml.startsWith(abreRow, i) && fimDeNome(i + abreRow.length)) {
      final r = int.tryParse(_atributo(xml, i + abreRow.length, fimTag, 'r') ?? '');
      linhaAtual = r != null ? r - 1 : linhaAtual + 1;
      colAtual = -1;
      linha = null;
      pos = fimTag + 1;
      continue;
    }
    if (!(xml.startsWith(abreC, i) && fimDeNome(i + abreC.length))) {
      pos = fimTag + 1;
      continue;
    }

    final iniAttr = i + abreC.length;
    final ref = _atributo(xml, iniAttr, fimTag, 'r');
    final pos2 = ref == null ? null : _decodificarRef(ref);
    final int r, c;
    if (pos2 != null) {
      (r, c) = pos2;
    } else {
      r = linhaAtual < 0 ? 0 : linhaAtual;
      c = colAtual + 1;
    }
    linhaAtual = r;
    colAtual = c;
    if (xml.codeUnitAt(fimTag - 1) == 47) {
      pos = fimTag + 1;
      continue; // célula sem valor (só estilo): o SheetJS também a ignora
    }
    var fimCelula = xml.indexOf(fechaC, fimTag);
    if (fimCelula < 0) fimCelula = fimDados;
    pos = fimCelula + fechaC.length;

    final tipo = _atributo(xml, iniAttr, fimTag, 't') ?? 'n';
    Object? valor;
    if (tipo == 'inlineStr') {
      valor = _textoRico(xml, fimTag + 1, fimCelula);
    } else {
      String? v;
      final iv = xml.indexOf(abreV, fimTag);
      if (iv >= 0 && iv < fimCelula) {
        final fv = xml.indexOf(fechaV, iv);
        v = xml.substring(iv + abreV.length, fv < 0 || fv > fimCelula ? fimCelula : fv);
      } else {
        v = _textoFilho(xml, fimTag + 1, fimCelula, 'v');
      }
      if (v == null) continue;
      switch (tipo) {
        case 's':
          final idx = int.tryParse(v.trim());
          if (idx == null || idx < 0 || idx >= compartilhadas.length) continue;
          valor = compartilhadas[idx];
        case 'str' || 'd':
          valor = decodificarXml(v);
        case 'b':
          valor = textoDaCelula(CelulaXlsx('b', v: v.trim() == '1', w: v.trim() == '1' ? 'TRUE' : 'FALSE'));
        case 'e':
          valor = textoDaCelula(CelulaXlsx('e', v: v, w: decodificarXml(v)));
        default:
          final numero = double.tryParse(v.trim());
          if (numero == null) continue;
          final s = int.tryParse(_atributo(xml, iniAttr, fimTag, 's') ?? '');
          final z = s != null && s >= 0 && s < formatos.length ? formatos[s] : 'General';
          valor = CelulaNumero(textoDaCelula(CelulaXlsx('n', v: numero, z: z)), numero);
      }
    }

    if (linha == null || linha.r != r) {
      linha = LinhaBruta(r);
      linhas.add(linha);
    }
    linha.colunas.add(c);
    linha.valores.add(valor);
  }
  return linhas;
}
