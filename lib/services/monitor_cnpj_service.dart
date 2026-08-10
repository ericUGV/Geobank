// lib/services/monitor_cnpj_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'score_service.dart';
import 'google_places_service.dart';
import 'casa_dos_dados_service.dart';

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
  final String? placeId; 

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
    this.placeId,
  });

  String get enderecoCompleto {
    final parts = <String>[];
    if (logradouro.isNotEmpty) parts.add(logradouro);
    if (numero.isNotEmpty)     parts.add('nº $numero');
    if (complemento.isNotEmpty) parts.add(complemento);
    if (bairro.isNotEmpty)     parts.add(bairro);
    if (municipio.isNotEmpty)  parts.add('$municipio/$uf');
    if (cep.isNotEmpty)        parts.add('CEP $cep');
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
    'logradouro': logradouro,
    'numero': numero,
    'complemento': complemento,
    'bairro': bairro,
    'municipio': municipio,
    'uf': uf,
    'cep': cep,
    'enderecoCompleto': enderecoCompleto,
    'telefone': telefone1,
    'telefone2': telefone2,
    'email': email,
    'localizacao': geoPoint,
    'cidadeMonitorada': cidadeMonitorada,
    'detectadaEm': Timestamp.fromDate(detectadaEm),
    'visto': false,
    'origemMonitor': true,
    'placeId': placeId,
  };

  factory EmpresaDetectada.fromApi(Map<String, dynamic> data, String cidade) {
    final capital   = (data['capital_social'] ?? 0).toDouble();
    final cnae      = data['cnae_fiscal']?.toString() ?? '';
    final municipio = (data['municipio'] ?? cidade).toString();
    final uf        = (data['uf'] ?? '').toString();
    return EmpresaDetectada(
      cnpj:             (data['cnpj'] ?? '').toString(),
      razaoSocial:      (data['razao_social'] ?? '').toString(),
      nomeFantasia:     (data['nome_fantasia'] ?? '').toString(),
      cnae:             cnae,
      cnaeDescricao:    (data['cnae_fiscal_descricao'] ?? '').toString(),
      dataAbertura:     (data['data_inicio_atividade'] ?? '').toString(),
      situacao:         (data['descricao_situacao_cadastral'] ?? '').toString(),
      naturezaJuridica: (data['descricao_natureza_juridica'] ?? '').toString(),
      porte:            (data['descricao_porte'] ?? '').toString(),
      capitalSocial:    capital,
      logradouro:       (data['logradouro'] ?? '').toString(),
      numero:           (data['numero'] ?? '').toString(),
      complemento:      (data['complemento'] ?? '').toString(),
      bairro:           (data['bairro'] ?? '').toString(),
      municipio:        municipio,
      uf:               uf,
      cep:              (data['cep'] ?? '').toString(),
      telefone1:        _parseTelefone(data, 'ddd_telefone_1'),
      telefone2:        _parseTelefone(data, 'ddd_telefone_2'),
      email:            (data['email'] ?? '').toString(),
      cidadeMonitorada: cidade,
      detectadaEm:      DateTime.now(),
      score: ScoreService.calcularScore(
        capitalSocial: capital,
        cnae:          cnae,
        municipio:     municipio,
        uf:            uf,
      ),
    );
  }

  factory EmpresaDetectada.fromCasaDosDados(Map<String, dynamic> data, String cidade) {
    // Casa dos Dados retorna campos diferentes, ajustar conforme documentação
    final cnpj = (data['cnpj'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
    return EmpresaDetectada(
      cnpj: cnpj,
      razaoSocial: data['razao_social'] ?? '',
      nomeFantasia: data['nome_fantasia'] ?? '',
      cnae: data['cnae_principal_codigo']?.toString() ?? '',
      cnaeDescricao: data['cnae_principal_descricao'] ?? '',
      dataAbertura: data['data_abertura'] ?? '',
      situacao: data['situacao_cadastral'] ?? 'ATIVA',
      naturezaJuridica: data['natureza_juridica'] ?? '',
      porte: data['porte'] ?? '',
      capitalSocial: (data['capital_social'] ?? 0).toDouble(),
      logradouro: data['logradouro'] ?? '',
      numero: data['numero'] ?? '',
      complemento: data['complemento'] ?? '',
      bairro: data['bairro'] ?? '',
      municipio: data['municipio'] ?? cidade,
      uf: data['uf'] ?? '',
      cep: data['cep'] ?? '',
      telefone1: _parseTelefone(data, 'telefone_1'),
      telefone2: _parseTelefone(data, 'telefone_2'),
      email: data['email'] ?? '',
      cidadeMonitorada: cidade,
      detectadaEm: DateTime.now(),
      score: ScoreService.calcularScore(
        capitalSocial: (data['capital_social'] ?? 0).toDouble(),
        cnae: data['cnae_principal_codigo']?.toString() ?? '',
        municipio: data['municipio'] ?? cidade,
        uf: data['uf'] ?? '',
      ),
    );
  }

  factory EmpresaDetectada.fromGoogle(Map<String, dynamic> place, String cidade) {
    return EmpresaDetectada(
      cnpj: '',
      razaoSocial: place['nome'] ?? '',
      nomeFantasia: '',
      cnae: '',
      cnaeDescricao: '',
      dataAbertura: 'Últimos 30 dias',
      situacao: 'ATIVA',
      naturezaJuridica: '',
      porte: '',
      capitalSocial: 0,
      logradouro: place['endereco'] ?? '',
      numero: '',
      complemento: '',
      bairro: '',
      municipio: cidade,
      uf: '',
      cep: '',
      telefone1: '',
      telefone2: '',
      email: '',
      cidadeMonitorada: cidade,
      detectadaEm: DateTime.now(),
      score: 55.0, 
      placeId: place['place_id'],
    );
  }

  factory EmpresaDetectada.fromFirestore(Map<String, dynamic> data) {
    return EmpresaDetectada(
      cnpj:             (data['cnpj'] ?? '').toString(),
      razaoSocial:      (data['nome'] ?? '').toString(),
      nomeFantasia:     (data['nomeFantasia'] ?? '').toString(),
      cnae:             (data['cnae'] ?? '').toString(),
      cnaeDescricao:    (data['cnaeDescricao'] ?? '').toString(),
      dataAbertura:     data['dataAbertura'] is Timestamp
          ? (data['dataAbertura'] as Timestamp).toDate().toIso8601String()
          : (data['dataAbertura'] ?? '').toString(),
      situacao:         (data['situacao'] ?? '').toString(),
      naturezaJuridica: (data['naturezaJuridica'] ?? '').toString(),
      porte:            (data['porte'] ?? '').toString(),
      capitalSocial:    (data['capitalSocial'] ?? 0).toDouble(),
      logradouro:       (data['logradouro'] ?? '').toString(),
      numero:           (data['numero'] ?? '').toString(),
      complemento:      (data['complemento'] ?? '').toString(),
      bairro:           (data['bairro'] ?? '').toString(),
      municipio:        (data['municipio'] ?? '').toString(),
      uf:               (data['uf'] ?? '').toString(),
      cep:              (data['cep'] ?? '').toString(),
      telefone1:        (data['telefone'] ?? '').toString(),
      telefone2:        (data['telefone2'] ?? '').toString(),
      email:            (data['email'] ?? '').toString(),
      cidadeMonitorada: (data['cidadeMonitorada'] ?? '').toString(),
      detectadaEm:      data['detectadaEm'] is Timestamp
          ? (data['detectadaEm'] as Timestamp).toDate()
          : DateTime.now(),
      score:            (data['score'] ?? 0).toDouble(),
      placeId:          data['placeId'],
    );
  }

  static String _parseTelefone(Map<String, dynamic> data, String campo) {
    final raw = (data[campo] ?? '').toString().trim();
    if (raw.isEmpty) return '';
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 11) return '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7)}';
    if (digits.length == 10) return '(${digits.substring(0, 2)}) ${digits.substring(2, 6)}-${digits.substring(6)}';
    return raw;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class MonitorCnpjService {
  static const String _brasilApi   = 'https://brasilapi.com.br/api/cnpj/v1';
  static const _colMonitor    = 'monitor_cidades';
  static const _colDetectadas = 'empresas_detectadas';

  static Stream<List<String>> streamCidades() {
    return FirebaseFirestore.instance
        .collection(_colMonitor).doc('config').snapshots()
        .map((snap) => snap.exists ? List<String>.from(snap.data()!['cidades'] ?? []) : <String>[]);
  }

  static Future<void> salvarCidades(List<String> cidades) async {
    await FirebaseFirestore.instance.collection(_colMonitor).doc('config').set(
      {'cidades': cidades, 'atualizadoEm': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  static Stream<List<Map<String, dynamic>>> streamDetectadas() {
    return FirebaseFirestore.instance
        .collection(_colDetectadas)
        .orderBy('detectadaEm', descending: true)
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  static Stream<int> streamNaoVistas() {
    return FirebaseFirestore.instance
        .collection(_colDetectadas)
        .where('visto', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  static Future<void> marcarVista(String docId) async {
    await FirebaseFirestore.instance.collection(_colDetectadas).doc(docId).update({'visto': true});
  }

  static Future<void> marcarTodasVistas() async {
    final snap = await FirebaseFirestore.instance
        .collection(_colDetectadas).where('visto', isEqualTo: false).get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) batch.update(doc.reference, {'visto': true});
    await batch.commit();
  }

  static Future<void> deletarDetectada(String docId) async {
    await FirebaseFirestore.instance.collection(_colDetectadas).doc(docId).delete();
  }

  static Future<int> verificar(List<String> cidades) async {
    int novas = 0;
    for (final cidade in cidades) {
      try {
        // 1. Monitor CNPJ (BrasilAPI)
        final empresas = await _buscarNovasEmpresas(cidade);
        for (final empresa in empresas) {
          if (await _jaExiste(empresa.cnpj)) continue;
          final geo = await _geocodificar(empresa);
          await _salvarDetectada(empresa, geo);
          await _salvarNaCarteira(empresa, geo);
          novas++;
        }

        // 2. Monitor Casa dos Dados (Nova API)
        // Tentamos buscar sem UF primeiro, ou se falhar, apenas ignoramos se a API exigir UF
        try {
          final empresasCasa = await CasaDosDadosService.pesquisarAvancada(municipio: cidade);
          for (final item in empresasCasa) {
            final empresa = EmpresaDetectada.fromCasaDosDados(item, cidade);
            if (await _jaExiste(empresa.cnpj)) continue;
            final geo = await _geocodificar(empresa);
            await _salvarDetectada(empresa, geo);
            await _salvarNaCarteira(empresa, geo);
            novas++;
          }
        } catch (e) {
          print('Erro no monitoramento Casa dos Dados para $cidade: $e');
        }

        // 3. Monitor Google Maps
        final locaisGoogle = await _buscarNovasNoGoogle(cidade);
        for (final local in locaisGoogle) {
          if (await _jaExisteGoogle(local['place_id'])) continue;
          final empresa = EmpresaDetectada.fromGoogle(local, cidade);
          final geo = GeoPoint(local['lat'], local['lng']);
          await _salvarDetectada(empresa, geo);
          await _salvarNaCarteira(empresa, geo);
          novas++;
        }
      } catch (_) {}
    }
    return novas;
  }

  static Future<List<EmpresaDetectada>> _buscarNovasEmpresas(String cidade) async {
    final hoje    = DateTime.now();
    final dataStr = '${hoje.year}-${hoje.month.toString().padLeft(2,'0')}-${hoje.day.toString().padLeft(2,'0')}';

    try {
      final url = Uri.parse(
          '$_brasilApi/search?municipio=${Uri.encodeComponent(cidade.toUpperCase())}'
              '&data_inicio_atividade=$dataStr&page=1&per_page=20');
      final res = await http.get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        final lista = body is List ? body : (body['data'] ?? body['empresas'] ?? const []);
        if (lista is List && lista.isNotEmpty) return _enriquecerLista(lista, cidade);
      }
    } catch (_) {}

    return [];
  }

  static Future<List<Map<String, dynamic>>> _buscarNovasNoGoogle(String cidade) async {
    return await GooglePlacesService.buscarEmpresas("novas empresas em $cidade");
  }

  static Future<List<EmpresaDetectada>> _enriquecerLista(List<dynamic> lista, String cidade) async {
    final resultado = <EmpresaDetectada>[];
    for (final item in lista.take(15)) {
      try {
        final cnpj = (item['cnpj'] ?? item['taxId'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
        if (cnpj.isEmpty) continue;
        final empresa = await _buscarCnpjCompleto(cnpj, cidade);
        if (empresa != null) resultado.add(empresa);
        await Future.delayed(const Duration(milliseconds: 400));
      } catch (_) {}
    }
    return resultado;
  }

  static Future<EmpresaDetectada?> _buscarCnpjCompleto(String cnpj, String cidade) async {
    final clean = cnpj.replaceAll(RegExp(r'[^0-9]'), '');
    try {
      final res = await http.get(Uri.parse('$_brasilApi/$clean')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return EmpresaDetectada.fromApi(json.decode(res.body) as Map<String, dynamic>, cidade);
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> _jaExiste(String cnpj) async {
    if (cnpj.isEmpty) return false;
    final snap = await FirebaseFirestore.instance
        .collection(_colDetectadas).where('cnpj', isEqualTo: cnpj).limit(1).get();
    return snap.docs.isNotEmpty;
  }

  static Future<bool> _jaExisteGoogle(String? placeId) async {
    if (placeId == null || placeId.isEmpty) return false;
    final snap = await FirebaseFirestore.instance
        .collection(_colDetectadas).where('placeId', isEqualTo: placeId).limit(1).get();
    return snap.docs.isNotEmpty;
  }

  static Future<void> _salvarDetectada(EmpresaDetectada empresa, GeoPoint geo) async {
    await FirebaseFirestore.instance.collection(_colDetectadas).add(empresa.toFirestore(geo));
  }

  static Future<void> _salvarNaCarteira(EmpresaDetectada empresa, GeoPoint geo) async {
    Query query;
    if (empresa.cnpj.isNotEmpty) {
      query = FirebaseFirestore.instance.collection('clientes').where('cnpj', isEqualTo: empresa.cnpj);
    } else if (empresa.placeId != null) {
      query = FirebaseFirestore.instance.collection('clientes').where('placeId', isEqualTo: empresa.placeId);
    } else {
      return;
    }

    final existe = await query.limit(1).get();
    if (existe.docs.isNotEmpty) return;

    await FirebaseFirestore.instance.collection('clientes').add({
      'nome':             empresa.razaoSocial,
      'nomeFantasia':     empresa.nomeFantasia,
      'cnpj':             empresa.cnpj,
      'placeId':          empresa.placeId,
      'cnae':             empresa.cnaeDescricao.isNotEmpty ? empresa.cnaeDescricao : empresa.cnae,
      'capitalSocial':    empresa.capitalSocial,
      'status':           'novaOportunidade',
      'localizacao':      geo,
      'dataAbertura':     empresa.dataAbertura,
      'score':            empresa.score,
      'logradouro':       empresa.logradouro,
      'municipio':        empresa.municipio,
      'uf':               empresa.uf,
      'enderecoCompleto': empresa.enderecoCompleto,
      'origemMonitor':    true,
      'detectadaEm':      FieldValue.serverTimestamp(),
    });
  }

  static Future<GeoPoint> _geocodificar(EmpresaDetectada empresa) async {
    try {
      final endereco = '${empresa.logradouro}, ${empresa.numero}, ${empresa.municipio} - ${empresa.uf}';
      final locs = await locationFromAddress(endereco).timeout(const Duration(seconds: 5));
      if (locs.isNotEmpty) return GeoPoint(locs.first.latitude, locs.first.longitude);
    } catch (_) {}
    return const GeoPoint(0, 0);
  }

  static Future<void> adicionarACarteira(EmpresaDetectada empresa) async {
    final geo = await _geocodificar(empresa);
    await _salvarNaCarteira(empresa, geo);
  }

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
