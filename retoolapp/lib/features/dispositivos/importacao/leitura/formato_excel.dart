/// Formatação de números com códigos de formato do Excel (subconjunto do SSF
/// usado pelo SheetJS no desktop). Serve para obter o "texto exibido" de uma
/// célula numérica com formato explícito (`00000`, `0.00`, datas...), que é o
/// que o desktop usa como Código/Dispositivo (preserva zeros à esquerda).
library;

/// `String(n)` do JavaScript: inteiros sem ".0", notação científica só a partir de 1e21.
String numeroParaTextoJs(num v) {
  if (v is int) return v.toString();
  final d = v.toDouble();
  if (d.isNaN) return 'NaN';
  if (d.isInfinite) return d > 0 ? 'Infinity' : '-Infinity';
  if (d == 0) return '0';
  if (d == d.truncateToDouble() && d.abs() < 1e21) return d.toStringAsFixed(0);
  return d.toString(); // menor representação de ida-e-volta, igual ao JS
}

/// Formatos internos do Excel (numFmtId < 164) — mesma tabela do SheetJS.
const formatosPadraoExcel = <int, String>{
  0: 'General',
  1: '0',
  2: '0.00',
  3: '#,##0',
  4: '#,##0.00',
  9: '0%',
  10: '0.00%',
  11: '0.00E+00',
  12: '# ?/?',
  13: '# ??/??',
  14: 'm/d/yy',
  15: 'd-mmm-yy',
  16: 'd-mmm',
  17: 'mmm-yy',
  18: 'h:mm AM/PM',
  19: 'h:mm:ss AM/PM',
  20: 'h:mm',
  21: 'h:mm:ss',
  22: 'm/d/yy h:mm',
  37: '#,##0 ;(#,##0)',
  38: '#,##0 ;[Red](#,##0)',
  39: '#,##0.00;(#,##0.00)',
  40: '#,##0.00;[Red](#,##0.00)',
  45: 'mm:ss',
  46: '[h]:mm:ss',
  47: 'mmss.0',
  48: '##0.0E+0',
  49: '@',
};

/// Texto exibido de [valor] com o código de formato [formato]; `null` quando o
/// formato não é suportado (quem chama usa então o valor completo).
String? formatarNumeroExcel(double valor, String formato) {
  try {
    return _formatar(valor, formato);
  } catch (_) {
    return null;
  }
}

String? _formatar(double v, String formato) {
  if (v.isNaN || v.isInfinite) return null;
  final secoes = _dividirSecoes(formato);
  if (secoes.isEmpty) return numeroParaTextoJs(v);
  String secao;
  var sinalAutomatico = false;
  var x = v;
  if (secoes.length == 1) {
    secao = secoes[0];
    if (v < 0) {
      sinalAutomatico = true;
      x = -v;
    }
  } else if (v < 0) {
    secao = secoes[1];
    x = -v;
  } else if (v == 0 && secoes.length >= 3) {
    secao = secoes[2];
  } else {
    secao = secoes[0];
  }

  final tokens = _cacheTokens.putIfAbsent(secao, () => _tokenizar(secao));
  if (tokens == null) return null;
  final String? corpo;
  if (tokens.any((t) => t.tipo == _T.geral)) {
    corpo = _montarGeral(tokens, x);
  } else if (tokens.any((t) => t.tipo == _T.data)) {
    if (sinalAutomatico) return null; // datas negativas não existem no Excel
    corpo = _formatarData(tokens, x);
  } else {
    corpo = _formatarNumero(tokens, x);
  }
  if (corpo == null) return null;
  return sinalAutomatico ? '-$corpo' : corpo;
}

/// Formatos se repetem em milhares de células (ex.: coluna Peso "0.00"): tokeniza uma vez só.
final _cacheTokens = <String, List<_Tok>?>{};
final _cacheSecoes = <String, List<String>>{};

