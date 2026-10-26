import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../../domain/services/file_validators.dart';

/// Arquivo escolhido pelo usuário, já em memória, pronto para validar e enviar.
class ArquivoEscolhido {
  final String nome;
  final Uint8List bytes;
  final String contentType;

  ArquivoEscolhido({required this.nome, required this.bytes, String? contentType})
    : contentType = (contentType == null || contentType.isEmpty) ? contentTypeDoNome(nome) : contentType;

  int get tamanho => bytes.length;
}

enum OrigemImagem { camera, galeria }

/// Escolha de arquivos isolada da UI (pickers nativos não rodam nos testes).
abstract class SeletorArquivos {
  Future<ArquivoEscolhido?> escolherImagem(OrigemImagem origem);
  Future<List<ArquivoEscolhido>> escolherPdfs();
}

/// Implementação real: `image_picker` (câmera/galeria) e `file_picker` (PDFs).
class SeletorArquivosNativo implements SeletorArquivos {
  final ImagePicker _imagens;
  SeletorArquivosNativo({ImagePicker? imagens}) : _imagens = imagens ?? ImagePicker();

  @override
  Future<ArquivoEscolhido?> escolherImagem(OrigemImagem origem) async {
    // Reduz fotos da câmera (dezenas de MB) para um tamanho de envio rápido.
    final x = await _imagens.pickImage(
      source: origem == OrigemImagem.camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 2560,
      maxHeight: 2560,
      imageQuality: 85,
    );
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    final tipoPeloNome = contentTypeDoNome(x.name);
    return ArquivoEscolhido(
      nome: x.name,
      bytes: bytes,
      contentType: tipoPeloNome != 'application/octet-stream' ? tipoPeloNome : x.mimeType,
    );
  }

  @override
  Future<List<ArquivoEscolhido>> escolherPdfs() async {
    final arquivos = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf']);
    final escolhidos = <ArquivoEscolhido>[];
    for (final f in arquivos) {
      escolhidos.add(ArquivoEscolhido(nome: f.name, bytes: await f.readAsBytes()));
    }
    return escolhidos;
  }
}

/// Seletor usado pelo formulário quando nenhum é injetado. Os testes trocam por um fake.
SeletorArquivos seletorArquivosPadrao = SeletorArquivosNativo();
