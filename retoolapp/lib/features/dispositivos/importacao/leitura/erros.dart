/// Falha de leitura com mensagem pronta para o usuário (pt-BR).
class ErroLeituraPlanilha implements Exception {
  final String mensagem;
  const ErroLeituraPlanilha(this.mensagem);

  @override
  String toString() => mensagem;
}

const mensagemXlsNaoSuportado =
    'Arquivos .xls (Excel 97-2003) não podem ser lidos no celular. Abra a planilha no Excel, use "Salvar como" '
    '.xlsx ou .csv e importe novamente.';

const mensagemArquivoInvalido = 'Ocorreu um erro ao ler o arquivo. Verifique o formato.';
