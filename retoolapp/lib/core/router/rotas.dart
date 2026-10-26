/// Caminhos das telas (espelham as rotas do desktop).
class Rotas {
  Rotas._();
  static const carregando = '/carregando';
  static const login = '/login';
  static const aguardando = '/aguardando-aprovacao';
  static const trocaSenha = '/troca-senha';

  static const home = '/';
  static const dispositivos = '/dispositivos';
  static const novoDispositivo = '/dispositivos/novo';
  static String dispositivo(String id) => '/dispositivos/$id';
  static String editarDispositivo(String id) => '/dispositivos/$id/editar';
  static String buscarDispositivos(String q) => '/dispositivos?q=${Uri.encodeQueryComponent(q)}';

  static const reutilizacoes = '/reutilizacoes';

  /// Abre a tela de reutilizações destacando uma solicitação (vindo de notificação).
  static String reutilizacao(String id) => '/reutilizacoes?destaque=${Uri.encodeQueryComponent(id)}';

  static const categorias = '/categorias';
  static const administracao = '/administracao';
  static String administracaoAba(String aba) => '/administracao?aba=$aba';

  static const sobre = '/sobre';
  static const notificacoes = '/notificacoes';
  static const perfil = '/perfil';

  static const publicas = {login};
  static const sessaoRestrita = {carregando, login, aguardando, trocaSenha};
}
