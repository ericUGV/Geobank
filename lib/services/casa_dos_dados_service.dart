import 'dart:convert';
import 'package:http/http.dart' as http;

class CasaDosDadosService {
  static const String _baseUrl = 'https://api.casadosdados.com.br/v1/search';
  // IMPORTANTE: Verifique se este token é válido e possui saldo para pesquisa avançada
  static const String _token = 'ca674f84222a175f5d4d03e1ea765d1ab98d5655e7031ae122aa4a9ccc34d3c2ae451699d47327812f1ce286fa5a3171daaf90b3df6a1360146bd03232c7ccc6';

  static Future<List<Map<String, dynamic>>> pesquisarAvancada({
    String? municipio,
    String? uf,
    String? cnae,
    double? capitalMinimo,
    int? diasAtras,
    String situacao = "ATIVA",
    int page = 1,
  }) async {
    final Map<String, dynamic> filters = {
      "situacao_cadastral": situacao,
    };

    if (municipio != null && municipio.isNotEmpty) {
      filters["municipio"] = [municipio.toUpperCase()];
    }
    if (uf != null && uf.isNotEmpty) {
      filters["uf"] = [uf.toUpperCase()];
    }
    if (cnae != null && cnae.isNotEmpty) {
      filters["cnae_principal"] = [cnae];
    }
    if (capitalMinimo != null) {
      filters["capital_social"] = {"desde": capitalMinimo};
    }
    if (diasAtras != null) {
      final dataInicio = DateTime.now().subtract(Duration(days: diasAtras));
      final dataFim = DateTime.now();
      filters["data_abertura"] = {
        "desde": "${dataInicio.year}-${dataInicio.month.toString().padLeft(2, '0')}-${dataInicio.day.toString().padLeft(2, '0')}",
        "ate": "${dataFim.year}-${dataFim.month.toString().padLeft(2, '0')}-${dataFim.day.toString().padLeft(2, '0')}"
      };
    }

    final payload = {
      "filters": filters,
      "page": page.toString()
    };

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
          'x-api-key': _token, // Algumas versões da API usam este header
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Mapeamento ultra-robusto para diferentes versões da API
        List<dynamic> lista = [];
        if (data is List) {
          lista = data;
        } else if (data is Map) {
          final possibleKeys = ['data', 'items', 'rows', 'results', 'empresas'];
          for (var key in possibleKeys) {
            if (data[key] is List) {
              lista = data[key];
              break;
            } else if (data[key] is Map && data[key]['items'] is List) {
              lista = data[key]['items'];
              break;
            }
          }
          // Se ainda não achou, e o root tiver um campo 'success' ou similar mas a lista estiver solta
          if (lista.isEmpty && data.values.any((v) => v is List)) {
             lista = data.values.firstWhere((v) => v is List);
          }
        }

        return lista.map((e) => e as Map<String, dynamic>).toList();
      } else {
        // Log detalhado para você ver no console do VS Code / Android Studio
        print('--- ERRO CASA DOS DADOS ---');
        print('Status: ${response.statusCode}');
        print('Corpo: ${response.body}');
        print('---------------------------');
        
        if (response.statusCode == 401 || response.statusCode == 403) {
          throw Exception('Token inválido, expirado ou sem saldo.');
        }
        throw Exception('Erro ${response.statusCode} na API.');
      }
    } catch (e) {
      print('Erro ao consultar Casa dos Dados: $e');
      rethrow;
    }
  }
}
