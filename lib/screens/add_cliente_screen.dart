// lib/screens/add_cliente_screen.dart
// CORRIGIDO:
//  - Busca via CNPJ (BrasilAPI) com geocodificação automática
//  - Ou cadastro manual com endereço → geocodificação
//  - Score calculado corretamente
//  - Campos completos: CNAE, banco, município, UF, CEP

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import '../services/score_service.dart';
import '../services/cnpj_service.dart';
import '../theme/app_theme.dart';

class AddClienteScreen extends StatefulWidget {
  @override
  _AddClienteScreenState createState() => _AddClienteScreenState();
}

class _AddClienteScreenState extends State<AddClienteScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Aba CNPJ ──────────────────────────────────────────────────────────────
  final _cnpjController = TextEditingController();
  bool _buscandoCnpj = false;

  // ── Aba Manual ─────────────────────────────────────────────────────────────
  final _nomeController = TextEditingController();
  final _cnpjManualController = TextEditingController();
  final _cnaeController = TextEditingController();
  final _logradouroController = TextEditingController();
  final _numeroController = TextEditingController();
  final _bairroController = TextEditingController();
  final _municipioController = TextEditingController();
  final _ufController = TextEditingController();
  final _cepController = TextEditingController();
  final _capitalController = TextEditingController();

  String _statusManual = 'leadFrio';
  String _bancoManual = 'Banco do Brasil';
  bool _salvandoManual = false;

  final List<String> _bancos = [
    'Banco do Brasil', 'Itaú', 'Bradesco', 'Caixa', 'Santander',
    'Sicredi', 'Sicoob', 'Nubank', 'Outro',
  ];

  final List<Map<String, dynamic>> _statusOptions = [
    {'value': 'clienteBB_Minha', 'label': '🔵 Minha Carteira BB'},
    {'value': 'clienteBB_Outra', 'label': '🟡 Outra Carteira BB'},
    {'value': 'concorrente',     'label': '🔴 Concorrente'},
    {'value': 'novaOportunidade','label': '🟣 Nova Oportunidade'},
    {'value': 'leadFrio',        'label': '⚪ Lead Frio'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cnpjController.dispose();
    _nomeController.dispose();
    _cnpjManualController.dispose();
    _cnaeController.dispose();
    _logradouroController.dispose();
    _numeroController.dispose();
    _bairroController.dispose();
    _municipioController.dispose();
    _ufController.dispose();
    _cepController.dispose();
    _capitalController.dispose();
    super.dispose();
  }

  // ── Busca por CNPJ ─────────────────────────────────────────────────────────

  Future<void> _buscarCnpj() async {
    final cnpj = _cnpjController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cnpj.length != 14) {
      _snack('Digite um CNPJ completo com 14 dígitos.', isError: true);
      return;
    }
    setState(() => _buscandoCnpj = true);
    final resultado = await CnpjService.buscarECadastrar(cnpj);
    if (!mounted) return;
    setState(() => _buscandoCnpj = false);

    if (resultado != null) {
      _snack('${resultado['nome']} adicionada à carteira!');
      Navigator.pop(context);
    } else {
      _snack('CNPJ não encontrado ou API indisponível.', isError: true);
    }
  }

  // ── Salvar manual ──────────────────────────────────────────────────────────

  Future<void> _salvarManual() async {
    if (_nomeController.text.trim().isEmpty) {
      _snack('Informe o nome da empresa.', isError: true);
      return;
    }

    setState(() => _salvandoManual = true);

    // Geocodificação pelo endereço digitado
    GeoPoint geoPoint = const GeoPoint(0, 0);
    if (_logradouroController.text.isNotEmpty && _municipioController.text.isNotEmpty) {
      try {
        final endereco =
            '${_logradouroController.text}, ${_numeroController.text}, '
            '${_municipioController.text} - ${_ufController.text}';
        final locs = await locationFromAddress(endereco).timeout(const Duration(seconds: 6));
        if (locs.isNotEmpty) {
          geoPoint = GeoPoint(locs.first.latitude, locs.first.longitude);
        }
      } catch (_) {
        // geocodificação falhou — usa (0,0), empresa fica sem pin no mapa
      }
    }

    // Calcula score
    final capital = double.tryParse(_capitalController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    final score = ScoreService.calcularScore(
      capitalSocial: capital,
      cnae: _cnaeController.text.trim(),
      municipio: _municipioController.text.trim(),
      uf: _ufController.text.trim(),
    );

    final municipio = _municipioController.text.trim().toUpperCase();
    final uf = _ufController.text.trim().toUpperCase();

    // Monta endereço completo
    final partes = <String>[];
    if (_logradouroController.text.isNotEmpty) partes.add(_logradouroController.text.trim());
    if (_numeroController.text.isNotEmpty) partes.add('nº ${_numeroController.text.trim()}');
    if (_bairroController.text.isNotEmpty) partes.add(_bairroController.text.trim());
    if (municipio.isNotEmpty) partes.add('$municipio/$uf');
    if (_cepController.text.isNotEmpty) partes.add('CEP ${_cepController.text.trim()}');

    await FirebaseFirestore.instance.collection('clientes').add({
      'nome': _nomeController.text.trim(),
      'cnpj': _cnpjManualController.text.replaceAll(RegExp(r'[^0-9]'), ''),
      'cnae': _cnaeController.text.trim(),
      'capitalSocial': capital,
      'bancoDomicilio': _bancoManual,
      'status': _statusManual,
      'localizacao': geoPoint,
      'score': score,
      'logradouro': _logradouroController.text.trim(),
      'numero': _numeroController.text.trim(),
      'bairro': _bairroController.text.trim(),
      'municipio': municipio,
      'uf': uf,
      'cep': _cepController.text.trim(),
      'enderecoCompleto': partes.join(', '),
      'dataAbertura': null,
      'ultimaVisita': null,
    });

    if (!mounted) return;
    _snack('${_nomeController.text.trim()} adicionada à carteira!');
    Navigator.pop(context);
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle,
            color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: isError ? Colors.red : const Color(0xFF16A34A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Adicionar Cliente'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_scanner_outlined), text: 'Por CNPJ'),
            Tab(icon: Icon(Icons.edit_outlined), text: 'Manual'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildCnpjTab(), _buildManualTab()],
      ),
    );
  }

  // ── Aba CNPJ ──────────────────────────────────────────────────────────────

  Widget _buildCnpjTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Buscar pelo CNPJ',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text(
            'O sistema consulta a Receita Federal e preenche automaticamente os dados da empresa, endereço e score.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _cnpjController,
            keyboardType: TextInputType.number,
            style: const TextStyle(letterSpacing: 1.5, fontSize: 15),
            decoration: _inputDecor('00.000.000/0000-00', Icons.badge_outlined),
            onSubmitted: (_) => _buscarCnpj(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _buscandoCnpj ? null : _buscarCnpj,
              icon: _buscandoCnpj
                  ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.search, size: 20),
              label: Text(_buscandoCnpj ? 'Consultando Receita Federal...' : 'Buscar e Adicionar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
                  SizedBox(width: 8),
                  Text('O que é preenchido automaticamente:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ]),
                const SizedBox(height: 10),
                ...[
                  'Razão social e nome fantasia',
                  'Endereço completo (logradouro, bairro, CEP)',
                  'CNAE e porte da empresa',
                  'Capital social',
                  'Coordenadas GPS (geocodificação automática)',
                  'Score de prospecção (0 a 100)',
                ].map((t) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [
                    const Icon(Icons.check, color: Color(0xFF16A34A), size: 14),
                    const SizedBox(width: 6),
                    Text(t, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ]),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Aba Manual ─────────────────────────────────────────────────────────────

  Widget _buildManualTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Nome / Razão Social *'),
          const SizedBox(height: 8),
          TextField(controller: _nomeController, decoration: _inputDecor('Nome da empresa', Icons.business)),

          const SizedBox(height: 16),
          _label('CNPJ'),
          const SizedBox(height: 8),
          TextField(controller: _cnpjManualController, keyboardType: TextInputType.number,
              decoration: _inputDecor('00.000.000/0000-00', Icons.badge_outlined)),

          const SizedBox(height: 16),
          _label('CNAE (código ou descrição)'),
          const SizedBox(height: 8),
          TextField(controller: _cnaeController,
              decoration: _inputDecor('Ex: 47 - Comércio Varejista', Icons.category_outlined)),

          const SizedBox(height: 16),
          _label('Capital Social (R\$)'),
          const SizedBox(height: 8),
          TextField(controller: _capitalController, keyboardType: TextInputType.number,
              decoration: _inputDecor('0.00', Icons.attach_money)),

          const SizedBox(height: 16),
          _label('Banco Domicílio'),
          const SizedBox(height: 8),
          _dropdownContainer(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _bancoManual,
                items: _bancos.map((b) => DropdownMenuItem(
                  value: b,
                  child: Text(b, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                )).toList(),
                onChanged: (v) => setState(() => _bancoManual = v!),
              ),
            ),
          ),

          const SizedBox(height: 16),
          _label('Status na Carteira'),
          const SizedBox(height: 8),
          _dropdownContainer(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _statusManual,
                items: _statusOptions.map((opt) => DropdownMenuItem(
                  value: opt['value'] as String,
                  child: Text(opt['label'] as String, style: const TextStyle(fontSize: 14)),
                )).toList(),
                onChanged: (v) => setState(() => _statusManual = v!),
              ),
            ),
          ),

          const Divider(height: 32),
          const Text('Endereço',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Usado para posicionar a empresa no mapa.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 14),

          TextField(controller: _logradouroController,
              decoration: _inputDecor('Rua, Avenida...', Icons.location_on_outlined)),
          const SizedBox(height: 12),

          Row(children: [
            Expanded(
              flex: 2,
              child: TextField(controller: _bairroController,
                  decoration: _inputDecor('Bairro', Icons.map_outlined)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(controller: _numeroController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecor('Nº', Icons.tag)),
            ),
          ]),
          const SizedBox(height: 12),

          Row(children: [
            Expanded(
              flex: 3,
              child: TextField(
                  controller: _municipioController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDecor('Município', Icons.location_city_outlined)),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 70,
              child: TextField(
                controller: _ufController,
                maxLength: 2,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'UF',
                  counterText: '',
                  filled: true, fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.divider)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.divider)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),

          TextField(controller: _cepController, keyboardType: TextInputType.number,
              decoration: _inputDecor('CEP', Icons.local_post_office_outlined)),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _salvandoManual ? null : _salvarManual,
              icon: _salvandoManual
                  ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_outlined, size: 20),
              label: const Text('Salvar Cliente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary));

  InputDecoration _inputDecor(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
    filled: true, fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.divider)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.divider)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
  );

  Widget _dropdownContainer({required Widget child}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.divider),
    ),
    child: child,
  );
}