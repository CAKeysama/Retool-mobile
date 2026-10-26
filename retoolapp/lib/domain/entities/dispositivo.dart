import 'dart:convert';

import 'file_attachment.dart';

class Dispositivo {
  final String id;
  final String? nome;
  final String? codigo;
  final String? categoriaId;
  final String? peso;
  final String? familiaId;
  final String? descricao;
  final String? observacoes;
  final String? produtoId;
  final List<String> palavrasChave;
  final String? imagemPeca;
  final String? imagemDispositivo;
  final List<FileAttachment> anexos;
  final String? dataCriacao;

  /// Ausente no acervo legado = ativo.
  final bool ativo;

  const Dispositivo({
    required this.id,
    this.nome,
    this.codigo,
    this.categoriaId,
    this.peso,
    this.familiaId,
    this.descricao,
    this.observacoes,
    this.produtoId,
    this.palavrasChave = const [],
    this.imagemPeca,
    this.imagemDispositivo,
    this.anexos = const [],
    this.dataCriacao,
    this.ativo = true,
  });

  factory Dispositivo.fromMap(String id, Map<String, dynamic> m) => Dispositivo(
        id: id,
        nome: _str(m['nome']),
        codigo: _str(m['codigo']),
        categoriaId: _str(m['categoriaId']),
        peso: _str(m['peso']),
        familiaId: _str(m['familiaId']),
        descricao: _str(m['descricao']),
        observacoes: _str(m['observacoes']),
        produtoId: _str(m['produtoId']),
        palavrasChave: (m['palavrasChave'] is List)
            ? (m['palavrasChave'] as List).map((e) => e.toString()).toList()
            : const [],
        imagemPeca: _str(m['imagemPeca']),
        imagemDispositivo: _str(m['imagemDispositivo']),
        anexos: (m['anexos'] is List)
            ? (m['anexos'] as List)
                .whereType<Map>()
                .map((e) => FileAttachment.fromMap(Map<String, dynamic>.from(e)))
                .toList()
            : const [],
        dataCriacao: _str(m['dataCriacao']),
        ativo: m['ativo'] != false,
      );

  /// Mapa completo para criação (sem chaves nulas).
  Map<String, dynamic> toMap() => Map.fromEntries({
        'id': id,
        'nome': nome,
        'codigo': codigo,
        'categoriaId': categoriaId,
        'peso': peso,
        'familiaId': familiaId,
        'descricao': descricao,
        'observacoes': observacoes,
        'produtoId': produtoId,
        'palavrasChave': palavrasChave,
        'imagemPeca': imagemPeca,
        'imagemDispositivo': imagemDispositivo,
        'anexos': anexos.map((a) => a.toMap()).toList(),
        'dataCriacao': dataCriacao,
        'ativo': ativo,
      }.entries.where((e) => e.value != null));

  /// Valor de um campo de imagem pelo nome usado no Firestore.
  String? imagem(CampoImagemDispositivo campo) =>
      campo == CampoImagemDispositivo.imagemPeca ? imagemPeca : imagemDispositivo;

  /// Primeira imagem disponível (miniaturas de listas).
  String? get imagemCapa =>
      (imagemDispositivo?.isNotEmpty ?? false) ? imagemDispositivo : ((imagemPeca?.isNotEmpty ?? false) ? imagemPeca : null);

  Dispositivo copyWith({
    String? nome,
    String? codigo,
    String? categoriaId,
    String? peso,
    String? familiaId,
    String? descricao,
    String? observacoes,
    String? produtoId,
    List<String>? palavrasChave,
    String? imagemPeca,
    String? imagemDispositivo,
    List<FileAttachment>? anexos,
    bool? ativo,
  }) =>
      Dispositivo(
        id: id,
        nome: nome ?? this.nome,
        codigo: codigo ?? this.codigo,
        categoriaId: categoriaId ?? this.categoriaId,
        peso: peso ?? this.peso,
        familiaId: familiaId ?? this.familiaId,
        descricao: descricao ?? this.descricao,
        observacoes: observacoes ?? this.observacoes,
        produtoId: produtoId ?? this.produtoId,
        palavrasChave: palavrasChave ?? this.palavrasChave,
        imagemPeca: imagemPeca ?? this.imagemPeca,
        imagemDispositivo: imagemDispositivo ?? this.imagemDispositivo,
        anexos: anexos ?? this.anexos,
        dataCriacao: dataCriacao,
        ativo: ativo ?? this.ativo,
      );
}

