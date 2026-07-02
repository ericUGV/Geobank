// lib/screens/mapa_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../services/navigation_service.dart';
import '../theme/app_theme.dart';
import 'rota_multipla_screen.dart';
import 'add_cliente_screen.dart';

class MapaScreen extends StatefulWidget {
  @override
  _MapaScreenState createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  StreamSubscription<QuerySnapshot>? _subscription;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  Set<Marker> _markers = {};
  double _raioFiltro = 10000;
  Position? _minhaPosicao;
  String _filtroStatus = 'todos';
  String _filtroBanco = 'todos';
  String _filtroCnae = 'todos';
  String _filtroVisita = 'todos';
  bool _showFilters = false;
  int _totalVisible = 0;

  final List<Map<String, dynamic>> _raioOptions = [
    {'label': '2km',  'value': 2000.0},
    {'label': '5km',  'value': 5000.0},
    {'label': '10km', 'value': 10000.0},
    {'label': '25km', 'value': 25000.0},
  ];

  @override
  void initState() {
    super.initState();
    _determinarPosicao();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _determinarPosicao() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    final position = await Geolocator.getCurrentPosition();
    if (!mounted) return;
    setState(() => _minhaPosicao = position);
    _carregarEmpresas();
  }

  double _getMarkerHue(String status, String? gerenteId) {
    // Lógica para diferenciar Minha Carteira de Outras
    if (status == 'clienteBB_Minha' || status == 'clienteBB_Outra') {
      if (gerenteId == _currentUserId) {
        return BitmapDescriptor.hueAzure; // Azul para Minha Carteira
      } else {
        return BitmapDescriptor.hueYellow; // Amarelo para Outros Usuários
      }
    }
    
    switch (status) {
      case 'concorrente':       return BitmapDescriptor.hueRed;
      case 'novaOportunidade':  return BitmapDescriptor.hueViolet;
      case 'leadFrio':          return BitmapDescriptor.hueMagenta;
      default:                  return BitmapDescriptor.hueCyan;
    }
  }

  void _carregarEmpresas() {
    _subscription?.cancel();

    _subscription = FirebaseFirestore.instance
        .collection('clientes')
        .snapshots()
        .listen((snapshot) {
      final Set<Marker> localMarkers = {};
      int count = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final GeoPoint? point = data['localizacao'];
        if (point == null || (point.latitude == 0 && point.longitude == 0)) continue;

        final status = data['status'] ?? '';
        final gerenteId = data['gerenteId'];

        // Lógica de filtro de status considerando propriedade
        if (_filtroStatus != 'todos') {
          if (_filtroStatus == 'clienteBB_Minha' && (status != 'clienteBB_Minha' || gerenteId != _currentUserId)) continue;
          if (_filtroStatus == 'clienteBB_Outra' && (status != 'clienteBB_Outra' && status != 'clienteBB_Minha' || gerenteId == _currentUserId)) continue;
          if (_filtroStatus != 'clienteBB_Minha' && _filtroStatus != 'clienteBB_Outra' && status != _filtroStatus) continue;
        }

        if (_minhaPosicao != null) {
          final distancia = Geolocator.distanceBetween(
            _minhaPosicao!.latitude, _minhaPosicao!.longitude,
            point.latitude, point.longitude,
          );
          if (distancia > _raioFiltro) continue;
        }

        count++;
        localMarkers.add(Marker(
          markerId: MarkerId(doc.id),
          position: LatLng(point.latitude, point.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(_getMarkerHue(status, gerenteId)),
          infoWindow: InfoWindow(
            title: data['nome'],
            snippet: gerenteId == _currentUserId 
                ? 'Sua Carteira - Toque para navegar' 
                : 'Carteira de Outro Gerente',
            onTap: () => NavigationService.abrirRota(point, data['nome']),
          ),
        ));
      }

      if (!mounted) return;
      setState(() {
        _markers = localMarkers;
        _totalVisible = count;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _minhaPosicao != null
                  ? LatLng(_minhaPosicao!.latitude, _minhaPosicao!.longitude)
                  : const LatLng(-25.8733, -50.3867),
              zoom: 13,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                if (_showFilters) _buildFilters(),
              ],
            ),
          ),

          // Legenda Inferior
          Positioned(
            bottom: 20, left: 12, right: 12,
            child: _buildLegend(),
          ),

          // Botão Adicionar Flutuante
          Positioned(
            bottom: 90, right: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'loc',
                  onPressed: _determinarPosicao,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.my_location, color: AppColors.primary),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'add',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddClienteScreen())),
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Row(
        children: [
          const Icon(Icons.radar, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mapa de Prospecção', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('$_totalVisible empresas encontradas', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(_showFilters ? Icons.close : Icons.filter_list),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filtrar por Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              _filterChip('todos', 'Todos'),
              _filterChip('clienteBB_Minha', 'Minha Carteira'),
              _filterChip('clienteBB_Outra', 'Outras Carteiras'),
              _filterChip('novaOportunidade', 'Oportunidades'),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Raio de Busca', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Row(
            children: _raioOptions.map((opt) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(opt['label']),
                selected: _raioFiltro == opt['value'],
                onSelected: (s) { if(s) setState(() => _raioFiltro = opt['value']); _carregarEmpresas(); },
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String status, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _filtroStatus == status,
      onSelected: (s) { if(s) setState(() => _filtroStatus = status); _carregarEmpresas(); },
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _legendItem('Minha', Colors.blue),
          _legendItem('Outros', Colors.yellow),
          _legendItem('Nova', Colors.purple),
          _legendItem('Concorrente', Colors.red),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Icon(Icons.location_on, color: color, size: 16),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
