import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'score_service.dart';

/// Representa uma empresa detectada pelo monitoramento
class EmpresaDetectada {
  final String cnpj;
  final String razaoSocial;
  final String nomeFantasia;
  final String cnae;
  final String cnaeDescricao;
  final String dataAbertura;
  final String situacao;
  final String naturezaJuridica;
  final String porte;
  final double capitalSocial;

  // Contato e endereço
  final String logradouro;
  final String numero;
  final String complemento;
  final String bairro;
  final String municipio;
  final String uf;
  final String cep;
  final String telefone1;
  final String telefone2;
  final String email;

  final String cidadeMonitorada;
  final DateTime detectadaEm;
  final double score;

  EmpresaDetectada({
    required this.cnpj,
    required this.razaoSocial,
    required this.nomeFantasia,
    required this.cnae,
    required this.cnaeDescricao,
    required this.dataAbertura,
    required this.situacao,
    required this.naturezaJuridica,
    required this.porte,
    required this.capitalSocial,
    required this.logradouro,
    required this.numero,
    required this.complemento,
    required this.bairro,
    required this.municipio,
    required this.uf,
    required this.cep,
    required this.telefone1,
    required this.telefone2,
    required this.email,
    required this.cidadeMonitorada,
    required this.detectadaEm,
    required this.score,
  });

  /// Endereço completo formatado
  String get enderecoCompleto {
    final parts = <String>[];
    if (logradouro.isNotEmpty) parts.add(logradouro);
    if (numero.isNotEmpty) parts.add('nº $numero');
    if (complemento.isNotEmpty) parts.add(complemento);
    if (bairro.isNotEmpty) parts.add(bairro);
    if (municipio.isNotEmpty) parts.add('$municipio/$uf');
    if (cep.isNotEmpty) parts.add('CEP $cep');
    return parts.join(', ');
  }

  Map<String, dynamic> toFirestore(GeoPoint geoPoint) => {
    'nome': razaoSocial,
    'nomeFantasia': nomeFantasia,
    'cnpj': cnpj,
    'cnae': cnae,
    'cnaeDescricao': cnaeDescricao,
    'status': 'novaOportunidade',
    'score': score,
    'capitalSocial': capitalSocial,
    'naturezaJuridica': naturezaJuridica,
    'porte': porte,
    'situacao': situacao,
    'dataAbertura': dataAbertura,
    // Endereço detalhado
    'logradouro': logradouro,
    'numero': numero,
    'complemento': complemento,
    'bairro': bairro,
    'municipio': municipio,
    'uf': uf,
    'cep': cep,
    'enderecoCompleto': enderecoCompleto,
    // Contato
    'telefone': telefone1,
    'telefone2': telefone2,
    'email': email,
    // Geo
    'localizacao': geoPoint,
    // Meta
    'cidadeMonitorada': cidadeMonitorada,
    'detectadaEm': Timestamp.fromDate(detectadaEm),
    'visto': false,
    'origemMonitor': true,
  };

  factory EmpresaDetectada.fromApi(Map<String, dynamic> data, String cidade) {
    final capital = (data['capital_social'] ?? 0).toDouble();
    final cnae = data['cnae_fiscal']?.toString() ?? '';
    return EmpresaDetectada(
      cnpj: data['cnpj'] ?? '',
      razaoSocial: data['razao_social'] ?? '',
      nomeFantasia: data['nome_fantasia'] ?? '',
      cnae: cnae,
      cnaeDescricao: data['cnae_fiscal_descricao'] ?? data['descricao_cnae_principal'] ?? '',
      dataAbertura: data['data_inicio_atividade'] ?? '',
      situacao: data['descricao_situacao_cadastral'] ?? '',
      naturezaJuridica: data['descricao_natureza_juridica'] ?? '',
      porte: data['descricao_porte'] ?? '',
      capitalSocial: capital,
      logradouro: data['logradouro'] ?? '',
      numero: data['numero'] ?? '',
      complemento: data['complemento'] ?? '',
      bairro: data['bairro'] ?? '',
      municipio: data['municipio'] ?? cidade,
      uf: data['uf'] ?? '',
      cep: data['cep'] ?? '',
      telefone1: _parseTelefone(data, 'ddd_telefone_1'),
      telefone2: _parseTelefone(data, 'ddd_telefone_2'),
      email: data['email'] ?? '',
      cidadeMonitorada: cidade,
      detectadaEm: DateTime.now(),
      score: ScoreService.calcularScore(capitalSocial: capital, cnae: cnae),
    );
  }

