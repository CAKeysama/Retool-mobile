import 'dart:convert';
import 'dart:typed_data';

import 'celulas.dart';

/// Windows-1252 nos bytes 0x80–0x9F (o resto coincide com Latin-1).
const _cp1252 = <int>[
  0x20AC, 0x81, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x8D, 0x017D, 0x8F,
  0x90, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, 0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x9D, 0x017E, 0x0178,
];

/// Decodifica um CSV: UTF-8 (com ou sem BOM) e, se os bytes não forem UTF-8
/// válido, Windows-1252 (padrão do Excel pt-BR em "CSV separado por vírgulas").
String decodificarTexto(Uint8List bytes) {
  try {
    final s = utf8.decode(bytes);
    return s.startsWith('﻿') ? s.substring(1) : s;
  } on FormatException {
    final codigos = List<int>.generate(bytes.length, (i) {
      final b = bytes[i];
      return b >= 0x80 && b <= 0x9F ? _cp1252[b - 0x80] : b;
    });
    return String.fromCharCodes(codigos);
  }
}

/// Separador como o SheetJS adivinha: o mais frequente (fora de aspas) entre
/// `,` `\t` `;` `|` nos primeiros 1024 caracteres; empate favorece a vírgula.
String adivinharSeparador(String texto) {
  const pesos = {',': 3, '\t': 2, ';': 1, '|': 0};
  final cont = <String, int>{};
  var aspas = false;
  final fim = texto.length < 1024 ? texto.length : 1024;
  for (var i = 0; i < fim; i++) {
    final c = texto[i];
    if (c == '"') {
      aspas = !aspas;
    } else if (!aspas && pesos.containsKey(c)) {
      cont[c] = (cont[c] ?? 0) + 1;
    }
  }
  if (cont.isEmpty) return ',';
  final ordenado = cont.entries.toList()
    ..sort((a, b) => a.value != b.value ? a.value - b.value : pesos[a.key]! - pesos[b.key]!);
  return ordenado.last.key;
}

/// Lê o CSV como texto puro (como `raw: true` do desktop): "0041" continua "0041".
List<AbaBruta> lerCsv(Uint8List bytes) {
  var texto = decodificarTexto(bytes);
  String sep;
  // Diretiva "sep=;" do Excel na primeira linha.
  final diretiva = RegExp(r'^sep=(.)\r?\n?').firstMatch(texto);
  if (diretiva != null) {
    sep = diretiva.group(1)!;
    texto = texto.substring(diretiva.end);
  } else {
    sep = adivinharSeparador(texto);
  }

  final linhas = <LinhaBruta>[];
  var r = 0, c = 0;
  LinhaBruta? linha;
  final campo = StringBuffer();
  var aspas = false;

  void fecharCampo() {
    if (campo.isNotEmpty) {
      if (linha == null || linha!.r != r) {
        linha = LinhaBruta(r);
        linhas.add(linha!);
      }
      linha!.colunas.add(c);
      linha!.valores.add(campo.toString());
      campo.clear();
    }
    c++;
  }

  void fecharLinha() {
    fecharCampo();
    r++;
    c = 0;
  }

  final n = texto.length;
  var i = 0;
  while (i < n) {
    final ch = texto[i];
    if (aspas) {
      if (ch == '"') {
        if (i + 1 < n && texto[i + 1] == '"') {
          campo.write('"');
          i += 2;
          continue;
        }
        aspas = false;
      } else {
        campo.write(ch);
      }
      i++;
      continue;
    }
    if (ch == '"') {
      aspas = true;
    } else if (ch == sep) {
      fecharCampo();
    } else if (ch == '\r') {
      fecharLinha();
      if (i + 1 < n && texto[i + 1] == '\n') i++;
    } else if (ch == '\n') {
      fecharLinha();
    } else {
      campo.write(ch);
    }
    i++;
  }
  if (campo.isNotEmpty || c > 0) fecharLinha();
  return [AbaBruta('Sheet1', linhas)];
}
