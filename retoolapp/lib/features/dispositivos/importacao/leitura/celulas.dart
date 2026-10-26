import 'formato_excel.dart';

/// Célula numérica lida: o texto exibido (usado para Código, Dispositivo e
/// demais textos) e o valor bruto (usado no Peso, para que um formato "0.00"
/// não arredonde o peso gravado). Células de texto são `String`.
class CelulaNumero {
  final String texto;
  final double numero;
  const CelulaNumero(this.texto, this.numero);

  @override
  bool operator ==(Object other) => other is CelulaNumero && other.texto == texto && other.numero == numero;

  @override
  int get hashCode => Object.hash(texto, numero);

  @override
  String toString() => 'CelulaNumero($texto, $numero)';
}

/// `String` ou [CelulaNumero].
typedef CelulaPlanilha = Object;

/// Texto de uma célula já lida (`textoCelula` do desktop).
String textoCelula(Object? c) => c == null ? '' : (c is CelulaNumero ? c.texto : c.toString());

/// Célula do .xlsx no mesmo modelo do SheetJS (`t`, `v`, `z` formato, `w` texto formatado).
class CelulaXlsx {
  final String t;
  final Object? v;
  final String? z;
  final String? w;
  const CelulaXlsx(this.t, {this.v, this.z, this.w});
}

/// Texto de uma célula como o usuário o vê, sem perder informação (porte de
/// `textoDaCelula` do desktop):
/// - número com formato explícito ("00000", "0.00", data) → texto formatado
///   (preserva zeros à esquerda e casas decimais exibidos);
/// - número em formato Geral → valor completo (o texto do Geral abrevia
///   códigos longos para "5.04001E+13", o que colidiria códigos);
/// - texto → como está.
String textoDaCelula(CelulaXlsx? cell) {
  if (cell == null || cell.v == null) return '';
  final v = cell.v!;
  switch (cell.t) {
    case 'n':
      final numero = v is num ? v.toDouble() : double.tryParse(v.toString());
      if (numero == null) return v.toString();
      final formato = cell.z ?? 'General';
      if (formato == 'General' || formato == '@') return numeroParaTextoJs(numero);
      final w = cell.w ?? formatarNumeroExcel(numero, formato);
      return w ?? numeroParaTextoJs(numero);
    case 'e':
      return cell.w ?? '';
    case 'd':
      return cell.w ?? (v is DateTime ? v.toUtc().toIso8601String() : v.toString());
    case 'b':
      return cell.w ?? v.toString();
    default:
      return v.toString();
  }
}

/// Linha esparsa como está no arquivo: só as células com valor.
class LinhaBruta {
  final int r;
  final List<int> colunas = [];
  final List<CelulaPlanilha> valores = [];
  LinhaBruta(this.r);
}

class AbaBruta {
  final String nome;
  final List<LinhaBruta> linhas;
  const AbaBruta(this.nome, this.linhas);
}
