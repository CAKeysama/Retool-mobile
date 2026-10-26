enum CategoriaAnexo {
  imagemPeca('imagem_peca'),
  imagemDispositivo('imagem_dispositivo'),
  documentoPdf('documento_pdf');

  final String valor;
  const CategoriaAnexo(this.valor);

  static CategoriaAnexo fromValor(String? v) =>
      CategoriaAnexo.values.firstWhere((c) => c.valor == v, orElse: () => CategoriaAnexo.documentoPdf);

  bool get isImagem => this != CategoriaAnexo.documentoPdf;
}

class FileAttachment {
  final String id;
  final String originalName;
  final String fileName;
  final String contentType;
  final int size;
  final String storagePath;
  final String downloadURL;
  final String uploadedAt;
  final CategoriaAnexo categoria;

  const FileAttachment({
    required this.id,
    required this.originalName,
    required this.fileName,
    required this.contentType,
    required this.size,
    required this.storagePath,
    required this.downloadURL,
    required this.uploadedAt,
    required this.categoria,
  });

  factory FileAttachment.fromMap(Map<String, dynamic> m) => FileAttachment(
        id: (m['id'] ?? '').toString(),
        originalName: (m['originalName'] ?? '').toString(),
        fileName: (m['fileName'] ?? '').toString(),
        contentType: (m['contentType'] ?? '').toString(),
        size: (m['size'] is num) ? (m['size'] as num).toInt() : 0,
        storagePath: (m['storagePath'] ?? '').toString(),
        downloadURL: (m['downloadURL'] ?? '').toString(),
        uploadedAt: (m['uploadedAt'] ?? '').toString(),
        categoria: CategoriaAnexo.fromValor(m['categoria'] as String?),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'originalName': originalName,
        'fileName': fileName,
        'contentType': contentType,
        'size': size,
        'storagePath': storagePath,
        'downloadURL': downloadURL,
        'uploadedAt': uploadedAt,
        'categoria': categoria.valor,
      };
}
