import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../services/navigation_service.dart';
import '../theme/app_theme.dart';

class MapaScreen extends StatefulWidget {
  @override
  _MapaScreenState createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  Set<Marker> _markers = {};
  double _raioFiltro = 10000;
  Position? _minhaPosicao;
  String _filtroStatus = 'todos';
  bool _showFilters = false;
  int _totalVisible = 0;

  final List<Map<String, dynamic>> _raioOptions = [
    {'label': '2km', 'value': 2000.0},
    {'label': '5km', 'value': 5000.0},
    {'label': '10km', 'value': 10000.0},
    {'label': '25km', 'value': 25000.0},
  ];

  @override
  void initState() {
    super.initState();
    _determinarPosicao();
  }

  Future<void> _determinarPosicao() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() => _minhaPosicao = position);
    _carregarEmpresas();
  }

  double _getMarkerHue(String status) {
    switch (status) {
      case 'clienteBB_Minha': return BitmapDescriptor.hueAzure;
      case 'clienteBB_Outra': return BitmapDescriptor.hueYellow;
      case 'concorrente': return BitmapDescriptor.hueRed;
      case 'novaOportunidade': return BitmapDescriptor.hueViolet;
      default: return 200; // grey-ish
    }
  }

  void _carregarEmpresas() {
    FirebaseFirestore.instance.collection('clientes').snapshots().listen((snapshot) {
      Set<Marker> localMarkers = {};
      int count = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final GeoPoint? point = data['localizacao'];
        if (point == null) continue;

        if (_filtroStatus != 'todos' && data['status'] != _filtroStatus) continue;

        if (_minhaPosicao != null) {
          double distancia = Geolocator.distanceBetween(
            _minhaPosicao!.latitude, _minhaPosicao!.longitude,
            point.latitude, point.longitude,
          );
          if (distancia > _raioFiltro) continue;
        }

        count++;
        localMarkers.add(
          Marker(
            markerId: MarkerId(doc.id),
            position: LatLng(point.latitude, point.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(_getMarkerHue(data['status'] ?? '')),
            infoWindow: InfoWindow(
              title: data['nome'],
              snippet: "Toque para navegar",
              onTap: () => NavigationService.abrirRota(point, data['nome']),
            ),
          ),
        );
      }

      setState(() { _markers = localMarkers; _totalVisible = count; });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _minhaPosicao != null
                  ? LatLng(_minhaPosicao!.latitude, _minhaPosicao!.longitude)
                  : const LatLng(-29.6883, -53.8071),
              zoom: 13,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // Top overlay
          SafeArea(
            child: Column(
              children: [
                // Header bar
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.map_outlined, color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("GPS de Prospecção", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                            Text("$_totalVisible empresa(s) visível(is)", style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _showFilters = !_showFilters),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _showFilters ? AppColors.primary : AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _showFilters ? AppColors.primary : AppColors.divider),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.tune, size: 16, color: _showFilters ? Colors.white : AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text("Filtros", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _showFilters ? Colors.white : AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Filter panel
                if (_showFilters)
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Radius filter
                        const Text("Raio de busca", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        Row(
                          children: _raioOptions.map((opt) {
                            final sel = _raioFiltro == opt['value'];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () { setState(() => _raioFiltro = opt['value']); _carregarEmpresas(); },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: sel ? AppColors.primary : AppColors.surface,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: sel ? AppColors.primary : AppColors.divider),
                                  ),
                                  child: Text(opt['label'], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? Colors.white : AppColors.textSecondary)),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),
                        const Text("Status", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: [
                            _statusChip('todos', 'Todos', AppColors.primary),
                            _statusChip('clienteBB_Minha', 'Minha Carteira', AppColors.statusMinhaCarteira),
                            _statusChip('clienteBB_Outra', 'Outra Carteira', AppColors.statusOutraCarteira),
                            _statusChip('concorrente', 'Concorrente', AppColors.statusConcorrente),
                            _statusChip('novaOportunidade', 'Nova Empresa', AppColors.statusNovaEmpresa),
                            _statusChip('leadFrio', 'Lead Frio', AppColors.statusLeadFrio),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Bottom legend
          Positioned(
            bottom: 20, left: 12, right: 12,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -2))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _legendDot('Minha Cart.', AppColors.statusMinhaCarteira),
                  _legendDot('Outra Cart.', AppColors.statusOutraCarteira),
                  _legendDot('Concorrente', AppColors.statusConcorrente),
                  _legendDot('Nova Emp.', AppColors.statusNovaEmpresa),
                  _legendDot('Lead Frio', AppColors.statusLeadFrio),
                ],
              ),
            ),
          ),

          // My location FAB
          Positioned(
            bottom: 90, right: 16,
            child: FloatingActionButton.small(
              onPressed: _determinarPosicao,
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              elevation: 4,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String key, String label, Color color) {
    final sel = _filtroStatus == key;
    return GestureDetector(
      onTap: () { setState(() => _filtroStatus = key); _carregarEmpresas(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? color : AppColors.divider),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sel ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  Widget _legendDot(String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
    ],
  );
}
