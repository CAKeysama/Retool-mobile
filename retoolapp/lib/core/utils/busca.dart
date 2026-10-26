import '../../domain/entities/classificacao.dart';

/// Normalização de busca do desktop: sem acentos, minúsculas, vírgula decimal
/// vira ponto e o erro de digitação fabril "avula" equivale a "avola".
String normalizarBusca(String? s) {
  if (s == null || s.isEmpty) return '';
  var r = removerAcentos(s).toLowerCase().replaceAll(',', '.');
  if (r.contains('avula')) r = r.replaceAll('avula', 'avola');
  return r;
}
