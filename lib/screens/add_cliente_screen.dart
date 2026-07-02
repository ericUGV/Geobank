// lib/screens/add_cliente_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/score_service.dart';
import '../services/cnpj_service.dart';
import '../services/google_places_service.dart';
import '../theme/app_theme.dart';

class AddClienteScreen extends StatefulWidget {
  @override
  _AddClienteScreenState createState() => _AddClienteScreenState();
}

class _AddClienteScreenState extends State<AddClienteScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Aba Recentes (30 dias) ────────────────────────────────────────────────
  List<Map<String, dynamic>> _recentes = [];
  bool _buscandoRecentes = false;
  String _cidadeAtual = 'Detectando...';

  // ── Aba Google Maps ────────────────────────────────────────────────────────
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _googleResults = [];
  bool _isSearchingGoogle = false;

  // ── Aba CNPJ ──────────────────────────────────────────────────────────────
  final _cnpjController = TextEditingController();
  bool _buscandoCnpj = false;

  // ── Aba Manual ─────────────────────────────────────────────────────────────
  final _nomeController = TextEditingController();
  final _logradouroController = TextEditingController();
  final _municipioController = TextEditingController();
  final _ufController = TextEditingController();
  String _statusManual = 'novaOportunidade';
  bool _salvandoManual = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _carregarRecentes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _cnpjController.dispose();
    _nomeController.dispose();
    _logradouroController.dispose();
    _municipioController.dispose();
    _ufController.dispose();
    super.dispose();
  }

  // ── Lógica de Busca Recentes ───────────────────────────────────────────────

  Future<void> _carregarRecentes() async {
    setState(() {
      _buscandoRecentes = true;
      _recentes = [];
    });

    try {
      // 1. Obter Localização e Cidade Atual
      Position pos = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      String cidade = placemarks.first.subAdministrativeArea ?? placemarks.first.locality ?? "sua cidade";
      
      if (!mounted) return;
      setState(() => _cidadeAtual = cidade);

      // 2. Buscar Empresas do Monitor (CNPJ) - Últimos 30 dias na cidade
      DateTime trintaDiasAtras = DateTime.now().subtract(const Duration(days: 30));
      final querySnapshot = await FirebaseFirestore.instance
          .collection('empresas_detectadas')
          .where('municipio', isEqualTo: cidade.toUpperCase())
          .where('detectadaEm', isGreaterThanOrEqualTo: Timestamp.fromDate(trintaDiasAtras))
          .limit(20)
          .get();

      // 3. Buscar no Google Maps por novos locais
      final googleNovos = await GooglePlacesService.buscarEmpresas("novas empresas em $cidade", 
          userLocation: LatLng(pos.latitude, pos.longitude));

      List<Map<String, dynamic>> combinados = [];

      // Mapear dados do Firestore (CNPJ)
      for (var doc in querySnapshot.docs) {
        final d = doc.data();
        combinados.add({
          'nome': d['nome'] ?? 'Empresa s/ Nome',
          'endereco': d['enderecoCompleto'] ?? '',
          'tipo': 'CNPJ Oficial',
          'cnpj': d['cnpj'],
          'isCnpj': true,
          'lat': (d['localizacao'] as GeoPoint).latitude,
          'lng': (d['localizacao'] as GeoPoint).longitude,
        });
      }

      // Mapear dados do Google
      for (var p in googleNovos) {
        combinados.add({
          'nome': p['nome'],
          'endereco': p['endereco'],
          'tipo': 'Google Maps',
          'place_id': p['place_id'],
          'isCnpj': false,
          'lat': p['lat'],
          'lng': p['lng'],
        });
      }

      if (!mounted) return;
      setState(() {
        _recentes = combinados;
        _buscandoRecentes = false;
      });
    } catch (e) {
      if (mounted) setState(() => _buscandoRecentes = false);
    }
  }

  // ── Métodos de Ação ────────────────────────────────────────────────────────

  Future<void> _addFromGoogle(Map<String, dynamic> item) async {
    final user = FirebaseAuth.instance.currentUser;
    final details = await GooglePlacesService.obterDetalhes(item['place_id'] ?? '');

    await FirebaseFirestore.instance.collection('clientes').add({
      'nome': item['nome'],
      'enderecoCompleto': item['endereco'],
      'localizacao': GeoPoint(item['lat'], item['lng']),
      'status': 'novaOportunidade',
      'gerenteId': user?.uid,
      'bancoDomicilio': 'Outro',
      'telefone': details?['formatted_phone_number'] ?? '',
      'dataAdicao': FieldValue.serverTimestamp(),
      'score': 70.0,
    });

    _snack('Empresa adicionada à sua carteira!');
    Navigator.pop(context);
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : const Color(0xFF16A34A),
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build UI ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Adicionar Cliente'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.accent,
          tabs: const [
            Tab(icon: Icon(Icons.bolt, color: Colors.amber), text: 'Recentes (30d)'),
            Tab(icon: Icon(Icons.search), text: 'Google Maps'),
            Tab(icon: Icon(Icons.qr_code), text: 'CNPJ'),
            Tab(icon: Icon(Icons.edit), text: 'Manual'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRecentesTab(),
          _buildGoogleTab(),
          _buildCnpjTab(),
          _buildManualTab(),
        ],
      ),
    );
  }

  Widget _buildRecentesTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: AppColors.primary.withOpacity(0.05),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Novidades em $_cidadeAtual', 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
              ),
              IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _carregarRecentes),
            ],
          ),
        ),
        if (_buscandoRecentes)
          const Expanded(child: Center(child: CircularProgressIndicator())),
        if (!_buscandoRecentes && _recentes.isEmpty)
          const Expanded(child: Center(child: Text('Nenhuma empresa recente encontrada.'))),
        if (!_buscandoRecentes && _recentes.isNotEmpty)
          Expanded(
            child: ListView.builder(
              itemCount: _recentes.length,
              itemBuilder: (context, index) {
                final item = _recentes[index];
                final bool isCnpj = item['isCnpj'];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isCnpj ? Colors.orange : AppColors.primary,
                    child: Icon(isCnpj ? Icons.business : Icons.place, color: Colors.white, size: 16),
                  ),
                  title: Text(item['nome'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('${item['tipo']} • ${item['endereco']}', maxLines: 2, style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                  onTap: () {
                    if (isCnpj) {
                      _cnpjController.text = item['cnpj'];
                      _tabController.animateTo(2);
                    } else {
                      _addFromGoogle(item);
                    }
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildGoogleTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: _inputDecor('Buscar por nome no Google...', Icons.search).copyWith(
              suffixIcon: IconButton(icon: const Icon(Icons.send), onPressed: () async {
                setState(() => _isSearchingGoogle = true);
                _googleResults = await GooglePlacesService.buscarEmpresas(_searchController.text);
                setState(() => _isSearchingGoogle = false);
              }),
            ),
          ),
        ),
        if (_isSearchingGoogle) const Expanded(child: Center(child: CircularProgressIndicator())),
        if (!_isSearchingGoogle)
          Expanded(
            child: ListView.builder(
              itemCount: _googleResults.length,
              itemBuilder: (ctx, i) => ListTile(
                title: Text(_googleResults[i]['nome']),
                subtitle: Text(_googleResults[i]['endereco']),
                trailing: const Icon(Icons.add, color: AppColors.primary),
                onTap: () => _addFromGoogle(_googleResults[i]),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCnpjTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          TextField(controller: _cnpjController, decoration: _inputDecor('Digite o CNPJ', Icons.badge)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              setState(() => _buscandoCnpj = true);
              final res = await CnpjService.buscarECadastrar(_cnpjController.text);
              setState(() => _buscandoCnpj = false);
              if (res != null) {
                _snack('Cliente cadastrado!');
                Navigator.pop(context);
              }
            },
            child: Text(_buscandoCnpj ? 'Buscando...' : 'Buscar e Adicionar'),
          ),
        ],
      ),
    );
  }

  Widget _buildManualTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          TextField(controller: _nomeController, decoration: _inputDecor('Razão Social', Icons.business)),
          const SizedBox(height: 12),
          TextField(controller: _logradouroController, decoration: _inputDecor('Endereço', Icons.map)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              await FirebaseFirestore.instance.collection('clientes').add({
                'nome': _nomeController.text,
                'status': _statusManual,
                'gerenteId': user?.uid,
                'dataAdicao': FieldValue.serverTimestamp(),
              });
              Navigator.pop(context);
            },
            child: const Text('Salvar Cliente'),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecor(String hint, IconData icon) => InputDecoration(
    hintText: hint, prefixIcon: Icon(icon, color: AppColors.textSecondary),
    filled: true, fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
  );
}
