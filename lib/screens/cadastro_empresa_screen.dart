import 'package:flutter/material.dart';
import '../services/cnpj_service.dart';
import '../theme/app_theme.dart';

class CadastroEmpresaScreen extends StatefulWidget {
  @override
  _CadastroEmpresaScreenState createState() => _CadastroEmpresaScreenState();
}

class _CadastroEmpresaScreenState extends State<CadastroEmpresaScreen> {
  final _buscaController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, String>> _sugestoes = [];
  Map<String, dynamic>? _empresaDetalhada;

  void _pesquisarNovasEmpresas(String query) {
    if (query.length < 3) {
      setState(() => _sugestoes = []);
      return;
    }
    final mockEmpresas = [
      {'nome': 'MERCADO DA VILA LTDA', 'cnpj': '12345678000190', 'cnae': '4711-3/02 - Comércio Varejista'},
      {'nome': 'POSTO CENTRAL S.A.', 'cnpj': '98765432000121', 'cnae': '4731-8/00 - Comércio de Combustíveis'},
      {'nome': 'RESTAURANTE SABOR REAL', 'cnpj': '45678912000133', 'cnae': '5611-2/01 - Restaurantes'},
      {'nome': 'AUTO PEÇAS DO VALE', 'cnpj': '11223344000155', 'cnae': '4530-7/03 - Comércio de Peças'},
      {'nome': 'TECH SOLUTIONS LTDA', 'cnpj': '33445566000177', 'cnae': '6201-5/00 - Desenvolvimento de Software'},
    ];
    setState(() {
      _sugestoes = mockEmpresas.where((e) => e['nome']!.toLowerCase().contains(query.toLowerCase()) || e['cnpj']!.contains(query)).toList();
    });
  }

  Future<void> _cadastrarPeloCnpj(String cnpj, String nome) async {
    setState(() { _isLoading = true; _sugestoes = []; _buscaController.text = cnpj; });
    final resultado = await CnpjService.buscarECadastrar(cnpj);
    setState(() { _isLoading = false; _empresaDetalhada = resultado; });
    if (resultado != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text("'${resultado['nome'] ?? nome}' monitorada com sucesso!")),
          ]),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.radar, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Monitorador", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            Text("Detecção automática de empresas", style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _buscaController,
                      onChanged: _pesquisarNovasEmpresas,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: "Digite o nome ou CNPJ da empresa...",
                        hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                        suffixIcon: _buscaController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18, color: AppColors.textSecondary),
                                onPressed: () { _buscaController.clear(); setState(() { _sugestoes = []; _empresaDetalhada = null; }); },
                              )
                            : null,
                        filled: true, fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Loading
            if (_isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 12),
                    Text("Consultando dados da empresa...", style: TextStyle(color: AppColors.textSecondary)),
                  ]),
                ),
              ),

            // Suggestions
            if (_sugestoes.isNotEmpty && !_isLoading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.business_center, size: 16, color: AppColors.statusNovaEmpresa),
                          const SizedBox(width: 6),
                          Text("${_sugestoes.length} empresa(s) encontrada(s)", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ..._sugestoes.map((e) => _sugestaoCard(e)),
                    ],
                  ),
                ),
              ),

            // Result card
            if (_empresaDetalhada != null && !_isLoading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF16A34A), width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Text("Empresa Monitorada", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF16A34A))),
                        ]),
                        const Divider(height: 20),
                        _detailRow(Icons.business, _empresaDetalhada!['nome'] ?? ''),
                        _detailRow(Icons.badge_outlined, _empresaDetalhada!['cnpj'] ?? ''),
                        _detailRow(Icons.star_outline, "Score: ${_empresaDetalhada!['score'] ?? 'N/A'}"),
                      ],
                    ),
                  ),
                ),
              ),

            // Info section
            if (_sugestoes.isEmpty && _empresaDetalhada == null && !_isLoading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 60, height: 60,
                              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), shape: BoxShape.circle),
                              child: const Icon(Icons.search_outlined, size: 32, color: AppColors.primary),
                            ),
                            const SizedBox(height: 16),
                            const Text("Busque por Empresas", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            const SizedBox(height: 8),
                            const Text(
                              "Digite o nome ou CNPJ da empresa que deseja monitorar. O sistema irá buscar os dados públicos e calcular automaticamente o score de prospecção.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
                            ),
                            const SizedBox(height: 20),
                            // Features chips
                            Wrap(
                              spacing: 8, runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                _featureChip(Icons.gps_fixed, "Geocodificação"),
                                _featureChip(Icons.score, "Score Auto"),
                                _featureChip(Icons.business_center, "CNPJ Público"),
                                _featureChip(Icons.add_location, "Mapa GPS"),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sugestaoCard(Map<String, String> e) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border(left: BorderSide(color: AppColors.statusNovaEmpresa, width: 3)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.statusNovaEmpresa.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.business, color: AppColors.statusNovaEmpresa, size: 20),
      ),
      title: Text(e['nome']!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("CNPJ: ${e['cnpj']}", style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          if (e['cnae'] != null) Text(e['cnae']!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
      trailing: ElevatedButton(
        onPressed: () => _cadastrarPeloCnpj(e['cnpj']!, e['nome']!),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: Size.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text("Monitorar", style: TextStyle(fontSize: 12)),
      ),
    ),
  );

  Widget _detailRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Icon(icon, size: 16, color: AppColors.textSecondary),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary))),
    ]),
  );

  Widget _featureChip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.07),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: AppColors.primary),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
    ]),
  );
}
