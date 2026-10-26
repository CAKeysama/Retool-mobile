import 'dart:typed_data';

import 'erros.dart';

/// Plataformas sem `dart:io` (web): não há zlib nativo para abrir o .xlsx.
Uint8List inflarDeflate(Uint8List dados) => throw const ErroLeituraPlanilha(
    'A leitura de arquivos .xlsx não está disponível nesta plataforma. Salve a planilha como .csv e tente novamente.');