List<String> _dividirSecoes(String f) => _cacheSecoes.putIfAbsent(f, () => _dividir(f));

List<String> _dividir(String f) {
  final secoes = <String>[];
  final atual = StringBuffer();
  var aspas = false, colchete = false;
  for (var i = 0; i < f.length; i++) {
    final c = f[i];
    if (!aspas && !colchete && c == r'\' && i + 1 < f.length) {
      atual
        ..write(c)
        ..write(f[++i]);
      continue;
    }
    if (c == '"' && !colchete) aspas = !aspas;
    if (!aspas && c == '[') colchete = true;
    if (!aspas && c == ']') colchete = false;
    if (c == ';' && !aspas && !colchete) {
      secoes.add(atual.toString());
      atual.clear();
      continue;
    }
    atual.write(c);
  }
  secoes.add(atual.toString());
  return secoes;
}

enum _T { literal, d0, dSus, dInt, ponto, virgula, pct, exp, texto, geral, data }

class _Tok {
  final _T tipo;
  final String texto;
  const _Tok(this.tipo, [this.texto = '']);
  bool get digito => tipo == _T.d0 || tipo == _T.dSus || tipo == _T.dInt;
}

bool _pareceData(String s) {
  var aspas = false;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c == r'\' || c == '_' || c == '*') {
      i++;
      continue;
    }
    if (c == '"') {
      aspas = !aspas;
      continue;
    }
    if (aspas) continue;
    if (c == '[') {
      final fim = s.indexOf(']', i);
      if (fim < 0) return false;
      final dentro = s.substring(i + 1, fim).toLowerCase();
      if (RegExp(r'^(h+|m+|s+)$').hasMatch(dentro)) return true;
      i = fim;
      continue;
    }
    if ('yYmMdDhHsS'.contains(c)) return true;
  }
  return false;
}

List<_Tok>? _tokenizar(String s) {
  final data = _pareceData(s);
  final tokens = <_Tok>[];
  void lit(String t) => tokens.add(_Tok(_T.literal, t));
  var i = 0;
  while (i < s.length) {
    final c = s[i];
    if (c == '"') {
      final fim = s.indexOf('"', i + 1);
      if (fim < 0) return null;
      lit(s.substring(i + 1, fim));
      i = fim + 1;
      continue;
    }
    if (c == r'\') {
      if (i + 1 < s.length) lit(s[i + 1]);
      i += 2;
      continue;
    }
    if (c == '_') {
      lit(' ');
      i += 2;
      continue;
    }
    if (c == '*') {
      i += 2;
      continue;
    }
    if (c == '[') {
      final fim = s.indexOf(']', i);
      if (fim < 0) return null;
      final dentro = s.substring(i + 1, fim);
      if (dentro.startsWith(r'$')) {
        final traco = dentro.indexOf('-');
        lit(traco < 0 ? dentro.substring(1) : dentro.substring(1, traco));
      } else if (RegExp(r'^(h+|m+|s+)$', caseSensitive: false).hasMatch(dentro)) {
        tokens.add(_Tok(_T.data, '[${dentro.toLowerCase()}]'));
      }
      // Cores ([Red]) e condições ([>=100]) não alteram o texto.
      i = fim + 1;
      continue;
    }
    if (s.length - i >= 7 && s.substring(i, i + 7).toLowerCase() == 'general') {
      tokens.add(const _Tok(_T.geral));
      i += 7;
      continue;
    }
    if (c == '@') {
      tokens.add(const _Tok(_T.texto));
      i++;
      continue;
    }
    if (data) {
      final resto = s.substring(i);
      final ampm = RegExp(r'^(AM/PM|am/pm|A/P|a/p)').firstMatch(resto);
      if (ampm != null) {
        tokens.add(_Tok(_T.data, ampm.group(0)!.toUpperCase()));
        i += ampm.group(0)!.length;
        continue;
      }
      final l = c.toLowerCase();
      if ('ymdhs'.contains(l)) {
        var j = i;
        while (j < s.length && s[j].toLowerCase() == l) {
          j++;
        }
        tokens.add(_Tok(_T.data, l * (j - i)));
        i = j;
        continue;
      }
      if (c == '.' && i + 1 < s.length && s[i + 1] == '0') {
        var j = i + 1;
        while (j < s.length && s[j] == '0') {
          j++;
        }
        tokens.add(_Tok(_T.data, s.substring(i, j)));
        i = j;
        continue;
      }
      lit(c);
      i++;
      continue;
    }
    switch (c) {
      case '0':
        tokens.add(const _Tok(_T.d0));
      case '#':
        tokens.add(const _Tok(_T.dInt));
      case '?':
        tokens.add(const _Tok(_T.dSus));
      case '.':
        tokens.add(const _Tok(_T.ponto));
      case ',':
        tokens.add(const _Tok(_T.virgula));
      case '%':
        tokens.add(const _Tok(_T.pct));
      case '/':
        return null; // frações ("# ?/?") não suportadas
      case 'E' || 'e' when i + 1 < s.length && (s[i + 1] == '+' || s[i + 1] == '-'):
        tokens.add(_Tok(_T.exp, s[i + 1]));
        i += 2;
        continue;
      default:
        lit(c);
    }
    i++;
  }
  return tokens;
}

