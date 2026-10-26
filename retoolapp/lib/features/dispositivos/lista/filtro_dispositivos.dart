import '../../../core/utils/busca.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/dispositivo.dart';
import '../../../presentation/state/retool_controller.dart';

/// Processos industriais do filtro "Processo Industrial" do desktop.
const processosIndustriais = ['Shotblaster', 'Coping', 'Sawing', 'Drilling'];

/// Situação do cadastro (filtro extra do mobile: o desktop mostra todos).
enum FiltroStatus {
  todos('Todos'),
  ativos('Ativos'),
  inativos('Inativos');

  final String rotulo;
  const FiltroStatus(this.rotulo);
}

/// Estado dos filtros da lista (equivalente aos `filter*` do `useDispositivosController`).
class FiltrosDispositivos {
  final String query;
  final String? categoriaId;
  final String? processo;
  final FiltroStatus status;

  const FiltrosDispositivos({this.query = '', this.categoriaId, this.processo, this.status = FiltroStatus.todos});

  /// Quantidade de filtros do painel ativos (a busca textual não conta).
  int get ativos => (categoriaId != null ? 1 : 0) + (processo != null ? 1 : 0) + (status != FiltroStatus.todos ? 1 : 0);

  FiltrosDispositivos copyWith({
    String? query,
    String? Function()? categoriaId,
    String? Function()? processo,
    FiltroStatus? status,
  }) => FiltrosDispositivos(
    query: query ?? this.query,
    categoriaId: categoriaId != null ? categoriaId() : this.categoriaId,
    processo: processo != null ? processo() : this.processo,
    status: status ?? this.status,
  );

  @override
  bool operator ==(Object other) =>
      other is FiltrosDispositivos &&
      other.query == query &&
      other.categoriaId == categoriaId &&
      other.processo == processo &&
      other.status == status;

  @override
  int get hashCode => Object.hash(query, categoriaId, processo, status);
}

/// Aplica busca multidimensional (índice do controller, tolerante a acentos),
/// categoria, processo industrial (nome, descrição ou palavras-chave) e situação.
List<Dispositivo> filtrarDispositivos(ReToolController retool, FiltrosDispositivos f) {
  final base = retool.buscarDispositivos(f.query);
  final proc = normalizarBusca(f.processo).trim();
  if (f.categoriaId == null && proc.isEmpty && f.status == FiltroStatus.todos) return base;
  return base.where((d) {
    if (f.categoriaId != null && d.categoriaId != f.categoriaId) return false;
    if (f.status == FiltroStatus.ativos && !d.ativo) return false;
    if (f.status == FiltroStatus.inativos && d.ativo) return false;
    if (proc.isNotEmpty) {
      final casa =
          normalizarBusca(d.descricao).contains(proc) ||
          normalizarBusca(d.nome).contains(proc) ||
          d.palavrasChave.any((t) => normalizarBusca(t).contains(proc));
      if (!casa) return false;
    }
    return true;
  }).toList();
}

/// Cor do badge pela primeira letra (`getBadgeColor` do desktop).
BadgeCor corDoBadge(String texto) {
  if (texto.isEmpty) return BadgeCor.neutro;
  return switch (texto.codeUnitAt(0) % 4) {
    0 => BadgeCor.pink,
    1 => BadgeCor.teal,
    2 => BadgeCor.yellow,
    _ => BadgeCor.blue,
  };
}

/// "1 dispositivo encontrado" / "N dispositivos encontrados".
String rotuloEncontrados(int n) => n == 1 ? '1 dispositivo encontrado' : '$n dispositivos encontrados';

/// "1 item" / "N itens".
String rotuloItens(int n) => n == 1 ? '1 item' : '$n itens';
