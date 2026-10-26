import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../application/usecases/acessos_usecases.dart';
import '../../../core/config/app_dependencies.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/busca.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/user.dart';
import '../../../presentation/state/auth_controller.dart';
import '../widgets/admin_comum.dart';
import '../widgets/senha_temporaria_dialog.dart';

/// Gestão de contas pela Administração: criação com senha temporária gerada
/// pelo sistema, nova senha temporária (Cloud Function), alteração de cargo,
/// bloqueio e exclusão (`UsuariosPanel` do desktop).
class UsuariosPanel extends StatefulWidget {
  /// Abre a aba de cadastros destacando o usuário ("Analisar cadastro").
  final ValueChanged<String> onAnalisarCadastro;
  const UsuariosPanel({super.key, required this.onAnalisarCadastro});

  @override
  State<UsuariosPanel> createState() => _UsuariosPanelState();
}

class _UsuariosPanelState extends State<UsuariosPanel> {
  final _busca = TextEditingController();
  Timer? _debounce;
  String _termo = '';
  SituacaoUsuario? _filtroSituacao;
  String? _filtroCargo;
  String? _processandoUid;

  @override
  void dispose() {
    _debounce?.cancel();
    _busca.dispose();
    super.dispose();
  }

  void _aoBuscar(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _termo = normalizarBusca(v.trim()));
    });
  }

  String _traduzir(Object e) => context.read<AppDependencies>().traduzirErro(e);

  Future<void> _executar(String uid, Future<void> Function() acao, String sucesso) async {
    final traduzir = context.read<AppDependencies>().traduzirErro;
    setState(() => _processandoUid = uid);
    try {
      await acao();
      Toasts.mostrar(sucesso);
    } catch (e) {
      Toasts.mostrar(traduzir(e), erro: true);
    } finally {
      if (mounted) setState(() => _processandoUid = null);
    }
  }

  Future<void> _novaConta() async {
    final conta = await showAppSheet<({ContaCriada conta, UserRole perfil})>(
      context,
      titulo: 'Criar nova conta',
      subtitulo: 'O sistema gera uma senha temporária segura; o colaborador será obrigado a trocá-la no primeiro acesso.',
      builder: (_) => const _NovaContaForm(),
    );
    if (conta == null || !mounted) return;
    await mostrarSenhaTemporaria(
      context,
      titulo: 'Conta criada: ${conta.conta.perfil.nome} (${rolesConfig[conta.perfil]!.titulo})',
      email: conta.conta.perfil.email,
      senha: conta.conta.senhaTemporaria,
    );
  }

  Future<void> _redefinirSenha(UserProfile alvo) async {
    final ok = await confirmar(
      context,
      titulo: 'Gerar nova senha temporária',
      mensagem:
          'A senha atual de ${alvo.nome} (${alvo.email}) deixará de valer, as sessões abertas serão encerradas e a troca de senha será obrigatória no próximo acesso.',
      confirmarLabel: 'Gerar nova senha',
    );
    if (!ok || !mounted) return;
    final auth = context.read<AuthController>();
    setState(() => _processandoUid = alvo.uid);
    try {
      final senha = await auth.redefinirSenhaTemporaria(alvo.uid);
      if (!mounted) return;
      setState(() => _processandoUid = null);
      await mostrarSenhaTemporaria(context, titulo: 'Nova senha temporária: ${alvo.nome}', email: alvo.email, senha: senha);
    } catch (e) {
      if (mounted) Toasts.mostrar(_traduzir(e), erro: true);
    } finally {
      if (mounted && _processandoUid == alvo.uid) setState(() => _processandoUid = null);
    }
  }

  Future<void> _excluir(UserProfile alvo) async {
    final ok = await confirmar(
      context,
      titulo: 'Excluir usuário',
      mensagem: 'Remover ${alvo.nome} (${alvo.email}) do sistema? Esta ação não pode ser desfeita.',
      confirmarLabel: 'Excluir',
      perigoso: true,
    );
    if (!ok || !mounted) return;
    final auth = context.read<AuthController>();
    await _executar(alvo.uid, () => auth.deleteUser(alvo.uid), 'Usuário ${alvo.nome} excluído do sistema.');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (auth.estadoUsuarios == EstadoSincronizacao.carregando) {
      return const EstadoCarregando(mensagem: 'Carregando usuários...');
    }
    if (auth.estadoUsuarios == EstadoSincronizacao.erro) {
      return const EstadoErro(
          mensagem:
              'Não foi possível carregar os usuários. Verifique sua conexão e se as regras do Firestore foram publicadas.');
    }

    final users = auth.users;
    final listados = users.where((u) {
      if (_filtroSituacao != null && situacaoDoUsuario(u) != _filtroSituacao) return false;
      if (_filtroCargo != null && u.perfil != _filtroCargo) return false;
      if (_termo.isEmpty) return true;
      return normalizarBusca(u.nome).contains(_termo) || normalizarBusca(u.email).contains(_termo);
    }).toList()
      ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    final meuUid = auth.userProfile?.uid;

    return CustomScrollView(slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
        sliver: SliverToBoxAdapter(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AppSearchField(controller: _busca, hint: 'Buscar por nome ou e-mail...', onChanged: _aoBuscar),
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              Expanded(
                child: Semantics(
                  label: 'Filtrar por situação',
                  child: AppDropdown<SituacaoUsuario?>(
                    key: const ValueKey('filtro-situacao'),
                    value: _filtroSituacao,
                    onChanged: (v) => setState(() => _filtroSituacao = v),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todas as situações', overflow: TextOverflow.ellipsis)),
                      for (final s in SituacaoUsuario.values)
                        DropdownMenuItem(value: s, child: Text(situacaoVisual[s]!.label, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Semantics(
                  label: 'Filtrar por cargo',
                  child: AppDropdown<String?>(
                    key: const ValueKey('filtro-cargo'),
                    value: _filtroCargo,
                    onChanged: (v) => setState(() => _filtroCargo = v),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todos os cargos', overflow: TextOverflow.ellipsis)),
                      for (final r in perfisAtribuiveis)
                        DropdownMenuItem(
                            value: r.name, child: Text(rolesConfig[r]!.tituloCurto, overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(
                          value: perfilConvidado, child: Text(convidadoConfig.tituloCurto, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              Expanded(
                child: Text(
                  '${listados.length} de ${users.length} ${users.length == 1 ? 'usuário' : 'usuários'}',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                ),
              ),
              AppButton.primary(label: 'Nova conta', icon: LucideIcons.userPlus, compact: true, onPressed: _novaConta),
            ]),
          ]),
        ),
      ),
      if (listados.isEmpty)
        SliverToBoxAdapter(
          child: FilaVazia(users.isEmpty ? 'Nenhum usuário cadastrado.' : 'Nenhum usuário encontrado para os filtros atuais.'),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
          sliver: SliverList.separated(
            itemCount: listados.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) {
              final u = listados[i];
              return _CartaoUsuario(
                key: ValueKey('usuario-${u.uid}'),
                usuario: u,
                propria: u.uid == meuUid,
                ocupado: _processandoUid == u.uid,
                onAlterarCargo: (perfil) => _executar(
                  u.uid,
                  () => auth.updateUserRole(u.uid, perfil),
                  'Cargo de ${u.nome} alterado para ${rolesConfig[perfil]!.titulo}.',
                ),
                onAlternarBloqueio: () => _executar(
                  u.uid,
                  () => auth.toggleUserStatus(u.uid, !u.ativo),
                  u.ativo ? '${u.nome} foi bloqueado.' : '${u.nome} foi desbloqueado.',
                ),
                onRedefinirSenha: () => _redefinirSenha(u),
                onExcluir: () => _excluir(u),
                onAnalisar: () => widget.onAnalisarCadastro(u.uid),
              );
            },
          ),
        ),
    ]);
  }
}

class _CartaoUsuario extends StatelessWidget {
  final UserProfile usuario;
  final bool propria;
  final bool ocupado;
  final ValueChanged<UserRole> onAlterarCargo;
  final VoidCallback onAlternarBloqueio;
  final VoidCallback onRedefinirSenha;
  final VoidCallback onExcluir;
  final VoidCallback onAnalisar;

  const _CartaoUsuario({
    super.key,
    required this.usuario,
    required this.propria,
    required this.ocupado,
    required this.onAlterarCargo,
    required this.onAlternarBloqueio,
    required this.onRedefinirSenha,
    required this.onExcluir,
    required this.onAnalisar,
  });

  @override
  Widget build(BuildContext context) {
    final u = usuario;
    final situacao = situacaoDoUsuario(u);
    final gerenciavel = situacao == SituacaoUsuario.ativo || situacao == SituacaoUsuario.bloqueado;
    final cargoEditavel = !propria && gerenciavel && isPerfilAtribuivel(u.perfil);

    return CartaoAdmin(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: u.nome),
                if (propria)
                  const TextSpan(text: ' (você)', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w500)),
              ]), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
              TextoSecundario(u.email, tamanho: 12),
            ]),
          ),
          const SizedBox(width: 8),
          SituacaoBadge(situacao),
        ]),
        if (u.trocaSenhaObrigatoria) ...[
          const SizedBox(height: 6),
          const Pill(
            label: 'Senha temporária — troca pendente',
            fundo: Color(0xFFFEF3C7),
            texto: Color(0xFFB45309),
            icon: LucideIcons.keyRound,
          ),
        ],
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (cargoEditavel)
            _SeletorCargo(usuario: u, enabled: !ocupado, onSelecionado: onAlterarCargo)
          else
            Tooltip(
              message: propria ? 'A Administração não altera o próprio cargo' : '',
              child: RoleBadge(perfil: u.perfil),
            ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (situacao == SituacaoUsuario.pendente)
            BotaoAcao(label: 'Analisar cadastro', cor: CorAcao.primary, onPressed: onAnalisar),
          if (gerenciavel && !propria)
            BotaoAcao(
              label: u.ativo ? 'Bloquear acesso' : 'Desbloquear',
              cor: u.ativo ? CorAcao.bloquear : CorAcao.desbloquear,
              loading: ocupado,
              onPressed: ocupado ? null : onAlternarBloqueio,
            ),
          if (gerenciavel && !propria)
            BotaoIconeAcao(
              icon: LucideIcons.keyRound,
              tooltip: 'Gerar nova senha temporária para ${u.nome}',
              cor: CorAcao.senha,
              onPressed: ocupado ? null : onRedefinirSenha,
            ),
          BotaoIconeAcao(
            icon: LucideIcons.trash2,
            tooltip: propria ? 'Não é possível excluir a própria conta' : 'Excluir usuário ${u.nome}',
            cor: CorAcao.bloquear,
            onPressed: propria || ocupado ? null : onExcluir,
          ),
        ]),
      ]),
    );
  }
}