String _montarGeral(List<_Tok> tokens, double x) {
  final sb = StringBuffer();
  for (final t in tokens) {
    if (t.tipo == _T.geral || t.tipo == _T.texto) {
      sb.write(numeroParaTextoJs(x));
    } else if (t.tipo == _T.literal) {
      sb.write(t.texto);
    }
  }
  return sb.toString();
}

String _agrupar(String digitos) {
  final sb = StringBuffer();
  for (var i = 0; i < digitos.length; i++) {
    if (i > 0 && (digitos.length - i) % 3 == 0) sb.write(',');
    sb.write(digitos[i]);
  }
  return sb.toString();
}

String? _formatarNumero(List<_Tok> tokens, double valor) {
  var x = valor;
  final idxExp = tokens.indexWhere((t) => t.tipo == _T.exp);
  final fimMantissa = idxExp < 0 ? tokens.length : idxExp;
  var idxPonto = -1;
  for (var i = 0; i < fimMantissa; i++) {
    if (tokens[i].tipo == _T.ponto) {
      idxPonto = i;
      break;
    }
  }
  final fimInteiro = idxPonto < 0 ? fimMantissa : idxPonto;

  // Vírgulas: entre dígitos = separador de milhar; depois do último dígito = divide por 1000.
  var agrupar = false;
  final usados = List<bool>.filled(tokens.length, true);
  for (var i = 0; i < fimMantissa; i++) {
    if (tokens[i].tipo != _T.virgula) continue;
    final antes = tokens.sublist(0, i).any((t) => t.digito);
    final depois = tokens.sublist(i + 1, fimMantissa).any((t) => t.digito);
    if (!antes) continue; // vírgula literal antes do número
    usados[i] = false;
    if (!depois) {
      x /= 1000;
    } else if (i < fimInteiro) {
      agrupar = true;
    }
  }
  for (final t in tokens) {
    if (t.tipo == _T.pct) x *= 100;
  }

  final digInt = [for (var i = 0; i < fimInteiro; i++) if (tokens[i].digito) i];
  final digFrac = [for (var i = fimInteiro; i < fimMantissa; i++) if (tokens[i].digito) i];
  final digExp = [for (var i = fimMantissa; i < tokens.length; i++) if (tokens[i].digito) i];

  var expoente = 0;
  if (idxExp >= 0 && x != 0) {
    final casasInt = digInt.isEmpty ? 1 : digInt.length;
    expoente = (_log10(x)).floor() - (casasInt - 1);
    var mant = x / _pot10(expoente);
    final arred = double.parse(mant.toStringAsFixed(digFrac.length));
    if (arred >= _pot10(casasInt)) {
      expoente++;
      mant = x / _pot10(expoente);
    }
    x = mant;
  }

  final fixo = x.toStringAsFixed(digFrac.length);
  if (fixo.contains('e')) return null; // ≥ 1e21: sem representação fixa
  final partes = fixo.split('.');
  var inteiro = partes[0] == '0' ? '' : partes[0];
  final frac = partes.length > 1 ? partes[1] : '';

  final saida = List<String>.filled(tokens.length, '');
  // Parte inteira (preenchida da direita para a esquerda, literais no lugar).
  if (agrupar) {
    final minimo = digInt.where((i) => tokens[i].tipo == _T.d0).length;
    final preenchido = inteiro.padLeft(minimo, '0');
    if (digInt.isNotEmpty) {
      saida[digInt.first] = _agrupar(preenchido);
      for (final i in digInt.skip(1)) {
        saida[i] = '';
      }
    }
  } else {
    var pos = inteiro.length - 1;
    for (var k = digInt.length - 1; k >= 0; k--) {
      final i = digInt[k];
      String ch;
      if (pos >= 0) {
        ch = inteiro[pos--];
      } else {
        ch = switch (tokens[i].tipo) { _T.d0 => '0', _T.dSus => ' ', _ => '' };
      }
      if (k == 0 && pos >= 0) ch = inteiro.substring(0, pos + 1) + ch;
      saida[i] = ch;
    }
  }
  if (digInt.isEmpty && inteiro.isNotEmpty) {
    final ancora = idxPonto >= 0 ? idxPonto : (digFrac.isNotEmpty ? digFrac.first : -1);
    if (ancora < 0) return null;
    saida[ancora] = inteiro + saida[ancora];
  }
  if (idxPonto >= 0) saida[idxPonto] = '${saida[idxPonto]}.';

  // Parte decimal: zeros finais em "#"/"?" somem.
  for (var k = 0; k < digFrac.length; k++) {
    final i = digFrac[k];
    final ch = frac[k];
    final restoZero = frac.substring(k).split('').every((c) => c == '0');
    final tipo = tokens[i].tipo;
    saida[i] = restoZero && tipo != _T.d0 ? (tipo == _T.dSus ? ' ' : '') : ch;
  }

  // Expoente.
  if (idxExp >= 0) {
    final sinal = expoente < 0 ? '-' : (tokens[idxExp].texto == '+' ? '+' : '');
    saida[idxExp] = 'E$sinal';
    final e = expoente.abs().toString().padLeft(digExp.where((i) => tokens[i].tipo == _T.d0).length, '0');
    for (var k = 0; k < digExp.length; k++) {
      saida[digExp[k]] = k == digExp.length - 1 ? e : '';
    }
    if (digExp.isEmpty) saida[idxExp] += e;
  }

  final sb = StringBuffer();
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    switch (t.tipo) {
      case _T.literal:
        sb.write(t.texto);
      case _T.pct:
        sb.write('%');
      case _T.texto:
        sb.write(numeroParaTextoJs(valor.abs()));
      case _T.virgula:
        if (usados[i]) sb.write(',');
      default:
        sb.write(saida[i]);
    }
  }
  return sb.toString();
}

