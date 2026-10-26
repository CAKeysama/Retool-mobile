import '../entities/file_attachment.dart';

const int maxImageSizeBytes = 10 * 1024 * 1024; // 10MB
const int maxDocumentSizeBytes = 25 * 1024 * 1024; // 25MB

const List<String> allowedImageTypes = ['image/jpeg', 'image/png', 'image/webp'];
const List<String> allowedDocumentTypes = ['application/pdf'];

/// Tipo MIME a partir da extensão (o picker do Android nem sempre informa o MIME).
String contentTypeDoNome(String nome) {
  final ext = nome.contains('.') ? nome.split('.').last.toLowerCase() : '';
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'pdf':
      return 'application/pdf';
    default:
      return 'application/octet-stream';
  }
}

/// Valida tipo e tamanho; retorna a mensagem de erro ou null (mesmas regras do storage.rules).
String? validarArquivo({required String contentType, required int size, required CategoriaAnexo categoria}) {
  if (categoria.isImagem) {
    if (!allowedImageTypes.contains(contentType)) {
      return 'Formato de imagem inválido (${contentType.isEmpty ? 'desconhecido' : contentType}). Formatos suportados: JPG, PNG e WEBP.';
    }
    if (size > maxImageSizeBytes) {
      return 'O tamanho da imagem (${formatFileSize(size)}) excede o limite máximo permitido de ${formatFileSize(maxImageSizeBytes)}.';
    }
  } else {
    if (!allowedDocumentTypes.contains(contentType)) {
      return 'Formato de documento inválido. Apenas documentos no formato PDF são aceitos.';
    }
    if (size > maxDocumentSizeBytes) {
      return 'O tamanho do documento (${formatFileSize(size)}) excede o limite máximo de ${formatFileSize(maxDocumentSizeBytes)}.';
    }
  }
  return null;
}

/// Remove acentos, troca espaços por `_` e mantém apenas `[a-zA-Z0-9._-]`.
String sanitizeFileName(String original) {
  const mapa = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ç': 'c', 'ñ': 'n',
    'Á': 'A', 'À': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A', 'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E',
    'Í': 'I', 'Ì': 'I', 'Î': 'I', 'Ï': 'I', 'Ó': 'O', 'Ò': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O',
    'Ú': 'U', 'Ù': 'U', 'Û': 'U', 'Ü': 'U', 'Ç': 'C', 'Ñ': 'N',
  };
  final semAcento = original.split('').map((c) => mapa[c] ?? c).join();
  final limpo = semAcento.replaceAll(RegExp(r'\s+'), '_').replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '');
  return limpo.isEmpty ? 'arquivo' : limpo;
}

String formatFileSize(int bytes) {
  if (bytes <= 0) return '0 B';
  const sizes = ['B', 'KB', 'MB', 'GB'];
  var i = 0;
  var valor = bytes.toDouble();
  while (valor >= 1024 && i < sizes.length - 1) {
    valor /= 1024;
    i++;
  }
  final arredondado = double.parse(valor.toStringAsFixed(1));
  final texto = arredondado == arredondado.truncateToDouble()
      ? arredondado.toInt().toString()
      : arredondado.toString();
  return '$texto ${sizes[i]}';
}
