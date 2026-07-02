// lib/services/cnpj_service.dart

import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'score_service.dart';

class CnpjService {
  static Future<Map<String, dynamic>?> buscarECadastrar(String cnpj) async {
    final cleanCnpj = cnpj.replaceAll(RegExp(r'[^0-9]'), '');
    final url = Uri.parse('https://brasilapi.com.br/api/cnpj/v1/$cleanCnpj');
    final user = FirebaseAuth.instance.currentUser;

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        GeoPoint geoPoint = const GeoPoint(0, 0);
        try {
          String endereco = "${data['logradouro']}, ${data['numero']}, ${data['municipio']} - ${data['uf']}";
          List<Location> locations = await locationFromAddress(endereco).timeout(const Duration(seconds: 5));
          if (locations.isNotEmpty) {
            geoPoint = GeoPoint(locations.first.latitude, locations.first.longitude);
          }
        } catch (e) {}

        final municipio = data['municipio']?.toString() ?? '';
        final uf = data['uf']?.toString() ?? '';
        double score = ScoreService.calcularScore(
          capitalSocial: (data['capital_social'] ?? 0).toDouble(),
          cnae: data['cnae_fiscal']?.toString() ?? '',
          municipio: municipio,
          uf: uf,
        );

        final novaEmpresa = {
          'nome': data['razao_social'],
          'nomeFantasia': data['nome_fantasia'] ?? '',
          'cnpj': cleanCnpj,
          'cnae': data['cnae_fiscal_descricao'] ?? data['cnae_fiscal']?.toString() ?? '',
          'capitalSocial': data['capital_social'] ?? 0,
          'status': 'novaOportunidade',
          'gerenteId': user?.uid, // Vínculo com o usuário atual
          'localizacao': geoPoint,
          'score': score,
          'municipio': municipio,
          'uf': uf,
          'enderecoCompleto': _montarEndereco(data),
          'dataAdicao': FieldValue.serverTimestamp(),
        };

        await FirebaseFirestore.instance.collection('clientes').add(novaEmpresa);
        return novaEmpresa;
      }
    } catch (e) {}
    return null;
  }

  static String _montarEndereco(Map<String, dynamic> data) {
    final parts = <String>[];
    if ((data['logradouro'] ?? '').isNotEmpty) parts.add(data['logradouro']);
    if ((data['numero'] ?? '').isNotEmpty) parts.add('nº ${data['numero']}');
    if ((data['bairro'] ?? '').isNotEmpty) parts.add(data['bairro']);
    if ((data['municipio'] ?? '').isNotEmpty) parts.add('${data['municipio']}/${data['uf'] ?? ''}');
    return parts.join(', ');
  }
}