  factory EmpresaDetectada.fromFirestore(Map<String, dynamic> data) {
    return EmpresaDetectada(
      cnpj: data['cnpj'] ?? '',
      razaoSocial: data['nome'] ?? '',
      nomeFantasia: data['nomeFantasia'] ?? '',
      cnae: data['cnae'] ?? '',
      cnaeDescricao: data['cnaeDescricao'] ?? '',
      dataAbertura: data['dataAbertura'] is Timestamp 
          ? (data['dataAbertura'] as Timestamp).toDate().toIso8601String() 
          : data['dataAbertura']?.toString() ?? '',
      situacao: data['situacao'] ?? '',
      naturezaJuridica: data['naturezaJuridica'] ?? '',
      porte: data['porte'] ?? '',
      capitalSocial: (data['capitalSocial'] ?? 0).toDouble(),
      logradouro: data['logradouro'] ?? '',
      numero: data['numero'] ?? '',
      complemento: data['complemento'] ?? '',
      bairro: data['bairro'] ?? '',
      municipio: data['municipio'] ?? '',
      uf: data['uf'] ?? '',
      cep: data['cep'] ?? '',
      telefone1: data['telefone'] ?? '',
      telefone2: data['telefone2'] ?? '',
      email: data['email'] ?? '',
      cidadeMonitorada: data['cidadeMonitorada'] ?? '',
      detectadaEm: data['detectadaEm'] is Timestamp 
          ? (data['detectadaEm'] as Timestamp).toDate() 
          : DateTime.now(),
      score: (data['score'] ?? 0).toDouble(),
    );
  }

  /// Normaliza telefone da API — pode vir como "(41) 3333-4444" ou "41333344444"
  static String _parseTelefone(Map<String, dynamic> data, String campo) {
    final raw = (data[campo] ?? '').toString().trim();
    if (raw.isEmpty) return '';
    if (raw.contains('(') || raw.contains(' ') || raw.contains('-')) return raw;
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 11) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7)}';
    } else if (digits.length == 10) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 6)}-${digits.substring(6)}';
    }
    return raw;
  }
}

class MonitorCnpjService {
  static const String _baseUrl = 'https://brasilapi.com.br/api/cnpj/v1';
  static const _colMonitor = 'monitor_cidades';
  static const _colDetectadas = 'empresas_detectadas';

  // ─── Configuração de cidades ──────────────────────────────────────────────

  static Stream<List<String>> streamCidades() {
    return FirebaseFirestore.instance
        .collection(_colMonitor)
        .doc('config')
        .snapshots()
        .map((snap) {
      if (!snap.exists) return <String>[];
      return List<String>.from(snap.data()!['cidades'] ?? []);
    });
  }

