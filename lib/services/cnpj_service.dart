import 'dart:convert';
import 'dart:async'; // Para Timeout
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'score_service.dart';

class CnpjService {
  static Future<Map<String, dynamic>?> buscarECadastrar(String cnpj) async {
    final cleanCnpj = cnpj.replaceAll(RegExp(r'[^0-9]'), '');
    final url = Uri.parse('https://brasilapi.com.br/api/cnpj/v1/$cleanCnpj');

    try {
      // Adicionado timeout de 15 segundos para não ficar carregando infinito
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // 1. Geocodificação com tratamento de erro
        GeoPoint geoPoint = const GeoPoint(0, 0);
        try {
          String endereco = "${data['logradouro']}, ${data['numero']}, ${data['municipio']} - ${data['uf']}";
          List<Location> locations = await locationFromAddress(endereco).timeout(const Duration(seconds: 5));
          if (locations.isNotEmpty) {
            geoPoint = GeoPoint(locations.first.latitude, locations.first.longitude);
          }
        } catch (e) {
          print("Erro na geocodificação: $e. Usando coordenadas (0,0)");
        }

        double score = ScoreService.calcularScore(
          capitalSocial: (data['capital_social'] ?? 0).toDouble(),
          cnae: data['cnae_fiscal'].toString(),
        );

        final novaEmpresa = {
          'nome': data['razao_social'],
          'cnpj': cleanCnpj,
          'cnae': data['cnae_fiscal'].toString(),
          'capitalSocial': data['capital_social'] ?? 0,
          'status': 'novaOportunidade',
          'localizacao': geoPoint,
          'dataAbertura': DateTime.parse(data['data_inicio_atividade'] ?? DateTime.now().toString()),
          'score': score,
        };

        await FirebaseFirestore.instance.collection('clientes').add(novaEmpresa);
        return novaEmpresa;
      }
    } on TimeoutException {
      print("Tempo de busca esgotado");
    } catch (e) {
      print("Erro geral: $e");
    }
    return null;
  }
}
