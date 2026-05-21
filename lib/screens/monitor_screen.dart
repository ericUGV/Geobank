import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/app_theme.dart';
import '../services/monitor_cnpj_service.dart';

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _monitorAtivo = false;
  bool _verificando = false;
  String _statusMsg = 'Monitor inativo';
  int _novasHoje = 0;
  Timer? _timer;

  final _cidadeController = TextEditingController();
  final _cnpjController = TextEditingController();
  List<String> _cidades = [];
  bool _consultando = false;
  EmpresaDetectada? _resultadoConsulta;
  String? _erroConsulta;

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

  void _confirmarSair() {
    FirebaseAuth.instance.signOut();
  }

  Future<void> _consultar() async {
    final busca = _cnpjController.text.trim();
    if (busca.isEmpty) return;
    setState(() { _consultando = true; _resultadoConsulta = null; _erroConsulta = null; });

    final apenasNumeros = busca.replaceAll(RegExp(r'[^0-9]'), '');
    if (apenasNumeros.length == 14) {
      final res = await MonitorCnpjService.consultarCnpj(apenasNumeros);
      setState(() {
        _consultando = false;
        if (res != null) _resultadoConsulta = res;
        else _erroConsulta = 'CNPJ não encontrado.';
      });
    } else {
      final res = await MonitorCnpjService.buscarEmpresaPorNome(busca);
      setState(() {
        _consultando = false;
        if (res.isNotEmpty) _resultadoConsulta = res.first;
        else _erroConsulta = 'Nome não encontrado no banco.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text("Monitor de Prospecção"),
        actions: [IconButton(onPressed: _confirmarSair, icon: const Icon(Icons.logout))],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Config'), Tab(text: 'Alertas'), Tab(text: 'Busca')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildConfig(),
          _buildAlertas(),
          _buildBusca(),
        ],
      ),
    );
  }

  Widget _buildConfig() => const Center(child: Text("Configure as cidades monitoradas aqui"));

  Widget _buildAlertas() => const Center(child: Text("Alertas de novas empresas detectadas"));

  Widget _buildBusca() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: _cnpjController,
          decoration: InputDecoration(
            hintText: "CNPJ ou Nome da Empresa",
            suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _consultar),
          ),
          onSubmitted: (_) => _consultar(),
        ),
        const SizedBox(height: 20),
        if (_consultando) const LinearProgressIndicator(),
        if (_erroConsulta != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(_erroConsulta!, style: const TextStyle(color: Colors.red)),
          ),
        if (_resultadoConsulta != null) Card(
          child: ListTile(
            title: Text(_resultadoConsulta!.razaoSocial),
            subtitle: Text("CNPJ: ${_resultadoConsulta!.cnpj}"),
            trailing: IconButton(
                icon: const Icon(Icons.add_business, color: AppColors.primary),
                onPressed: () async {
                  await MonitorCnpjService.adicionarACarteira(_resultadoConsulta!);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Empresa salva na carteira!"))
                  );
                }
            ),
          ),
        )
      ],
    );
  }
}
