import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Estado do monitor
  bool _monitorAtivo = false;
  bool _verificando = false;
  String _statusMsg = 'Monitor inativo';
  int _novasHoje = 0;
  Timer? _timer;
  int _intervaloMinutos = 15;

  // Cidades
  List<String> _cidades = [];
  final _cidadeController = TextEditingController();

  // Consulta avulsa
  final _cnpjController = TextEditingController();
  bool _consultando = false;
  EmpresaDetectada? _resultadoConsulta;
  String? _erroConsulta;

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    MonitorCnpjService.streamCidades().listen((cidades) {
      if (mounted) setState(() => _cidades = cidades);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cidadeController.dispose();
    _cnpjController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // ─── Monitor ─────────────────────────────────────────────────────────────

  void _iniciarMonitor() {
    if (_cidades.isEmpty) {
      _snack('Adicione pelo menos uma cidade antes de iniciar.', error: true);
      return;
    }
    setState(() {
      _monitorAtivo = true;
      _statusMsg = 'Monitor ativo — verificando...';
    });
    _rodarVerificacao();
    _timer = Timer.periodic(Duration(minutes: _intervaloMinutos), (_) => _rodarVerificacao());
  }

  void _pararMonitor() {
    _timer?.cancel();
    setState(() {
      _monitorAtivo = false;
      _statusMsg = 'Monitor pausado';
    });
  }

  Future<void> _rodarVerificacao() async {
    if (_verificando) return;
    setState(() {
      _verificando = true;
      _statusMsg = 'Consultando Receita Federal...';
    });
    try {
      final novas = await MonitorCnpjService.verificar(_cidades);
      setState(() {
        _novasHoje += novas;
        final hora = TimeOfDay.now().format(context);
        _statusMsg = 'Última verificação: $hora — $novas nova(s) empresa(s)';
      });
      if (novas > 0) {
        _snack('$novas nova(s) empresa(s) detectada(s)! 🎯');
      }
    } catch (e) {
      setState(() => _statusMsg = 'Erro na verificação. Tentando novamente...');
    } finally {
      setState(() => _verificando = false);
    }
  }

  // ─── Cidades ─────────────────────────────────────────────────────────────

  void _adicionarCidade() {
    final v = _cidadeController.text.trim();
    if (v.isEmpty) return;
    if (_cidades.contains(v)) {
      _snack('Cidade já adicionada.', error: true);
      return;
    }
    final novas = [..._cidades, v];
    MonitorCnpjService.salvarCidades(novas);
    _cidadeController.clear();
  }

  void _removerCidade(String cidade) {
    final novas = _cidades.where((c) => c != cidade).toList();
    MonitorCnpjService.salvarCidades(novas);
  }

  // ─── Consulta avulsa ─────────────────────────────────────────────────────

  Future<void> _consultar() async {
    final busca = _cnpjController.text.trim();
    if (busca.isEmpty) return;

    setState(() {
      _consultando = true;
      _resultadoConsulta = null;
      _erroConsulta = null;
    });

    final apenasNumeros = busca.replaceAll(RegExp(r'[^0-9]'), '');

    if (apenasNumeros.length == 14) {
      final resultado = await MonitorCnpjService.consultarCnpj(apenasNumeros);
      setState(() {
        _consultando = false;
        if (resultado != null) {
          _resultadoConsulta = resultado;
        } else {
          _erroConsulta = 'CNPJ não encontrado ou erro na consulta.';
        }
      });
    } else {
      final resultados = await MonitorCnpjService.buscarEmpresaPorNome(busca);
      setState(() {
        _consultando = false;
        if (resultados.isNotEmpty) {
          _resultadoConsulta = resultados.first;
        } else {
          _erroConsulta = 'Nenhuma empresa encontrada com este nome.';
        }
      });
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.statusConcorrente : AppColors.scoreHigh,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _ligar(String tel) async {
    final clean = tel.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('tel:+55$clean');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsapp(String tel) async {
    final clean = tel.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/55$clean');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _copiar(String v) {
    Clipboard.setData(ClipboardData(text: v));
    _snack('Copiado!');
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Configurar'),
                Tab(text: 'Alertas'),
                Tab(text: 'Consultar'),
              ],
            ),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildConfigurar(),
                  _buildAlertas(),
                  _buildConsultar(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      color: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Monitor de Empresas',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          const Text('Detecta novas empresas abertas por CNPJ',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 14),

          // Status bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                // Pulse indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _monitorAtivo ? const Color(0xFF16A34A) : Colors.white38,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _verificando ? 'Consultando Receita Federal...' : _statusMsg,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
                if (_verificando)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
                  ),
              ],
            ),
          ),

          // KPI row
          const SizedBox(height: 10),
          Row(
            children: [
              _headerKpi('Cidades', '${_cidades.length}', Icons.map_outlined),
              const SizedBox(width: 10),
              _headerKpi('Detectadas hoje', '$_novasHoje', Icons.business_outlined),
              const SizedBox(width: 10),
              StreamBuilder<int>(
                stream: MonitorCnpjService.streamNaoVistas(),
                builder: (_, snap) =>
                    _headerKpi('Não vistas', '${snap.data ?? 0}', Icons.notifications_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerKpi(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.accent),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Tab: Configurar ─────────────────────────────────────────────────────

  Widget _buildConfigurar() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Cidades
        const Text('Cidades monitoradas',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        const Text('Empresas abertas nessas cidades serão detectadas automaticamente.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _cidadeController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Ex: São Mateus do Sul',
                  prefixIcon: Icon(Icons.location_city_outlined, size: 20),
                ),
                onSubmitted: (_) => _adicionarCidade(),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _adicionarCidade,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (_cidades.isEmpty)
          _emptyInfo('Nenhuma cidade adicionada.', Icons.map_outlined)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _cidades.map((c) => Chip(
              label: Text(c, style: const TextStyle(fontSize: 13)),
              avatar: const Icon(Icons.location_on, size: 15, color: AppColors.primary),
              deleteIcon: const Icon(Icons.close, size: 15),
              onDeleted: () => _removerCidade(c),
              backgroundColor: Colors.white,
              side: const BorderSide(color: AppColors.divider),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            )).toList(),
          ),

        const SizedBox(height: 28),
        const Divider(color: AppColors.divider),
        const SizedBox(height: 20),

        // Intervalo
        const Text('Intervalo de verificação',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider),
          ),
          child: DropdownButton<int>(
            value: _intervaloMinutos,
            isExpanded: true,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 5, child: Text('A cada 5 minutes')),
              DropdownMenuItem(value: 15, child: Text('A cada 15 minutes')),
              DropdownMenuItem(value: 30, child: Text('A cada 30 minutes')),
              DropdownMenuItem(value: 60, child: Text('A cada 1 hour')),
              DropdownMenuItem(value: 360, child: Text('A cada 6 hours')),
              DropdownMenuItem(value: 1440, child: Text('A cada 24 hours')),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() => _intervaloMinutos = v);
                if (_monitorAtivo) {
                  _pararMonitor();
                  _iniciarMonitor();
                }
              }
            },
          ),
        ),

        const SizedBox(height: 28),

        // Botão principal
        SizedBox(
          width: double.infinity,
          child: _monitorAtivo
              ? OutlinedButton.icon(
            onPressed: _pararMonitor,
            icon: const Icon(Icons.pause_circle_outline),
            label: const Text('Pausar monitoramento'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.statusConcorrente,
              side: const BorderSide(color: AppColors.statusConcorrente),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          )
              : ElevatedButton.icon(
            onPressed: _iniciarMonitor,
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Iniciar monitoramento'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),

        if (_monitorAtivo) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _verificando ? null : _rodarVerificacao,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Verificar agora'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.statusNovaEmpresa.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.statusNovaEmpresa.withOpacity(0.2)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: AppColors.statusNovaEmpresa),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Empresas detectadas são salvas automaticamente na Carteira com status "Nova Empresa" e incluem endereço completo, telefone e e-mail cadastrados na Receita Federal.',
                  style: TextStyle(fontSize: 12, color: AppColors.statusNovaEmpresa),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Tab: Alertas ────────────────────────────────────────────────────────

  Widget _buildAlertas() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: MonitorCnpjService.streamDetectadas(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        final lista = snap.data ?? [];
        if (lista.isEmpty) {
          return _emptyInfo(
              'Nenhuma empresa detectada ainda.\nInicie o monitoramento na aba Configurar.',
              Icons.radar_outlined);
        }
        return Column(
          children: [
            // Mark all as read
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${lista.length} empresa(s) detectada(s)',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  TextButton(
                    onPressed: MonitorCnpjService.marcarTodasVistas,
                    child: const Text('Marcar todas como vistas',
                        style: TextStyle(fontSize: 12, color: AppColors.primary)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: lista.length,
                itemBuilder: (_, i) => _alertaCard(lista[i]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _alertaCard(Map<String, dynamic> data) {
    final visto = data['visto'] == true;
    final docId = data['id'] as String;
    final tel1 = data['telefone'] as String? ?? '';
    final tel2 = data['telefone2'] as String? ?? '';
    final email = data['email'] as String? ?? '';
    final endereco = data['enderecoCompleto'] as String? ?? '';
    final score = (data['score'] ?? 0).toDouble();
    final scoreColor = AppTheme.scoreColor(score);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: const BorderSide(color: AppColors.statusNovaEmpresa, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: visto ? Colors.transparent : AppColors.statusNovaEmpresa.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nome + Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['nome'] ?? '—',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'CNPJ: ${data['cnpj'] ?? '—'}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!visto)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.statusNovaEmpresa.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Nova', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.statusNovaEmpresa)),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: scoreColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.star, size: 11, color: scoreColor),
                        const SizedBox(width: 3),
                        Text('${score.toInt()}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: scoreColor)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 10),

            // Endereço
            if (endereco.isNotEmpty)
              _infoRow(Icons.location_on_outlined, 'Endereço', endereco, copiable: true, onCopy: () => _copiar(endereco)),

            // Telefone
            if (tel1.isNotEmpty)
              _infoRow(Icons.phone_outlined, 'Telefone principal', tel1, clickable: true, onTap: () => _ligar(tel1)),

            // Telefone 2
            if (tel2.isNotEmpty)
              _infoRow(Icons.phone_forwarded_outlined, 'Telefone 2', tel2, clickable: true, onTap: () => _ligar(tel2)),

            // Email
            if (email.isNotEmpty)
              _infoRow(Icons.email_outlined, 'E-mail', email, copiable: true, onCopy: () => _copiar(email)),

            // CNAE
            if ((data['cnae'] ?? '').isNotEmpty)
              _infoRow(Icons.category_outlined, 'Atividade', data['cnae'] ?? ''),

            // Data abertura
            if ((data['dataAbertura'] ?? '').isNotEmpty)
              _infoRow(Icons.calendar_today_outlined, 'Abertura', data['dataAbertura'] ?? ''),

            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 8),

            // Ações
            Row(
              children: [
                if (tel1.isNotEmpty) ...[
                  _actionBtn(
                    icon: Icons.chat_outlined,
                    label: 'WhatsApp',
                    color: const Color(0xFF16A34A),
                    onTap: () => _whatsapp(tel1),
                  ),
                  const SizedBox(width: 8),
                  _actionBtn(
                    icon: Icons.phone,
                    label: 'Ligar',
                    color: AppColors.primary,
                    onTap: () => _ligar(tel1),
                  ),
                  const SizedBox(width: 8),
                ],
                if (tel2.isNotEmpty) ...[
                  _actionBtn(
                    icon: Icons.phone_forwarded_outlined,
                    label: 'Tel 2',
                    color: AppColors.textSecondary,
                    onTap: () => _ligar(tel2),
                  ),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                if (!visto)
                  TextButton(
                    onPressed: () => MonitorCnpjService.marcarVista(docId),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Marcar vista', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ),
                IconButton(
                  onPressed: () => _confirmarDelete(docId),
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
      {bool copiable = false, bool clickable = false, VoidCallback? onCopy, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                GestureDetector(
                  onTap: onTap,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      color: clickable ? AppColors.primary : AppColors.textPrimary,
                      decoration: clickable ? TextDecoration.underline : TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (copiable && onCopy != null)
            GestureDetector(
              onTap: onCopy,
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.copy_outlined, size: 14, color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  void _confirmarDelete(String docId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover alerta'),
        content: const Text('Deseja remover este alerta do monitor? A empresa continuará na Carteira.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              MonitorCnpjService.deletarDetectada(docId);
            },
            child: const Text('Remover', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ─── Tab: Consultar ──────────────────────────────────────────────────────

  Widget _buildConsultar() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Consultar CNPJ ou Nome',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        const Text('Busca endereço, telefone e todos os dados cadastrais.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _cnpjController,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  hintText: 'Digite o CNPJ ou Nome da Empresa',
                  prefixIcon: Icon(Icons.search, size: 20),
                ),
                onSubmitted: (_) => _consultar(),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _consultando ? null : _consultar,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _consultando
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.search),
            ),
          ],
        ),

        const SizedBox(height: 16),

        if (_erroConsulta != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.statusConcorrente.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.statusConcorrente.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.statusConcorrente, size: 18),
                const SizedBox(width: 10),
                Text(_erroConsulta!, style: const TextStyle(color: AppColors.statusConcorrente, fontSize: 13)),
              ],
            ),
          ),

        if (_resultadoConsulta != null) _cardResultadoConsulta(_resultadoConsulta!),
      ],
    );
  }

  Widget _cardResultadoConsulta(EmpresaDetectada e) {
    final score = e.score;
    final scoreColor = AppTheme.scoreColor(score);

    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header colorido
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.razaoSocial,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                      if (e.nomeFantasia.isNotEmpty)
                        Text(e.nomeFantasia,
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text('CNPJ: ${e.cnpj}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'monospace')),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: scoreColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.star, size: 13, color: scoreColor),
                        const SizedBox(width: 4),
                        Text('${score.toInt()}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: scoreColor)),
                      ]),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: e.situacao == 'ATIVA'
                            ? AppColors.scoreHigh.withOpacity(0.1)
                            : AppColors.statusConcorrente.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        e.situacao.isNotEmpty ? e.situacao : '—',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: e.situacao == 'ATIVA' ? AppColors.scoreHigh : AppColors.statusConcorrente,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Endereço + Contato (destaque)
                if (e.enderecoCompleto.isNotEmpty)
                  _consultaInfoRow(Icons.location_on, 'Endereço completo', e.enderecoCompleto,
                      highlight: true, onCopy: () => _copiar(e.enderecoCompleto)),
                if (e.telefone1.isNotEmpty)
                  _consultaInfoRow(Icons.phone, 'Telefone principal', e.telefone1,
                      highlight: true, onTap: () => _ligar(e.telefone1)),
                if (e.telefone2.isNotEmpty)
                  _consultaInfoRow(Icons.phone_forwarded_outlined, 'Telefone 2', e.telefone2,
                      onTap: () => _ligar(e.telefone2)),
                if (e.email.isNotEmpty)
                  _consultaInfoRow(Icons.email_outlined, 'E-mail', e.email,
                      onCopy: () => _copiar(e.email)),

                const Divider(height: 20, color: AppColors.divider),

                _consultaInfoRow(Icons.category_outlined, 'CNAE / Atividade',
                    e.cnaeDescricao.isNotEmpty ? e.cnaeDescricao : e.cnae),
                _consultaInfoRow(Icons.calendar_today_outlined, 'Data de abertura', e.dataAbertura),
                _consultaInfoRow(Icons.business_outlined, 'Natureza jurídica', e.naturezaJuridica),
                _consultaInfoRow(Icons.corporate_fare_outlined, 'Porte', e.porte),
                _consultaInfoRow(Icons.attach_money, 'Capital social',
                    e.capitalSocial > 0 ? 'R\$ ${e.capitalSocial.toStringAsFixed(2).replaceAll('.', ',')}' : '—'),

                const SizedBox(height: 16),

                // Botões de ação
                Row(
                  children: [
                    if (e.telefone1.isNotEmpty) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _whatsapp(e.telefone1),
                          icon: const Icon(Icons.chat_outlined, size: 16),
                          label: const Text('WhatsApp', style: TextStyle(fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF16A34A),
                            side: const BorderSide(color: const Color(0xFF16A34A)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          // Aqui você pode decidir se quer salvar o que foi consultado
                          _snack('Empresa salva na Carteira!');
                        },
                        icon: const Icon(Icons.add_business_outlined, size: 16),
                        label: const Text('Salvar na Carteira', style: TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _consultaInfoRow(IconData icon, String label, String value,
      {bool highlight = false, VoidCallback? onTap, VoidCallback? onCopy}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: highlight ? AppColors.primary : AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                GestureDetector(
                  onTap: onTap,
                  child: Text(
                    value.isNotEmpty ? value : '—',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
                      color: onTap != null ? AppColors.primary : AppColors.textPrimary,
                      decoration: onTap != null ? TextDecoration.underline : TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (onCopy != null)
            GestureDetector(
              onTap: onCopy,
              child: const Padding(
                padding: EdgeInsets.only(left: 8, top: 2),
                child: Icon(Icons.copy_outlined, size: 15, color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Helpers visuais ─────────────────────────────────────────────────────

  Widget _emptyInfo(String msg, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.divider),
            const SizedBox(height: 16),
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
