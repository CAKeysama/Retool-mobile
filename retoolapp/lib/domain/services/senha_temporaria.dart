import 'dart:math';

/// Senhas temporárias para contas criadas pela Administração (CSPRNG do sistema,
/// sem viés de módulo). A senha nunca é persistida: o Firebase Auth guarda só o hash.

// Sem caracteres ambíguos (0/O, 1/l/I) para facilitar o repasse ao colaborador.
const _maiusculas = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
const _minusculas = 'abcdefghijkmnpqrstuvwxyz';
const _digitos = '23456789';
const _simbolos = '!@#\$%*-_+?';
const _todos = _maiusculas + _minusculas + _digitos + _simbolos;

const int tamanhoSenhaTemporaria = 14;
const int tamanhoMinimoSenha = 8;

String gerarSenhaTemporaria({int tamanho = tamanhoSenhaTemporaria, Random? fonte}) {
  if (tamanho < tamanhoMinimoSenha) {
    throw ArgumentError('A senha temporária deve ter ao menos $tamanhoMinimoSenha caracteres.');
  }
  final rnd = fonte ?? Random.secure();
  String escolher(String alfabeto) => alfabeto[rnd.nextInt(alfabeto.length)];

  // Garante ao menos um caractere de cada classe; o restante é uniforme.
  final chars = [escolher(_maiusculas), escolher(_minusculas), escolher(_digitos), escolher(_simbolos)];
  while (chars.length < tamanho) {
    chars.add(escolher(_todos));
  }
  chars.shuffle(rnd);
  return chars.join();
}

/// Política da nova senha definida no primeiro acesso; retorna o erro ou null.
String? validarNovaSenha(String novaSenha, String confirmacao, [String? senhaAtual]) {
  if (novaSenha.length < tamanhoMinimoSenha) {
    return 'A nova senha deve ter no mínimo $tamanhoMinimoSenha caracteres.';
  }
  if (!RegExp(r'[A-Za-z]').hasMatch(novaSenha) || !RegExp(r'\d').hasMatch(novaSenha)) {
    return 'A nova senha deve conter letras e números.';
  }
  if (novaSenha != confirmacao) return 'A confirmação não coincide com a nova senha.';
  if (senhaAtual != null && senhaAtual.isNotEmpty && novaSenha == senhaAtual) {
    return 'A nova senha deve ser diferente da senha temporária.';
  }
  return null;
}