/// Seletor de cargo com as cores do cargo atual (o `<select>` estilizado do desktop).
class _SeletorCargo extends StatelessWidget {
  final UserProfile usuario;
  final bool enabled;
  final ValueChanged<UserRole> onSelecionado;
  const _SeletorCargo({required this.usuario, required this.enabled, required this.onSelecionado});

  @override
  Widget build(BuildContext context) {
    final conf = configDoPerfil(usuario.perfil);
    return PopupMenuButton<UserRole>(
      tooltip: 'Cargo de ${usuario.nome}',
      enabled: enabled,
      initialValue: userRoleFromString(usuario.perfil),
      onSelected: (r) {
        if (r.name != usuario.perfil) onSelecionado(r);
      },
      itemBuilder: (_) => [
        for (final r in perfisAtribuiveis) PopupMenuItem(value: r, child: Text(rolesConfig[r]!.titulo)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: conf.badgeBg,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: conf.borderColor, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(
            child: Text(conf.titulo,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: conf.badgeText, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          const SizedBox(width: 4),
          Icon(LucideIcons.chevronDown, size: 14, color: conf.badgeText),
        ]),
      ),
    );
  }
}

/// Formulário "Criar nova conta" (fecha devolvendo a conta criada).
class _NovaContaForm extends StatefulWidget {
  const _NovaContaForm();

