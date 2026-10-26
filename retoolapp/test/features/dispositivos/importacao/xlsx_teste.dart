import 'dart:convert';
import 'dart:io' show ZLibEncoder;
import 'dart:typed_data';

import 'package:retoolapp/features/dispositivos/importacao/leitura/formato_excel.dart';

/// Célula para montar um .xlsx de teste (como o Excel salvaria): `t` = 's' texto,
/// 'n' número, 'b' booleano; `z` = código de formato.
typedef CelulaTeste = ({String t, Object v, String? z});

CelulaTeste txt(String v) => (t: 's', v: v, z: null);
CelulaTeste num_(num v, [String? z]) => (t: 'n', v: v, z: z);

String _esc(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

/// Gera um .xlsx em memória. [dimensao] sobrescreve a tag `<dimension>` (para
/// simular geradores que a deixam desatualizada). [comprimir] usa DEFLATE.
Uint8List xlsxDe(
  Map<String, CelulaTeste> celulas, {
  String nomeAba = 'DADOS',
  String? dimensao,
  bool comprimir = true,
  bool compartilhadas = true,
  Map<String, Map<String, CelulaTeste>> outrasAbas = const {},
}) {
  final abas = {nomeAba: celulas, ...outrasAbas};
  final strings = <String>[];
  final idxString = <String, int>{};
  final formatos = <String>['General'];
  final customIds = <String, int>{};
  int estilo(String? z) {
    if (z == null || z == 'General') return 0;
    var i = formatos.indexOf(z);
    if (i < 0) {
      formatos.add(z);
      i = formatos.length - 1;
    }
    return i;
  }

  String sheetXml(Map<String, CelulaTeste> cels) {
    final porLinha = <int, List<MapEntry<String, CelulaTeste>>>{};
    for (final e in cels.entries) {
      final linha = int.parse(e.key.replaceAll(RegExp('[A-Z]'), ''));
      porLinha.putIfAbsent(linha, () => []).add(e);
    }
    final linhas = porLinha.keys.toList()..sort();
    final sb = StringBuffer(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">');
    sb.write('<dimension ref="${dimensao ?? 'A1'}"/><sheetData>');
    for (final l in linhas) {
      sb.write('<row r="$l">');
      for (final e in porLinha[l]!) {
        final c = e.value;
        final s = estilo(c.z);
        final attrS = s == 0 ? '' : ' s="$s"';
        switch (c.t) {
          case 's':
            final v = c.v as String;
            if (compartilhadas) {
              final i = idxString.putIfAbsent(v, () {
                strings.add(v);
                return strings.length - 1;
              });
              sb.write('<c r="${e.key}"$attrS t="s"><v>$i</v></c>');
            } else {
              sb.write('<c r="${e.key}"$attrS t="inlineStr"><is><t>${_esc(v)}</t></is></c>');
            }
          case 'b':
            sb.write('<c r="${e.key}" t="b"><v>${c.v == true ? 1 : 0}</v></c>');
          default:
            sb.write('<c r="${e.key}"$attrS><v>${c.v}</v></c>');
        }
      }
      sb.write('</row>');
    }
    sb.write('</sheetData></worksheet>');
    return sb.toString();
  }

  final sheets = [for (final a in abas.values) sheetXml(a)];

  final numFmts = StringBuffer();
  var proximo = 164;
  final idsFormato = <int>[];
  for (final z in formatos) {
    final padrao = formatosPadraoExcel.entries.where((e) => e.value == z).firstOrNull;
    if (padrao != null) {
      idsFormato.add(padrao.key);
    } else {
      final id = customIds.putIfAbsent(z, () => proximo++);
      numFmts.write('<numFmt numFmtId="$id" formatCode="${_esc(z)}"/>');
      idsFormato.add(id);
    }
  }
  final styles = '<?xml version="1.0" encoding="UTF-8"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '${customIds.isEmpty ? '' : '<numFmts count="${customIds.length}">$numFmts</numFmts>'}'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0"/></cellStyleXfs>'
      '<cellXfs count="${idsFormato.length}">${idsFormato.map((id) => '<xf numFmtId="$id" fontId="0" applyNumberFormat="1"/>').join()}</cellXfs>'
      '</styleSheet>';

  final nomes = abas.keys.toList();
  final workbook = '<?xml version="1.0" encoding="UTF-8"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>'
      '${[for (var i = 0; i < nomes.length; i++) '<sheet name="${_esc(nomes[i])}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}'
      '</sheets></workbook>';
  final rels = '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '${[for (var i = 0; i < nomes.length; i++) '<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>'].join()}'
      '<Relationship Id="rId90" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '<Relationship Id="rId91" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>'
      '</Relationships>';
  final sst = '<?xml version="1.0" encoding="UTF-8"?><sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="${strings.length}" uniqueCount="${strings.length}">'
      '${strings.map((s) => '<si><t xml:space="preserve">${_esc(s)}</t></si>').join()}</sst>';

  final arquivos = <String, String>{
    '[Content_Types].xml': '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>',
    'xl/workbook.xml': workbook,
    'xl/_rels/workbook.xml.rels': rels,
    'xl/styles.xml': styles,
    'xl/sharedStrings.xml': sst,
    for (var i = 0; i < sheets.length; i++) 'xl/worksheets/sheet${i + 1}.xml': sheets[i],
  };
  return zipDe({for (final e in arquivos.entries) e.key: utf8.encode(e.value)}, comprimir: comprimir);
}

final _tabelaCrc = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> dados) {
  var c = 0xFFFFFFFF;
  for (final b in dados) {
    c = _tabelaCrc[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

/// ZIP mínimo (sem ZIP64) com entradas armazenadas ou DEFLATE.
Uint8List zipDe(Map<String, List<int>> arquivos, {bool comprimir = true}) {
  final saida = BytesBuilder();
  final central = BytesBuilder();
  void u16(BytesBuilder b, int v) => b.add([v & 0xFF, (v >> 8) & 0xFF]);
  void u32(BytesBuilder b, int v) => b.add([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);
  var n = 0;
  for (final e in arquivos.entries) {
    final nome = utf8.encode(e.key);
    final dados = e.value;
    final comp = comprimir ? ZLibEncoder(raw: true).convert(dados) : dados;
    final metodo = comprimir ? 8 : 0;
    final crc = _crc32(dados);
    final offset = saida.length;
    u32(saida, 0x04034b50);
    u16(saida, 20);
    u16(saida, 0);
    u16(saida, metodo);
    u16(saida, 0);
    u16(saida, 0);
    u32(saida, crc);
    u32(saida, comp.length);
    u32(saida, dados.length);
    u16(saida, nome.length);
    u16(saida, 0);
    saida.add(nome);
    saida.add(comp);

    u32(central, 0x02014b50);
    u16(central, 20);
    u16(central, 20);
    u16(central, 0);
    u16(central, metodo);
    u16(central, 0);
    u16(central, 0);
    u32(central, crc);
    u32(central, comp.length);
    u32(central, dados.length);
    u16(central, nome.length);
    u16(central, 0);
    u16(central, 0);
    u16(central, 0);
    u16(central, 0);
    u32(central, 0);
    u32(central, offset);
    central.add(nome);
    n++;
  }
  final inicioCentral = saida.length;
  final tamanhoCentral = central.length;
  saida.add(central.takeBytes());
  u32(saida, 0x06054b50);
  u16(saida, 0);
  u16(saida, 0);
  u16(saida, n);
  u16(saida, n);
  u32(saida, tamanhoCentral);
  u32(saida, inicioCentral);
  u16(saida, 0);
  return saida.takeBytes();
}
