import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'score_service.dart';

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

  static Future<void> adicionarACarteira(EmpresaDetectada e) async {
    final geo = await _geocodificar(e);
    final existe = await FirebaseFirestore.instance
        .collection('clientes').where('cnpj', isEqualTo: e.cnpj).limit(1).get();

    if (existe.docs.isEmpty) {
      await FirebaseFirestore.instance.collection('clientes').add(e.toFirestore(geo));
    }
  }

  static Future<int> verificar(List<String> cidades) async {
    int novas = 0;
    for (final cidade in cidades) {
      try {
        final empresas = await _buscarNovasEmpresas(cidade);
        for (final empresa in empresas) {
          final existe = await FirebaseFirestore.instance
              .collection('empresas_detectadas').where('cnpj', isEqualTo: empresa.cnpj).limit(1).get();
          if (existe.docs.isEmpty) {
            final geo = await _geocodificar(empresa);
            await FirebaseFirestore.instance.collection('empresas_detectadas').add(empresa.toFirestore(geo));
            await adicionarACarteira(empresa);
            novas++;
          }
        }
      } catch (_) {}
    }
    return novas;
  }

  static Future<List<EmpresaDetectada>> _buscarNovasEmpresas(String cidade) async {
    final hoje = DateTime.now();
    final dataStr = '${hoje.year}-${hoje.month.toString().padLeft(2,'0')}-${hoje.day.toString().padLeft(2,'0')}';
    try {
      final url = Uri.parse('$_brasilApi/search?municipio=${Uri.encodeComponent(cidade.toUpperCase())}&data_inicio_atividade=$dataStr');
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final List<dynamic> lista = json.decode(res.body);
        final resultado = <EmpresaDetectada>[];
        for (var item in lista.take(10)) {
          final detalhe = await consultarCnpj(item['cnpj']);
          if (detalhe != null) resultado.add(detalhe);
        }
        return resultado;
      }
    } catch (_) {}
    return [];
  }

  static Future<EmpresaDetectada?> consultarCnpj(String cnpj) async {
    final clean = cnpj.replaceAll(RegExp(r'[^0-9]'), '');
    try {
      final res = await http.get(Uri.parse('$_brasilApi/$clean')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return EmpresaDetectada.fromApi(json.decode(res.body), '');
      }
    } catch (_) {}
    return null;
  }

  static Future<List<EmpresaDetectada>> buscarEmpresaPorNome(String nome) async {
    final termo = nome.toUpperCase();
    final snap = await FirebaseFirestore.instance
        .collection('clientes')
        .where('nome', isGreaterThanOrEqualTo: termo)
        .where('nome', isLessThanOrEqualTo: '$termo\uf8ff')
        .limit(10).get();
    return snap.docs.map((d) => EmpresaDetectada.fromFirestore(d.data())).toList();
  }

  static Future<GeoPoint> _geocodificar(EmpresaDetectada e) async {
    try {
      final endereco = '${e.logradouro}, ${e.numero}, ${e.municipio} - ${e.uf}';
      final locs = await locationFromAddress(endereco).timeout(const Duration(seconds: 5));
      if (locs.isNotEmpty) return GeoPoint(locs.first.latitude, locs.first.longitude);
    } catch (_) {}
    return const GeoPoint(0, 0);
  }

  static Future<void> marcarVista(String id) async => FirebaseFirestore.instance.collection(_colDetectadas).doc(id).update({'visto': true});

  static Future<void> marcarTodasVistas() async {
    final snap = await FirebaseFirestore.instance.collection(_colDetectadas).where('visto', isEqualTo: false).get();
    for (var d in snap.docs) d.reference.update({'visto': true});
  }
}