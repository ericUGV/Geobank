// lib/screens/cadastro_empresa_screen.dart
// CORRIGIDO: busca real na BrasilAPI por CNPJ (sem mock data)

import 'package:flutter/material.dart';
import '../services/cnpj_service.dart';
import '../theme/app_theme.dart';

class CadastroEmpresaScreen extends StatefulWidget {
  @override
  _CadastroEmpresaScreenState createState() => _CadastroEmpresaScreenState();
}

class _CadastroEmpresaScreenState extends State<CadastroEmpresaScreen> {
  final _cnpjController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _empresaDetalhada;
  String? _erro;

  @override
  void dispose() {
    _cnpjController.dispose();
    super.dispose();
  }

  Future<void> _buscarPorCnpj() async {
    final texto = _cnpjController.text.trim();
    if (texto.isEmpty) return;

    final cnpj = texto.replaceAll(RegExp(r'[^0-9]'), '');
    if (cnpj.length != 14) {
      setState(() => _erro = 'Digite um CNPJ completo com 14 dígitos.');
      return;
    }

    setState(() { _isLoading = true; _empresaDetalhada = null; _erro = null; });

    final resultado = await CnpjService.buscarECadastrar(cnpj);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (resultado != null) {
        _empresaDetalhada = resultado;
      } else {
        _erro = 'CNPJ não encontrado ou API indisponível.\nVerifique o número e tente novamente.';
      }
    });

    if (resultado != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text("'${resultado['nome']}' adicionada à carteira!")),
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
                  borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.radar, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cadastrar Empresa',
                                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            Text('Busca por CNPJ na Receita Federal',
                                style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Campo CNPJ
                    TextField(
                      controller: _cnpjController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.textPrimary, letterSpacing: 1.2),
                      onSubmitted: (_) => _buscarPorCnpj(),
                      decoration: InputDecoration(
                        hintText: '00.000.000/0000-00',
                        hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.textSecondary),
                        suffixIcon: _cnpjController.text.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: AppColors.textSecondary),
                          onPressed: () {
                            _cnpjController.clear();
                            setState(() { _empresaDetalhada = null; _erro = null; });
                          },
                        )
                            : null,
                        filled: true, fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _buscarPorCnpj,
                        icon: _isLoading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                            : const Icon(Icons.search, size: 20),
                        label: Text(_isLoading ? 'Consultando Receita Federal...' : 'Buscar CNPJ'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          disabledBackgroundColor: AppColors.accent.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Erro
            if (_erro != null)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade400, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_erro!,
                            style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),

            // Resultado
            if (_empresaDetalhada != null)
              SliverToBoxAdapter(child: _buildResultado(_empresaDetalhada!)),

            // Estado inicial — instruções
            if (_empresaDetalhada == null && _erro == null && !_isLoading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Container(
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
                          decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08), shape: BoxShape.circle),
                          child: const Icon(Icons.search_outlined, size: 32, color: AppColors.primary),
                        ),
                        const SizedBox(height: 16),
                        const Text('Busca por CNPJ',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        const Text(
                          'Digite o CNPJ da empresa acima. O sistema consulta os dados diretamente na Receita Federal, calcula o score de prospecção e adiciona automaticamente à sua carteira.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _chip(Icons.gps_fixed, 'Geocodificação automática'),
                            _chip(Icons.star_outline, 'Score calculado'),
                            _chip(Icons.business_center, 'Dados da Receita Federal'),
                            _chip(Icons.add_location, 'Aparece no mapa'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultado(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.all(16),
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
          // Cabeçalho
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Empresa adicionada à carteira!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF16A34A))),
            ],
          ),
          const Divider(height: 24),

          // Score
          if (data['score'] != null) ...[
            Row(
              children: [
                const Text('Score de Prospecção',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.scoreColor((data['score'] as num).toDouble()).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.star, size: 14, color: AppTheme.scoreColor((data['score'] as num).toDouble())),
                    const SizedBox(width: 4),
                    Text('${(data['score'] as num).toInt()} / 100',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14,
                            color: AppTheme.scoreColor((data['score'] as num).toDouble()))),
                  ]),
                ),
              ],
            ),
            const Divider(height: 20),
          ],

          // Dados
          _row(Icons.business, 'Razão Social', data['nome'] ?? ''),
          if ((data['nomeFantasia'] ?? '').toString().isNotEmpty)
            _row(Icons.storefront_outlined, 'Nome Fantasia', data['nomeFantasia']),
          _row(Icons.badge_outlined, 'CNPJ', data['cnpj'] ?? ''),
          if ((data['cnae'] ?? '').toString().isNotEmpty)
            _row(Icons.category_outlined, 'CNAE', data['cnae']),
          if ((data['enderecoCompleto'] ?? '').toString().isNotEmpty)
            _row(Icons.location_on_outlined, 'Endereço', data['enderecoCompleto']),
          if ((data['situacao'] ?? '').toString().isNotEmpty)
            _row(Icons.info_outline, 'Situação', data['situacao']),
          if ((data['porte'] ?? '').toString().isNotEmpty)
            _row(Icons.business_center_outlined, 'Porte', data['porte']),
          if (data['capitalSocial'] != null && (data['capitalSocial'] as num) > 0)
            _row(Icons.attach_money, 'Capital Social',
                'R\$ ${_formatarValor((data['capitalSocial'] as num).toDouble())}'),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: AppColors.primary),
      const SizedBox(width: 8),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
        ]),
      ),
    ]),
  );

  Widget _chip(IconData icon, String label) => Container(
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

  String _formatarValor(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}