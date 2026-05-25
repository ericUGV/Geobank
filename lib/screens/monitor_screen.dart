// lib/screens/monitor_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../services/monitor_cnpj_service.dart';

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});
  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Config ─────────────────────────────────────────────────────────────────
  final _cidadeController = TextEditingController();
  List<String> _cidades = [];
  StreamSubscription? _cidadesSubscription;

  // ── Monitor automático ─────────────────────────────────────────────────────
  bool _monitorAtivo = false;
  bool _verificando = false;
  String _statusMsg = 'Monitor inativo. Ative para detectar novas empresas.';
  int _novasHoje = 0;
  Timer? _timer;

  // ── Alertas ────────────────────────────────────────────────────────────────
  StreamSubscription? _alertasSubscription;
  List<Map<String, dynamic>> _alertas = [];
  int _naoVistas = 0;

  // ── Busca ──────────────────────────────────────────────────────────────────
  final _cnpjController = TextEditingController();
  bool _consultando = false;
  EmpresaDetectada? _resultadoConsulta;
  String? _erroConsulta;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Carrega cidades salvas
    _cidadesSubscription = MonitorCnpjService.streamCidades().listen((cidades) {
      if (mounted) setState(() => _cidades = cidades);
    });

    // Carrega alertas
    _alertasSubscription = MonitorCnpjService.streamDetectadas().listen((lista) {
      if (mounted) setState(() => _alertas = lista);
    });

    // Badge de não vistas
    MonitorCnpjService.streamNaoVistas().listen((n) {
      if (mounted) setState(() => _naoVistas = n);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cidadeController.dispose();
    _cnpjController.dispose();
    _timer?.cancel();
    _cidadesSubscription?.cancel();
    _alertasSubscription?.cancel();
    super.dispose();
  }

  // ── Monitor automático ─────────────────────────────────────────────────────

  void _toggleMonitor() {
    if (_monitorAtivo) {
      _timer?.cancel();
      setState(() {
        _monitorAtivo = false;
        _statusMsg = 'Monitor pausado.';
      });
    } else {
      if (_cidades.isEmpty) {
        _snack('Adicione pelo menos uma cidade antes de ativar o monitor.', isError: true);
        return;
      }
      setState(() {
        _monitorAtivo = true;
        _statusMsg = 'Monitor ativo — verificando a cada 30 min...';
      });
      _verificarAgora(); // roda imediatamente
      _timer = Timer.periodic(const Duration(minutes: 30), (_) => _verificarAgora());
    }
  }

  Future<void> _verificarAgora() async {
    if (_verificando || _cidades.isEmpty) return;
    setState(() {
      _verificando = true;
      _statusMsg = 'Verificando novas empresas...';
    });
    try {
      final novas = await MonitorCnpjService.verificar(_cidades);
      setState(() {
        _novasHoje += novas;
        _statusMsg = novas > 0
            ? '$novas nova(s) empresa(s) detectada(s)! Total hoje: $_novasHoje'
            : 'Verificação concluída. Nenhuma empresa nova.';
      });
      if (novas > 0) {
        _snack('$novas nova(s) empresa(s) adicionada(s) à carteira!');
        _tabController.animateTo(1); // vai para aba Alertas
      }
    } catch (e) {
      setState(() => _statusMsg = 'Erro na verificação: $e');
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  // ── Cidades ────────────────────────────────────────────────────────────────

  Future<void> _adicionarCidade() async {
    final cidade = _cidadeController.text.trim().toUpperCase();
    if (cidade.isEmpty) return;
    if (_cidades.contains(cidade)) {
      _snack('$cidade já está na lista.', isError: true);
      return;
    }
    final novas = [..._cidades, cidade];
    await MonitorCnpjService.salvarCidades(novas);
    _cidadeController.clear();
    _snack('$cidade adicionada!');
  }

  Future<void> _removerCidade(String cidade) async {
    final novas = _cidades.where((c) => c != cidade).toList();
    await MonitorCnpjService.salvarCidades(novas);
  }

  // ── Busca avulsa ───────────────────────────────────────────────────────────

  Future<void> _consultar() async {
    final busca = _cnpjController.text.trim();
    if (busca.isEmpty) return;
    setState(() {
      _consultando = true;
      _resultadoConsulta = null;
      _erroConsulta = null;
    });
    try {
      final numeros = busca.replaceAll(RegExp(r'[^0-9]'), '');
      EmpresaDetectada? resultado;
      if (numeros.length == 14) {
        resultado = await MonitorCnpjService.consultarCnpj(numeros);
      } else {
        final lista = await MonitorCnpjService.buscarEmpresaPorNome(busca);
        resultado = lista.isNotEmpty ? lista.first : null;
      }
      setState(() {
        _resultadoConsulta = resultado;
        _erroConsulta = resultado == null ? 'Nenhum resultado encontrado.' : null;
      });
    } finally {
      if (mounted) setState(() => _consultando = false);
    }
  }

  Future<void> _salvarNaCarteira(EmpresaDetectada e) async {
    await MonitorCnpjService.adicionarACarteira(e);
    _snack('${e.razaoSocial} salva na carteira!');
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : const Color(0xFF16A34A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Monitor de Prospecção'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            const Tab(icon: Icon(Icons.settings_outlined), text: 'Config'),
            Tab(
              icon: _naoVistas > 0
                  ? Badge(label: Text('$_naoVistas'), child: const Icon(Icons.notifications_outlined))
                  : const Icon(Icons.notifications_outlined),
              text: 'Alertas',
            ),
            const Tab(icon: Icon(Icons.search), text: 'Busca'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildConfig(), _buildAlertas(), _buildBusca()],
      ),
    );
  }

  // ── Aba Config ─────────────────────────────────────────────────────────────

  Widget _buildConfig() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Status card do monitor
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: _monitorAtivo ? const Color(0xFF16A34A) : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _monitorAtivo ? 'Monitor Ativo' : 'Monitor Inativo',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _monitorAtivo ? const Color(0xFF16A34A) : AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (_verificando)
                    const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 8),
              Text(_statusMsg, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              if (_novasHoje > 0) ...[
                const SizedBox(height: 6),
                Text('$_novasHoje empresa(s) detectada(s) hoje',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF16A34A))),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _toggleMonitor,
                      icon: Icon(_monitorAtivo ? Icons.pause : Icons.play_arrow),
                      label: Text(_monitorAtivo ? 'Pausar' : 'Ativar Monitor'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _monitorAtivo ? Colors.orange : AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _verificando ? null : _verificarAgora,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Verificar Agora'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const Text('Cidades Monitoradas',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        const Text('O sistema detectará automaticamente empresas abertas nestas cidades.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 12),

        // Campo para adicionar cidade
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _cidadeController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Ex: SAO MATEUS DO SUL',
                  filled: true, fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.divider)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.divider)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                ),
                onSubmitted: (_) => _adicionarCidade(),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _adicionarCidade,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Lista de cidades
        if (_cidades.isEmpty)
          _card(
            child: Row(
              children: const [
                Icon(Icons.location_city_outlined, color: AppColors.textSecondary, size: 20),
                SizedBox(width: 10),
                Text('Nenhuma cidade adicionada ainda.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          )
        else
          ..._cidades.map((cidade) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.divider),
            ),
            child: ListTile(
              leading: const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 20),
              title: Text(cidade, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                onPressed: () => _removerCidade(cidade),
              ),
              dense: true,
            ),
          )),
      ],
    );
  }

  // ── Aba Alertas ────────────────────────────────────────────────────────────

  Widget _buildAlertas() {
    if (_alertas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications_none, size: 60, color: AppColors.divider),
            const SizedBox(height: 16),
            const Text('Nenhuma empresa detectada ainda.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            const SizedBox(height: 8),
            const Text('Ative o monitor e adicione cidades para começar.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Barra de ações
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Text('${_alertas.length} empresa(s) detectada(s)',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const Spacer(),
              if (_naoVistas > 0)
                TextButton(
                  onPressed: MonitorCnpjService.marcarTodasVistas,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                  child: const Text('Marcar todas como vistas',
                      style: TextStyle(fontSize: 12, color: AppColors.primary)),
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _alertas.length,
            itemBuilder: (ctx, i) => _alertaCard(_alertas[i]),
          ),
        ),
      ],
    );
  }

  Widget _alertaCard(Map<String, dynamic> data) {
    final visto = data['visto'] == true;
    final score = (data['score'] ?? 0).toDouble();
    final scoreColor = AppTheme.scoreColor(score);
    final docId = data['id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: visto ? Colors.white : AppColors.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: visto ? AppColors.divider : AppColors.primary.withOpacity(0.25),
          width: visto ? 1 : 1.5,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () { if (!visto && docId.isNotEmpty) MonitorCnpjService.marcarVista(docId); },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (!visto)
                    Container(
                      width: 8, height: 8, margin: const EdgeInsets.only(right: 8),
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    ),
                  Expanded(
                    child: Text(data['nome'] ?? '',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                            color: visto ? AppColors.textPrimary : AppColors.primary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: scoreColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.star, size: 12, color: scoreColor),
                      const SizedBox(width: 3),
                      Text('${score.toInt()}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: scoreColor)),
                    ]),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if ((data['cnpj'] ?? '').isNotEmpty)
                Text('CNPJ: ${data['cnpj']}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              if ((data['cnae'] ?? '').isNotEmpty)
                Text(data['cnae'],
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              if ((data['municipio'] ?? '').isNotEmpty)
                Text('${data['municipio']}/${data['uf'] ?? ''}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final empresa = EmpresaDetectada.fromFirestore(data);
                        await _salvarNaCarteira(empresa);
                      },
                      icon: const Icon(Icons.add_business, size: 16),
                      label: const Text('Adicionar à Carteira'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () {
                      if (docId.isNotEmpty) MonitorCnpjService.deletarDetectada(docId);
                    },
                    tooltip: 'Remover alerta',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Aba Busca ──────────────────────────────────────────────────────────────

  Widget _buildBusca() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Busca por CNPJ ou Nome',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        const Text('Digite o CNPJ completo (14 dígitos) ou parte do nome da empresa.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _cnpjController,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  hintText: 'CNPJ ou nome da empresa...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                  filled: true, fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.divider)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.divider)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                ),
                onSubmitted: (_) => _consultar(),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _consultando ? null : _consultar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _consultando
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.search),
            ),
          ],
        ),

        const SizedBox(height: 20),

        if (_erroConsulta != null)
          _card(
            child: Row(children: [
              const Icon(Icons.info_outline, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(_erroConsulta!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
            ]),
          ),

        if (_resultadoConsulta != null) _resultadoCard(_resultadoConsulta!),
      ],
    );
  }

  Widget _resultadoCard(EmpresaDetectada e) {
    final scoreColor = AppTheme.scoreColor(e.score);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(e.razaoSocial,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: scoreColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.star, size: 14, color: scoreColor),
                  const SizedBox(width: 4),
                  Text('${e.score.toInt()}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: scoreColor)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow(Icons.badge_outlined, 'CNPJ', e.cnpj),
          if (e.cnaeDescricao.isNotEmpty) _infoRow(Icons.category_outlined, 'CNAE', e.cnaeDescricao),
          if (e.enderecoCompleto.isNotEmpty) _infoRow(Icons.location_on_outlined, 'Endereço', e.enderecoCompleto),
          if (e.telefone1.isNotEmpty) _infoRow(Icons.phone_outlined, 'Telefone', e.telefone1),
          if (e.situacao.isNotEmpty) _infoRow(Icons.info_outline, 'Situação', e.situacao),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _salvarNaCarteira(e),
                  icon: const Icon(Icons.add_business, size: 18),
                  label: const Text('Salvar na Carteira'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              if (e.telefone1.isNotEmpty) ...[
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final digits = e.telefone1.replaceAll(RegExp(r'[^0-9]'), '');
                    final uri = Uri.parse('https://wa.me/55$digits');
                    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.chat_outlined, size: 18),
                  label: const Text('WhatsApp'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF16A34A),
                    side: const BorderSide(color: Color(0xFF16A34A)),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: AppColors.primary),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
      ]),
    ]),
  );

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.divider),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
    ),
    child: child,
  );
}