import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GooglePlacesService {
  // Chave extraída do AndroidManifest.xml
  static const String _apiKey = 'AIzaSyA6mg6A35NyN9FJf3BtZFFmCnGI7I60LLs';

  static Future<List<Map<String, dynamic>>> buscarEmpresas(String query, {LatLng? userLocation}) async {
    if (query.isEmpty) return [];

    String url = 'https://maps.googleapis.com/maps/api/place/textsearch/json?query=$query&key=$_apiKey&language=pt-BR';
    
    if (userLocation != null) {
      url += '&location=${userLocation.latitude},${userLocation.longitude}&radius=10000';
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;
        
        return results.map((item) {
          return {
            'place_id': item['place_id'],
            'nome': item['name'],
            'endereco': item['formatted_address'],
            'lat': item['geometry']['location']['lat'],
            'lng': item['geometry']['location']['lng'],
            'rating': item['rating'],
            'types': item['types'],
          };
        }).toList();
      }
    } catch (e) {
      print('Erro ao buscar no Google Places: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>?> obterDetalhes(String placeId) async {
    final url = 'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=name,formatted_address,geometry,formatted_phone_number,website,opening_hours&key=$_apiKey&language=pt-BR';
    
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['result'];
      }
    } catch (e) {
      print('Erro ao obter detalhes do local: $e');
    }
    return null;
  }
}