double _log10(double x) {
  // log10 sem dart:math para manter o arquivo leve; precisão suficiente para expoentes.
  var e = 0;
  var y = x;
  while (y >= 10) {
    y /= 10;
    e++;
  }
  while (y < 1) {
    y *= 10;
    e--;
  }
  return e.toDouble();
}

double _pot10(int e) {
  var r = 1.0;
  if (e >= 0) {
    for (var i = 0; i < e; i++) {
      r *= 10;
    }
  } else {
    for (var i = 0; i < -e; i++) {
      r /= 10;
    }
  }
  return r;
}

const _meses = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _dias = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// Data do Excel (sistema 1900, com o falso 29/02/1900) a partir do número de série.
DateTime dataDoSerialExcel(double serial) {
  final dias = serial.floor();
  final base = dias < 61 ? DateTime.utc(1899, 12, 31) : DateTime.utc(1899, 12, 30);
  final ms = ((serial - dias) * 86400000).round();
  return base.add(Duration(days: dias, milliseconds: ms));
}

String? _formatarData(List<_Tok> tokens, double serial) {
  if (serial < 0) return null;
  var d = dataDoSerialExcel(serial);
  final temFracao = tokens.any((t) => t.tipo == _T.data && t.texto.startsWith('.'));
  if (!temFracao) d = DateTime.fromMillisecondsSinceEpoch(((d.millisecondsSinceEpoch + 500) ~/ 1000) * 1000, isUtc: true);
  final ampm = tokens.any((t) => t.tipo == _T.data && (t.texto == 'AM/PM' || t.texto == 'A/P'));
  String dois(int n) => n.toString().padLeft(2, '0');

  // "m" vira minuto quando vem logo após hora ou antes de segundo.
  final datas = [for (var i = 0; i < tokens.length; i++) if (tokens[i].tipo == _T.data) i];
  bool ehMinuto(int pos) {
    final k = datas.indexOf(pos);
    final antes = k > 0 ? tokens[datas[k - 1]].texto : '';
    final depois = k + 1 < datas.length ? tokens[datas[k + 1]].texto : '';
    return antes.startsWith('h') || antes.startsWith('[h') || depois.startsWith('s') || depois.startsWith('[s');
  }

  final sb = StringBuffer();
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    if (t.tipo == _T.literal) {
      sb.write(t.texto);
      continue;
    }
    if (t.tipo != _T.data) {
      if (t.tipo == _T.texto) sb.write(numeroParaTextoJs(serial));
      continue;
    }
    final s = t.texto;
    final hora12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final h = ampm ? hora12 : d.hour;
    switch (s) {
      case 'AM/PM':
        sb.write(d.hour < 12 ? 'AM' : 'PM');
      case 'A/P':
        sb.write(d.hour < 12 ? 'A' : 'P');
      case '[h]' || '[hh]':
        sb.write((serial * 24).floor().toString().padLeft(s.length - 2, '0'));
      case '[m]' || '[mm]':
        sb.write((serial * 1440).floor().toString().padLeft(s.length - 2, '0'));
      case '[s]' || '[ss]':
        sb.write((serial * 86400).round().toString().padLeft(s.length - 2, '0'));
      default:
        if (s.startsWith('.')) {
          final casas = s.length - 1;
          final fr = (d.millisecond / 1000).toStringAsFixed(casas);
          sb.write(fr.substring(fr.indexOf('.')));
        } else if (s.startsWith('y')) {
          sb.write(s.length <= 2 ? dois(d.year % 100) : d.year.toString());
        } else if (s.startsWith('m')) {
          if (s.length <= 2 && ehMinuto(i)) {
            sb.write(s.length == 2 ? dois(d.minute) : d.minute.toString());
          } else {
            sb.write(switch (s.length) {
              1 => d.month.toString(),
              2 => dois(d.month),
              3 => _meses[d.month - 1].substring(0, 3),
              4 => _meses[d.month - 1],
              _ => _meses[d.month - 1][0],
            });
          }
        } else if (s.startsWith('d')) {
          sb.write(switch (s.length) {
            1 => d.day.toString(),
            2 => dois(d.day),
            3 => _dias[d.weekday - 1].substring(0, 3),
            _ => _dias[d.weekday - 1],
          });
        } else if (s.startsWith('h')) {
          sb.write(s.length >= 2 ? dois(h) : h.toString());
        } else if (s.startsWith('s')) {
          sb.write(s.length >= 2 ? dois(d.second) : d.second.toString());
        }
    }
  }
  return sb.toString();
}