String? _str(Object? v) {
  if (v == null) return null;
  if (v is String) return v;
  return v.toString();
}

enum CampoImagemDispositivo {
  imagemPeca('imagemPeca'),
  imagemDispositivo('imagemDispositivo');

  final String campo;
  const CampoImagemDispositivo(this.campo);
}

/// Normaliza o Número da Peça usado como chave da linha (ignora caixa e espaços).
String normalizarNumeroPeca(String? codigo) => (codigo ?? '').trim().toLowerCase();

// Caracteres invisíveis comuns em planilhas: zero-width (U+200B–U+200D),
// BOM/ZWNBSP (U+FEFF), soft hyphen (U+00AD), word joiner (U+2060) e controles C0/C1.
final _invisiveis = RegExp('[​-‍﻿­⁠\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F]');
final _espacos = RegExp(r'\s+');

/// Normaliza um valor de Código ou Dispositivo para compor a chave de unicidade
/// (mesmo critério do desktop: ignora invisíveis, espaços repetidos e caixa;
/// preserva zeros à esquerda, casas decimais e acentuação).
String normalizarValorChave(Object? valor) {
  if (valor == null) return '';
  var s = comporNfcBasico(valor.toString());
  // Inteiros vindos de planilha como double (123.0) equivalem ao texto "123".
  if (valor is double && valor == valor.truncateToDouble()) s = valor.toInt().toString();
  return s.replaceAll(_invisiveis, '').replaceAll(_espacos, ' ').trim().toLowerCase();
}

// Marca combinante -> (letra base -> letra composta), para o alfabeto do pt-BR.
const _composicoes = <int, String>{
  0x0300: 'aàeèiìoòuùAÀEÈIÌOÒUÙ',
  0x0301: 'aáeéiíoóuúAÁEÉIÍOÓUÚ',
  0x0302: 'aâeêiîoôuûAÂEÊIÎOÔUÛ',
  0x0303: 'aãoõnñAÃOÕNÑ',
  0x0308: 'aäeëiïoöuüAÄEËIÏOÖUÜ',
  0x0327: 'cçCÇ',
};
final _combinante = RegExp('[̧̀́̂̃̈]');

/// Equivalente ao `normalize('NFC')` do desktop para letras acentuadas do pt-BR
/// (texto decomposto vindo de planilhas casa com o mesmo texto já gravado).
String comporNfcBasico(String s) {
  if (!_combinante.hasMatch(s)) return s;
  final runas = s.runes.toList();
  final sb = StringBuffer();
  for (var i = 0; i < runas.length; i++) {
    final base = String.fromCharCode(runas[i]);
    if (i + 1 < runas.length) {
      final pares = _composicoes[runas[i + 1]];
      final idx = pares == null ? -1 : _indiceBase(pares, base);
      if (idx >= 0) {
        sb.write(pares![idx + 1]);
        i++;
        continue;
      }
    }
    sb.write(base);
  }
  return sb.toString();
}

int _indiceBase(String pares, String base) {
  for (var i = 0; i < pares.length; i += 2) {
    if (pares[i] == base) return i;
  }
  return -1;
}

/// Identidade lógica: Código + Dispositivo (`nome`), serializada como tupla JSON.
String chaveCodigoDispositivo(Object? codigo, Object? nome) =>
    jsonEncode([normalizarValorChave(codigo), normalizarValorChave(nome)]);

class PatchPropagacaoImagem {
  final String id;
  final Map<String, String> patch;

  /// 'propagacao' = upload preencheu célula vazia; 'heranca' = registro novo herdou imagem.
  final String origem;
  const PatchPropagacaoImagem({required this.id, required this.patch, required this.origem});
}

