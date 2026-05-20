import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/cliente_service.dart';
import '../utils/map_utils.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  Set<Marker> markers = {};
  final service = ClienteService();

  @override
  void initState() {
    super.initState();
    carregar();
  }

  void carregar() async {
    final docs = await service.getClientes();

    Set<Marker> temp = {};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;

      temp.add(
        Marker(
          markerId: MarkerId(doc.id),
          position: LatLng(data['lat'], data['lng']),
          icon: getCorMarker(data['status']),
          infoWindow: InfoWindow(
            title: data['nome'],
            snippet: data['banco'],
          ),
        ),
      );
    }

    setState(() => markers = temp);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Mapa")),
      body: GoogleMap(
        initialCameraPosition:
        CameraPosition(target: LatLng(-25.42, -49.27), zoom: 14),
        markers: markers,
        myLocationEnabled: true,
      ),
    );
  }
}