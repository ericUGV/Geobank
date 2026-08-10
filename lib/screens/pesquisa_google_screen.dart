// lib/screens/pesquisa_google_screen.dart

import 'package:flutter/material.dart';
import '../services/google_places_service.dart';
import '../services/monitor_cnpj_service.dart';
import '../theme/app_theme.dart';

class PesquisaGoogleScreen extends StatefulWidget {
  const PesquisaGoogleScreen({super.key});

  @override
  State<PesquisaGoogleScreen> createState() => _PesquisaGoogleScreenState();
}

class _PesquisaGoogleScreenState extends State<PesquisaGoogleScreen> {
  final _queryController = TextEditingController();
  final _cidadeController = TextEditingController();
  
  bool _isLoading = false;
  List<Map<String, dynamic>> _resultados = [];
  String? _erro;

  String? _tipoSelecionado;
  final List<Map<String, String>> _tipos = [
    {'label': 'Todos', 'value': ''},
    {'label': 'Bancos', 'value': 'bank'},
    {'label': 'Contabilidades', 'value': 'accounting'},
    {'label': 'Postos de Combustível', 'value': 'gas_station'},
    {'label': 'Supermercados', 'value': 'supermarket'},
    {'label': 'Lojas de Carros', 'value': 'car_dealer'},
    {'label': 'Escritórios', 'value': 'establishment'},
  ];

  @override
  void dispose() {
    _queryController.dispose();
    _cidadeController.dispose();
    super.dispose();
  }

  Future<void> _pesquisar() async {
    final query = _queryController.text.trim();
    final cidade = _cidadeController.text.trim();
    
    if (query.isEmpty && (_tipoSelecionado == null || _tipoSelecionado!.isEmpty)) {
      setState(() => _erro = "Digite o que buscar ou selecione um tipo.");
      return;
    }

    setState(() {
      _isLoading = true;
      _resultados = [];
      _erro = null;
    });

    try {
      final buscaCompleta = cidade.isNotEmpty ? "$query em $cidade" : query;
      final resultados = await GooglePlacesService.buscarEmpresas(
        buscaCompleta, 
        type: _tipoSelecionado != '' ? _tipoSelecionado : null
      );

      setState(() {
        _resultados = resultados;
        if (resultados.isEmpty) {
          // Se o Google negou por falta de faturamento, mostramos exemplos para o TCC
          _resultados = [
            {
              'place_id': 'mock_1',
              'nome': 'Banco do Brasil - Agência Central',
              'endereco': 'Rua XV de Novembro, 123 - Centro',
              'rating': 4.5,
              'types': ['bank', 'finance']
            },
            {
              'place_id': 'mock_2',
              'nome': 'Posto Shell - Rodovia',
              'endereco': 'Av. Principal, 500 - Trevo',
              'rating': 4.2,
              'types': ['gas_station', 'establishment']
            },
            {
              'place_id': 'mock_3',
              'nome': 'Supermercado Condor',
              'endereco': 'Rua das Flores, 88 - Bairro Novo',
              'rating': 4.0,
              'types': ['supermarket', 'grocery_or_supermarket']
            },
          ];
          _erro = "Nota: Exibindo locais de demonstração (API Google Maps requer ativação de faturamento).";
        }
      });
    } catch (e) {
      setState(() => _erro = "Erro ao realizar pesquisa no Google: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _salvarNaCarteira(Map<String, dynamic> data) async {
    final empresa = EmpresaDetectada.fromGoogle(data, _cidadeController.text);
    await MonitorCnpjService.adicionarACarteira(empresa);
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("${empresa.razaoSocial} adicionada à carteira!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Pesquisa no Google Maps'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Painel de Filtros
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _queryController,
                  decoration: _inputDecor('O que buscar? (ex: Supermercados, Academias)', Icons.search),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _cidadeController,
                  decoration: _inputDecor('Cidade (Opcional)', Icons.location_city),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _tipoSelecionado,
                  decoration: _inputDecor('Tipo de Estabelecimento', Icons.category),
                  items: _tipos.map((t) => DropdownMenuItem(
                    value: t['value'],
                    child: Text(t['label']!),
                  )).toList(),
                  onChanged: (v) => setState(() => _tipoSelecionado = v),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pesquisar,
                    icon: const Icon(Icons.map),
                    label: const Text('Pesquisar no Google Maps'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lista de Resultados
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _erro != null
                    ? Center(child: Text(_erro!, style: const TextStyle(color: AppColors.textSecondary)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _resultados.length,
                        itemBuilder: (context, index) {
                          final item = _resultados[index];
                          return _resultadoCard(item);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _resultadoCard(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(data['nome'] ?? '', 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              if (data['rating'] != null)
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    Text(" ${data['rating']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(data['endereco'] ?? '', 
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const Divider(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _salvarNaCarteira(data),
              icon: const Icon(Icons.add_business, size: 18),
              label: const Text('Adicionar à Carteira'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.blue[800]),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecor(String hint, IconData? icon) => InputDecoration(
    hintText: hint,
    prefixIcon: icon != null ? Icon(icon, size: 20, color: AppColors.textSecondary) : null,
    filled: true,
    fillColor: AppColors.surface,
    counterText: '',
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
  );
}
