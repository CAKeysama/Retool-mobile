import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/solicitacao_cargo.dart';
import '../../domain/entities/user.dart';
import '../../presentation/shell/app_shell.dart';
import '../../presentation/state/auth_controller.dart';
import 'paineis/aprovacoes_cadastro_panel.dart';
import 'paineis/historico_acoes_panel.dart';
import 'paineis/solicitacoes_cargo_panel.dart';
import 'paineis/usuarios_panel.dart';

/// Ids das abas (iguais às rotas `/administracao/:aba` do desktop).
class AbaAdmin {
  AbaAdmin._();
  static const cadastros = 'cadastros';
  static const cargos = 'cargos';
  static const usuarios = 'usuarios';
  static const logs = 'logs';
  static const todas = [cadastros, cargos, usuarios, logs];

  /// Aceita também apelidos usados pelo mobile.
  static String? normalizar(String? aba) => switch (aba) {
        'cadastros' || 'aprovacoes' || 'aprovacao' => cadastros,
        'cargos' || 'solicitacoes' || 'cargo' => cargos,
        'usuarios' => usuarios,
        'logs' || 'historico' || 'auditoria' => logs,
        _ => null,
      };
}

/// Área exclusiva da Administração (rota protegida no router + regras do Firestore):
/// aprovação de cadastros, solicitações de cargo, contas com senha temporária e
/// histórico de ações (`pages/Administracao.tsx` do desktop).
class AdministracaoScreen extends StatefulWidget {
  final String? abaInicial;
  const AdministracaoScreen({super.key, this.abaInicial});

  @override
  State<AdministracaoScreen> createState() => _AdministracaoScreenState();
}

class _AdministracaoScreenState extends State<AdministracaoScreen> {
  /// Aba escolhida pelo toque (prevalece sobre a da URL até ela mudar).
  String? _abaEscolhida;
  String? _destacarId;
  String? _ultimoDestaqueUrl;
  bool _iniciado = false;
  final Set<String> _visitadas = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_iniciado) {
      _iniciado = true;
      _destacarId = _ultimoDestaqueUrl = _destaqueDaUrl();
    }
  }

  @override
  void didUpdateWidget(AdministracaoScreen old) {
    super.didUpdateWidget(old);
    // Nova navegação para a Administração (ex.: vinda de uma notificação).
    final destaque = _destaqueDaUrl();
    final novoDestaque = destaque != null && destaque != _ultimoDestaqueUrl;
    if (old.abaInicial != widget.abaInicial || novoDestaque) {
      _abaEscolhida = null;
      _destacarId = destaque;
    }
    if (destaque != null) _ultimoDestaqueUrl = destaque;
  }

  String? _destaqueDaUrl() {
    try {
      return GoRouter.maybeOf(context)?.state.uri.queryParameters['destaque'];
    } catch (_) {
      return null;
    }
  }

  void _irPara(String aba, {String? destacar}) => setState(() {
        _abaEscolhida = aba;
        _destacarId = destacar;
      });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final pendentesCadastro = auth.users.where((u) => situacaoDoUsuario(u) == SituacaoUsuario.pendente).length;
    final pendentesCargo = auth.solicitacoesCargo.where((s) => s.status == SolicitacaoCargoStatus.pendente).length;

    // Sem aba na URL: abre onde há pendências; senão, a gestão de usuários.
    final ativa = _abaEscolhida ??
        AbaAdmin.normalizar(widget.abaInicial) ??
        (pendentesCadastro > 0
            ? AbaAdmin.cadastros
            : pendentesCargo > 0
                ? AbaAdmin.cargos
                : AbaAdmin.usuarios);
    _visitadas.add(ativa);

    final abas = <({String id, String label})>[
      (id: AbaAdmin.cadastros, label: 'Cadastros pendentes ($pendentesCadastro)'),
      (id: AbaAdmin.cargos, label: 'Solicitações de cargo ($pendentesCargo)'),
      (id: AbaAdmin.usuarios, label: 'Usuários (${auth.users.length})'),
      (id: AbaAdmin.logs, label: 'Histórico de ações'),
    ];

    Widget painel(String id) {
      if (!_visitadas.contains(id)) return const SizedBox.shrink();
      return switch (id) {
        AbaAdmin.cadastros => AprovacoesCadastroPanel(destacarId: ativa == id ? _destacarId : null),
        AbaAdmin.cargos => SolicitacoesCargoPanel(destacarId: ativa == id ? _destacarId : null),
        AbaAdmin.usuarios => UsuariosPanel(onAnalisarCadastro: (uid) => _irPara(AbaAdmin.cadastros, destacar: uid)),
        _ => const HistoricoAcoesPanel(),
      };
    }

    return Scaffold(
      appBar: appBarPadrao(context, titulo: const Text('Administração')),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(children: [
            for (final a in abas) ...[
              if (a != abas.first) const SizedBox(width: AppSpacing.sm),
              _AbaPill(
                key: ValueKey('aba-${a.id}'),
                label: a.label,
                selecionada: a.id == ativa,
                onTap: () => _irPara(a.id),
              ),
            ],
          ]),
        ),
        const Divider(),
        Expanded(
          child: IndexedStack(
            index: AbaAdmin.todas.indexOf(ativa),
            children: [for (final id in AbaAdmin.todas) painel(id)],
          ),
        ),
      ]),
    );
  }
}

/// Aba em pílula (`Tabs.tsx` do desktop).
class _AbaPill extends StatelessWidget {
  final String label;
  final bool selecionada;
  final VoidCallback onTap;
  const _AbaPill({super.key, required this.label, required this.selecionada, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selecionada,
        button: true,
        child: Material(
          color: selecionada ? AppColors.primary : Colors.transparent,
          shape: StadiumBorder(side: BorderSide(color: selecionada ? AppColors.primary : AppColors.border)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              child: Center(
                child: Text(label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selecionada ? FontWeight.w700 : FontWeight.w500,
                      color: selecionada ? Colors.white : AppColors.textBody,
                    )),
              ),
            ),
          ),
        ),
      );
}
