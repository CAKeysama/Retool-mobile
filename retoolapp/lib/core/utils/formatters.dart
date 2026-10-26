import 'package:intl/intl.dart';

final _dataHora = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
final _data = DateFormat('dd/MM/yyyy', 'pt_BR');
final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
final _numero = NumberFormat.decimalPattern('pt_BR');

DateTime? _parse(String? iso) => (iso == null || iso.isEmpty) ? null : DateTime.tryParse(iso)?.toLocal();

/// `dd/MM/yyyy HH:mm` (equivale a `toLocaleString('pt-BR', short)` do desktop); '—' se inválida.
String formatarDataHora(String? iso) {
  final d = _parse(iso);
  return d == null ? '—' : _dataHora.format(d);
}

/// `dd/MM/yyyy`. Aceita ISO completo ou `yyyy-MM-dd` (campo `data` das reutilizações).
String formatarData(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  // Datas puras (yyyy-MM-dd) não sofrem ajuste de fuso.
  final pura = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(iso);
  final d = pura ? DateTime.tryParse(iso) : _parse(iso);
  return d == null ? '—' : _data.format(d);
}

/// Tempo relativo curto ("agora", "há 5 min", "há 2 h", "há 3 d") para notificações.
String formatarRelativo(String? iso, {DateTime? agora}) {
  final d = _parse(iso);
  if (d == null) return '—';
  final diff = (agora ?? DateTime.now()).difference(d);
  if (diff.inMinutes < 1) return 'agora';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'há ${diff.inHours} h';
  if (diff.inDays < 30) return 'há ${diff.inDays} d';
  return _data.format(d);
}

String formatarMoeda(num? valor) => _moeda.format(valor ?? 0);

String formatarNumero(num? valor) => _numero.format(valor ?? 0);

/// Peso com sufixo kg; vazio = "Não informado" (Open World Assumption).
String formatarPeso(Object? peso) {
  if (peso == null) return 'Não informado';
  final texto = peso.toString().trim();
  if (texto.isEmpty) return 'Não informado';
  return texto.toLowerCase().contains('kg') ? texto : '$texto kg';
}

/// Fallback amigável para campos opcionais.
String ouNaoInformado(String? valor) => (valor == null || valor.trim().isEmpty) ? 'Não informado' : valor;