  @override
  State<_NovaContaForm> createState() => _NovaContaFormState();
}

class _NovaContaFormState extends State<_NovaContaForm> {
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  UserRole _perfil = UserRole.engenharia;
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _criar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final auth = context.read<AuthController>();
    final traduzir = context.read<AppDependencies>().traduzirErro;
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      final conta = await auth.criarContaComSenhaTemporaria(_nome.text, _email.text, _perfil);
      if (mounted) Navigator.of(context).pop((conta: conta, perfil: _perfil));
    } catch (e) {
      if (mounted) setState(() => _erro = traduzir(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_erro != null) ...[
          AvisoAdmin(tipo: TipoAviso.erro, texto: _erro!),
          const SizedBox(height: AppSpacing.md),
        ],
        AppTextField(
          label: 'Nome completo',
          hint: 'Ex: Ana Beatriz',
          controller: _nome,
          obrigatorio: true,
          textInputAction: TextInputAction.next,
          validator: (v) => (v ?? '').trim().isEmpty ? 'Informe o nome completo do colaborador.' : null,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'E-mail institucional',
          hint: 'usuario@empresa.com',
          controller: _email,
          obrigatorio: true,
          keyboardType: TextInputType.emailAddress,
          validator: (v) => (v ?? '').trim().isEmpty ? 'Informe um e-mail válido.' : null,
        ),
        const SizedBox(height: AppSpacing.md),
        AppDropdown<UserRole>(
          label: 'Cargo',
          obrigatorio: true,
          value: _perfil,
          onChanged: _enviando ? null : (r) => setState(() => _perfil = r ?? _perfil),
          items: [
            for (final r in perfisAtribuiveis)
              DropdownMenuItem(value: r, child: Text(rolesConfig[r]!.titulo, overflow: TextOverflow.ellipsis)),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton.primary(
          label: _enviando ? 'Criando conta...' : 'Criar conta e gerar senha',
          icon: LucideIcons.userPlus,
          loading: _enviando,
          expand: true,
          onPressed: _criar,
        ),
      ]),
    );
  }
}
