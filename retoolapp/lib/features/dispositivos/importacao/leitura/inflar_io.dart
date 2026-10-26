import 'dart:io' show ZLibDecoder;
import 'dart:typed_data';

/// Descompacta DEFLATE "cru" (entradas ZIP do .xlsx) com o zlib nativo da plataforma.
Uint8List inflarDeflate(Uint8List dados) => Uint8List.fromList(ZLibDecoder(raw: true).convert(dados));
