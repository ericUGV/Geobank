import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NavigationService {
  // Abre o Google Maps com a rota traçada até a Latitude e Longitude da empresa
  static Future<void> abrirRota(GeoPoint destino, String nomeEmpresa) async {
    final double lat = destino.latitude;
    final double lng = destino.longitude;

    // URL para Google Maps (Funciona em Android e iOS)
    final Uri googleMapsUrl = Uri.parse(
      "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving"
    );

    // Tenta abrir a URL
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      throw 'Não foi possível abrir o mapa.';
    }
  }

  // Gera uma rota otimizada para múltiplas empresas (Módulo 2 da proposta)
  static Future<void> abrirRotaMultipla(List<GeoPoint> destinos) async {
    if (destinos.isEmpty) return;

    String waypoints = "";
    // O último destino da lista será o destino final, os outros são paradas (waypoints)
    for (int i = 0; i < destinos.length - 1; i++) {
      waypoints += "${destinos[i].latitude},${destinos[i].longitude}|";
    }

    final GeoPoint ultimo = destinos.last;
    final String url = "https://www.google.com/maps/dir/?api=1&destination=${ultimo.latitude},${ultimo.longitude}&waypoints=$waypoints&travelmode=driving";

    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
