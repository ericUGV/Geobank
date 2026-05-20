// lib/services/cnpj_service.dart
// ATUALIZADO: passa municipio e uf para ScoreService.calcularScore

import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'score_service.dart';

class CnpjService {
  static Future<Map<String, dynamic>?> buscarECadastrar(String cnpj) async {
    final cleanCnpj = cnpj.replaceAll(RegExp(r'[^0-9]'), '');
    final url = Uri.parse('https://brasilapi.com.br/api/cnpj/v1/$cleanCnpj');

    try {
      final response =
      await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Geocodificação
        GeoPoint geoPoint = const GeoPoint(0, 0);
        try {
          String endereco =
              "${data['logradouro']}, ${data['numero']}, ${data['municipio']} - ${data['uf']}";
          List<Location> locations = await locationFromAddress(endereco)
              .timeout(const Duration(seconds: 5));
          if (locations.isNotEmpty) {
            geoPoint =
                GeoPoint(locations.first.latitude, locations.first.longitude);
          }
        } catch (e) {
          // Geocodificação falhou — coordenada (0,0) usada
        }

        // Score com os 3 critérios (capital + CNAE + localização)
        final municipio = data['municipio']?.toString() ?? '';
        final uf = data['uf']?.toString() ?? '';
        double score = ScoreService.calcularScore(
          capitalSocial: (data['capital_social'] ?? 0).toDouble(),
          cnae: data['cnae_fiscal'].toString(),
          municipio: municipio,
          uf: uf,
        );

        final novaEmpresa = {
          'nome': data['razao_social'],
          'nomeFantasia': data['nome_fantasia'] ?? '',
          'cnpj': cleanCnpj,
          'cnae': data['cnae_fiscal_descricao'] ??
              data['cnae_fiscal'].toString(),
          'capitalSocial': data['capital_social'] ?? 0,
          'status': 'novaOportunidade',
          'localizacao': geoPoint,
          'dataAbertura': data['data_inicio_atividade'] != null
              ? Timestamp.fromDate(DateTime.parse(data['data_inicio_atividade']))
              : Timestamp.now(),
          'score': score,
          'logradouro': data['logradouro'] ?? '',
          'numero': data['numero'] ?? '',
          'complemento': data['complemento'] ?? '',
          'bairro': data['bairro'] ?? '',
          'municipio': municipio,
          'uf': uf,
          'cep': data['cep'] ?? '',
          'telefone': _parseTelefone(data, 'ddd_telefone_1'),
          'telefone2': _parseTelefone(data, 'ddd_telefone_2'),
          'email': data['email'] ?? '',
          'naturezaJuridica': data['descricao_natureza_juridica'] ?? '',
          'porte': data['descricao_porte'] ?? '',
          'situacao': data['descricao_situacao_cadastral'] ?? '',
          'enderecoCompleto': _montarEndereco(data),
        };

        await FirebaseFirestore.instance
            .collection('clientes')
            .add(novaEmpresa);
        return novaEmpresa;
      }
    } on TimeoutException {
      // Timeout silencioso
    } catch (e) {
      // Erro genérico
    }
    return null;
  }

  static String _montarEndereco(Map<String, dynamic> data) {
    final parts = <String>[];
    if ((data['logradouro'] ?? '').isNotEmpty) parts.add(data['logradouro']);
    if ((data['numero'] ?? '').isNotEmpty) parts.add('nº ${data['numero']}');
    if ((data['bairro'] ?? '').isNotEmpty) parts.add(data['bairro']);
    if ((data['municipio'] ?? '').isNotEmpty) {
      parts.add('${data['municipio']}/${data['uf'] ?? ''}');
    }
    if ((data['cep'] ?? '').isNotEmpty) parts.add('CEP ${data['cep']}');
    return parts.join(', ');
  }

  static String _parseTelefone(Map<String, dynamic> data, String campo) {
    final raw = (data[campo] ?? '').toString().trim();
    if (raw.isEmpty) return '';
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 11) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7)}';
    } else if (digits.length == 10) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 6)}-${digits.substring(6)}';
    }
    return raw;
  }
}