/// Propagação automática de imagens por Número da Peça (ver PROPAGACAO_IMAGENS.md do desktop).
List<PatchPropagacaoImagem> calcularPropagacaoImagens(
  List<Dispositivo> linha,
  String origemId,
  String? codigoOrigem,
  Map<String, Object?> payload,
  bool isNew,
) {
  final chave = normalizarNumeroPeca(codigoOrigem);
  if (chave.isEmpty) return const [];
  final mesmaLinha = linha.where((d) => normalizarNumeroPeca(d.codigo) == chave).toList();
  final resultados = <PatchPropagacaoImagem>[];

  for (final campo in CampoImagemDispositivo.values) {
    final novaImagem = payload[campo.campo] as String?;
    if (novaImagem != null && novaImagem.isNotEmpty) {
      for (final alvo in mesmaLinha) {
        final atual = alvo.imagem(campo);
        if (alvo.id == origemId || (atual != null && atual.isNotEmpty)) continue;
        resultados.add(PatchPropagacaoImagem(id: alvo.id, patch: {campo.campo: novaImagem}, origem: 'propagacao'));
      }
    } else if (isNew) {
      for (final fonte in mesmaLinha) {
        final img = fonte.imagem(campo);
        if (fonte.id != origemId && img != null && img.isNotEmpty) {
          resultados.add(PatchPropagacaoImagem(id: origemId, patch: {campo.campo: img}, origem: 'heranca'));
          break;
        }
      }
    }
  }
  return resultados;
}

class GrupoDuplicado {
  final String chave;
  final String? codigo;
  final String? nome;
  final Dispositivo manter;
  final List<Dispositivo> remover;
  final List<Dispositivo> revisar;
  const GrupoDuplicado({
    required this.chave,
    required this.codigo,
    required this.nome,
    required this.manter,
    required this.remover,
    required this.revisar,
  });
}

class PlanoLimpezaDuplicados {
  final List<GrupoDuplicado> grupos;
  final int totalDocumentos;
  final int combinacoesDistintas;
  final int totalRemover;
  final int totalRevisar;
  const PlanoLimpezaDuplicados({
    required this.grupos,
    required this.totalDocumentos,
    required this.combinacoesDistintas,
    required this.totalRemover,
    required this.totalRevisar,
  });
}

/// Planeja a limpeza de documentos repetidos (Código + Dispositivo). Não apaga nada.
PlanoLimpezaDuplicados planejarLimpezaDuplicados(List<Dispositivo> dispositivos, Set<String> idsComReutilizacao) {
  bool temVinculo(Dispositivo d) =>
      idsComReutilizacao.contains(d.id) ||
      (d.imagemPeca?.isNotEmpty ?? false) ||
      (d.imagemDispositivo?.isNotEmpty ?? false) ||
      d.anexos.isNotEmpty ||
      (d.observacoes?.trim().isNotEmpty ?? false);

  final porChave = <String, List<Dispositivo>>{};
  for (final d in dispositivos) {
    porChave.putIfAbsent(chaveCodigoDispositivo(d.codigo, d.nome), () => []).add(d);
  }

  final grupos = <GrupoDuplicado>[];
  porChave.forEach((chave, lista) {
    if (lista.length < 2) return;
    final ordenada = [...lista]..sort((a, b) {
        final c = (a.dataCriacao ?? '').compareTo(b.dataCriacao ?? '');
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    final manter = ordenada.firstWhere(temVinculo, orElse: () => ordenada.first);
    final outros = ordenada.where((d) => !identical(d, manter)).toList();
    grupos.add(GrupoDuplicado(
      chave: chave,
      codigo: manter.codigo,
      nome: manter.nome,
      manter: manter,
      remover: outros.where((d) => !temVinculo(d)).toList(),
      revisar: outros.where(temVinculo).toList(),
    ));
  });

  return PlanoLimpezaDuplicados(
    grupos: grupos,
    totalDocumentos: dispositivos.length,
    combinacoesDistintas: porChave.length,
    totalRemover: grupos.fold(0, (n, g) => n + g.remover.length),
    totalRevisar: grupos.fold(0, (n, g) => n + g.revisar.length),
  );
}
