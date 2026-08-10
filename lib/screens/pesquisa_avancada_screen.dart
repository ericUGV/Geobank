// lib/screens/pesquisa_avancada_screen.dart

import 'package:flutter/material.dart';
import '../services/casa_dos_dados_service.dart';
import '../services/monitor_cnpj_service.dart';
import '../theme/app_theme.dart';

class PesquisaAvancadaScreen extends StatefulWidget {
  const PesquisaAvancadaScreen({super.key});

  @override
  State<PesquisaAvancadaScreen> createState() => _PesquisaAvancadaScreenState();
}

class _PesquisaAvancadaScreenState extends State<PesquisaAvancadaScreen> {
  final _municipioController = TextEditingController();
  final _ufController = TextEditingController();
  final _cnaeController = TextEditingController();
  final _capitalController = TextEditingController();
  
  int _diasAtras = 30;
  bool _isLoading = false;
  List<Map<String, dynamic>> _resultados = [];
  String? _erro;

  @override
  void dispose() {
    _municipioController.dispose();
    _ufController.dispose();
    _cnaeController.dispose();
    _capitalController.dispose();
    super.dispose();
  }

  Future<void> _pesquisar() async {
    setState(() {
      _isLoading = true;
      _resultados = [];
      _erro = null;
    });

    try {
      final capital = double.tryParse(_capitalController.text) ?? 0.0;
      
      final resultados = await CasaDosDadosService.pesquisarAvancada(
        municipio: _municipioController.text.trim(),
        uf: _ufController.text.trim(),
        cnae: _cnaeController.text.trim(),
        capitalMinimo: capital > 0 ? capital : null,
        diasAtras: _diasAtras,
      );

      setState(() {
        _resultados = resultados;
        if (resultados.isEmpty) {
          _erro = "Nenhuma empresa encontrada com estes filtros.";
        }
      });
    } catch (e) {
      String msgErro = "Erro ao realizar pesquisa.";
      if (e.toString().contains("Token")) {
        msgErro = "Token da API expirado ou inválido. Para o seu TCC, tente usar a Pesquisa via Google Maps no botão ao lado.";
      } else if (e.toString().contains("Limite")) {
        msgErro = "Limite de buscas atingido para este token.";
      } else if (e.toString().contains("timeout")) {
        msgErro = "A conexão com o servidor expirou. Tente novamente.";
      } else {
        msgErro = "Erro: ${e.toString().replaceAll('Exception: ', '')}";
      }
      setState(() => _erro = msgErro);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _salvarNaCarteira(Map<String, dynamic> data) async {
    final empresa = EmpresaDetectada.fromCasaDosDados(data, _municipioController.text);
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
        title: const Text('Pesquisa Avançada'),
        backgroundColor: AppColors.primary,
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
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _municipioController,
                        decoration: _inputDecor('Município', Icons.location_city),
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _ufController,
                        decoration: _inputDecor('UF', null),
                        maxLength: 2,
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _cnaeController,
                  decoration: _inputDecor('Código CNAE (ex: 4711302)', Icons.category),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _capitalController,
                  decoration: _inputDecor('Capital Social Mínimo (R\$)', Icons.attach_money),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Abertas há:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    Expanded(
                      child: Slider(
                        value: _diasAtras.toDouble(),
                        min: 7,
                        max: 365,
                        divisions: 12,
                        label: "$_diasAtras dias",
                        onChanged: (v) => setState(() => _diasAtras = v.toInt()),
                      ),
                    ),
                    Text('$_diasAtras dias', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pesquisar,
                    icon: const Icon(Icons.search),
                    label: const Text('Pesquisar na Casa dos Dados'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
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
          Text(data['razao_social'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text("CNPJ: ${data['cnpj']}", style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text("${data['municipio']} - ${data['uf']}", style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text("Abertura: ${data['data_abertura']}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text("Capital: R\$ ${data['capital_social']}", style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _salvarNaCarteira(data),
              icon: const Icon(Icons.add_business, size: 18),
              label: const Text('Adicionar à Carteira'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
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