  static Future<void> salvarCidades(List<String> cidades) async {
    await FirebaseFirestore.instance
        .collection(_colMonitor)
        .doc('config')
        .set(
      {'cidades': cidades, 'atualizadoEm': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  // ─── Streams de empresas detectadas ─────────────────────────────────────

  static Stream<List<Map<String, dynamic>>> streamDetectadas() {
    return FirebaseFirestore.instance
        .collection(_colDetectadas)
        .orderBy('detectadaEm', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) =>
        snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  static Stream<int> streamNaoVistas() {
    return FirebaseFirestore.instance
        .collection(_colDetectadas)
        .where('visto', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  static Future<void> marcarVista(String docId) async {
    await FirebaseFirestore.instance
        .collection(_colDetectadas)
        .doc(docId)
        .update({'visto': true});
  }

  static Future<void> marcarTodasVistas() async {
    final snap = await FirebaseFirestore.instance
        .collection(_colDetectadas)
        .where('visto', isEqualTo: false)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'visto': true});
    }
    await batch.commit();
  }

  static Future<void> deletarDetectada(String docId) async {
    await FirebaseFirestore.instance
        .collection(_colDetectadas)
        .doc(docId)
        .delete();
  }

  // ─── Verificação de novas empresas ───────────────────────────────────────

  /// Roda verificação em todas as cidades; retorna quantas novas foram encontradas.
  static Future<int> verificar(List<String> cidades) async {
    int novas = 0;
    for (final cidade in cidades) {
      try {
        final empresas = await _buscarNovasEmpresas(cidade);
        for (final empresa in empresas) {
          final existe = await _jaExiste(empresa.cnpj);
          if (!existe) {
            await _salvarDetectada(empresa);
            await _salvarNaCarteira(empresa);
            novas++;
          }
        }
      } catch (_) {}
    }
    return novas;
  }

  /// Busca CNPJs com data de abertura de hoje na cidade.
  /// Para cada resultado, faz chamada individual para obter
  /// endereço completo, telefone e e-mail.
  static Future<List<EmpresaDetectada>> _buscarNovasEmpresas(String cidade) async {
    final hoje = DateTime.now();
    final dataStr =
        '${hoje.year}${hoje.month.toString().padLeft(2, '0')}${hoje.day.toString().padLeft(2, '0')}';

    final url = Uri.parse(
        '$_baseUrl/search?municipio=${Uri.encodeComponent(cidade.toUpperCase())}'
            '&data_inicio_atividade=$dataStr');

    final response = await http.get(url).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return [];

    final List<dynamic> lista = json.decode(response.body);
    final resultado = <EmpresaDetectada>[];

    for (final item in lista.take(20)) {
      try {
        final cnpj =
        (item['cnpj'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
        if (cnpj.isEmpty) continue;
        // Busca dados completos para ter endereço + telefone
        final completo = await _buscarCnpjCompleto(cnpj, cidade);
        if (completo != null) resultado.add(completo);
        // Respeita rate limit da BrasilAPI
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (_) {}
    }
    return resultado;
  }

  /// Busca dados cadastrais completos de um CNPJ individual.
  static Future<EmpresaDetectada?> _buscarCnpjCompleto(
      String cnpj, String cidade) async {
    final clean = cnpj.replaceAll(RegExp(r'[^0-9]'), '');
    final url = Uri.parse('$_baseUrl/$clean');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return EmpresaDetectada.fromApi(data, cidade);
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> _jaExiste(String cnpj) async {
    final snap = await FirebaseFirestore.instance
        .collection(_colDetectadas)
        .where('cnpj', isEqualTo: cnpj)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  static Future<void> _salvarDetectada(EmpresaDetectada empresa) async {
    final geo = await _geocodificar(empresa);
    await FirebaseFirestore.instance
        .collection(_colDetectadas)
        .add(empresa.toFirestore(geo));
  }

  /// Salva também na Carteira principal com status novaOportunidade.
  static Future<void> _salvarNaCarteira(EmpresaDetectada empresa) async {
    final existe = await FirebaseFirestore.instance
        .collection('clientes')
        .where('cnpj', isEqualTo: empresa.cnpj)
        .limit(1)
        .get();
    if (existe.docs.isNotEmpty) return;

    final geo = await _geocodificar(empresa);

    await FirebaseFirestore.instance.collection('clientes').add({
      'nome': empresa.razaoSocial,
      'nomeFantasia': empresa.nomeFantasia,
      'cnpj': empresa.cnpj,
      'cnae': empresa.cnaeDescricao.isNotEmpty
          ? empresa.cnaeDescricao
          : empresa.cnae,
      'capitalSocial': empresa.capitalSocial,
      'status': 'novaOportunidade',
      'localizacao': geo,
      'dataAbertura': empresa.dataAbertura.isNotEmpty
          ? Timestamp.fromDate(
          DateTime.tryParse(empresa.dataAbertura) ?? DateTime.now())
          : Timestamp.now(),
      'score': empresa.score,
      'logradouro': empresa.logradouro,
      'numero': empresa.numero,
      'complemento': empresa.complemento,
      'bairro': empresa.bairro,
      'municipio': empresa.municipio,
      'uf': empresa.uf,
      'cep': empresa.cep,
      'enderecoCompleto': empresa.enderecoCompleto,
      'telefone': empresa.telefone1,
      'telefone2': empresa.telefone2,
      'email': empresa.email,
      'naturezaJuridica': empresa.naturezaJuridica,
      'porte': empresa.porte,
      'situacao': empresa.situacao,
      'origemMonitor': true,
    });
  }

  /// Tenta geocodificar. Retorna GeoPoint(0,0) em caso de falha.
  static Future<GeoPoint> _geocodificar(EmpresaDetectada empresa) async {
    try {
      final endereco =
          '${empresa.logradouro}, ${empresa.numero}, ${empresa.municipio} - ${empresa.uf}';
      final locs = await locationFromAddress(endereco)
          .timeout(const Duration(seconds: 5));
      if (locs.isNotEmpty) {
        return GeoPoint(locs.first.latitude, locs.first.longitude);
      }
    } catch (_) {}
    return const GeoPoint(0, 0);
  }

  // ─── Consulta avulsa ─────────────────────────────────────────────────────

  static Future<EmpresaDetectada?> consultarCnpj(String cnpj) async {
    return _buscarCnpjCompleto(cnpj, '');
  }

  static Future<List<EmpresaDetectada>> buscarEmpresaPorNome(String nome) async {
    final termo = nome.toUpperCase();
    final snap = await FirebaseFirestore.instance
        .collection('clientes')
        .where('nome', isGreaterThanOrEqualTo: termo)
        .where('nome', isLessThanOrEqualTo: '$termo\uf8ff')
        .limit(10)
        .get();

    return snap.docs.map((d) => EmpresaDetectada.fromFirestore(d.data())).toList();
  }
}
