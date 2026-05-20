// lib/screens/rota_multipla_screen.dart
// Seleção de múltiplas empresas para gerar rota otimizada no Google Maps

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/navigation_service.dart';
import '../theme/app_theme.dart';

class RotaMultiplaScreen extends StatefulWidget {
  const RotaMultiplaScreen({super.key});

  @override
  State<RotaMultiplaScreen> createState() => _RotaMultiplaScreenState();
}

class _RotaMultiplaScreenState extends State<RotaMultiplaScreen> {
  final Set<String> _selecionados = {};
  final Map<String, Map<String, dynamic>> _dadosEmpresas = {};
  String _busca = '';
  String _filtroStatus = 'todos';
  bool _gerando = false;

  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, String>> _statusOptions = [
    {'key': 'todos', 'label': 'Todos'},
    {'key': 'clienteBB_Minha', 'label': 'Minha Carteira'},
    {'key': 'clienteBB_Outra', 'label': 'Outra Carteira'},
    {'key': 'concorrente', 'label': 'Concorrente'},
    {'key': 'novaOportunidade', 'label': 'Nova Empresa'},
    {'key': 'leadFrio', 'label': 'Lead Frio'},
  ];

  Future<void> _gerarRota() async {
    if (_selecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Selecione pelo menos uma empresa.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _gerando = true);

    try {
      final destinos = <GeoPoint>[];

      // Ordena por score (maior primeiro = mais próximo do início da rota)
      final empresasOrdenadas = _selecionados
          .map((id) => _dadosEmpresas[id])
          .where((d) => d != null && d['localizacao'] != null)
          .toList()
        ..sort((a, b) =>
            (b!['score'] ?? 0).compareTo(a!['score'] ?? 0));

      for (final empresa in empresasOrdenadas) {
        final geo = empresa!['localizacao'] as GeoPoint;
        if (geo.latitude != 0 || geo.longitude != 0) {
          destinos.add(geo);
        }
      }

      if (destinos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nenhuma empresa selecionada possui localização cadastrada.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await NavigationService.abrirRotaMultipla(destinos);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao abrir rota: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _gerando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              color: AppColors.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rota de Visitas',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Selecione as empresas para a rota otimizada',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Search
                  TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _busca = v.toLowerCase()),
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Pesquisar empresa...',
                      hintStyle: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 14),
                      prefixIcon: const Icon(Icons.search,
                          color: AppColors.textSecondary, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),

            // Filter chips
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: _statusOptions.map((opt) {
                    final selected = _filtroStatus == opt['key'];
                    final color = opt['key'] == 'todos'
                        ? AppColors.primary
                        : AppTheme.statusColor(opt['key']!);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(opt['label']!,
                            style: TextStyle(
                                fontSize: 12,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.normal)),
                        selected: selected,
                        onSelected: (_) =>
                            setState(() => _filtroStatus = opt['key']!),
                        backgroundColor: Colors.white,
                        selectedColor: color,
                        checkmarkColor: Colors.white,
                        side: BorderSide(
                            color: selected ? color : AppColors.divider),
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const Divider(height: 1, color: AppColors.divider),

            // Lista de empresas
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('clientes')
                    .where('localizacao', isNotEqualTo: null)
                    .orderBy('score', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _emptyState();
                  }

                  var docs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    // Atualiza cache de dados
                    _dadosEmpresas[doc.id] = data;
                    final nome =
                    (data['nome'] ?? '').toString().toLowerCase();
                    final statusOk = _filtroStatus == 'todos' ||
                        data['status'] == _filtroStatus;
                    final geo = data['localizacao'] as GeoPoint?;
                    final temGeo =
                        geo != null && (geo.latitude != 0 || geo.longitude != 0);
                    return nome.contains(_busca) && statusOk && temGeo;
                  }).toList();

                  if (docs.isEmpty) {
                    return _emptyState(msg: 'Nenhuma empresa com GPS cadastrado.');
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: docs.length,
                    itemBuilder: (ctx, i) {
                      final doc = docs[i];
                      final data = doc.data() as Map<String, dynamic>;
                      return _empresaCard(doc.id, data);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // Botão flutuante
      bottomNavigationBar: _selecionados.isNotEmpty
          ? SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Resumo das selecionadas
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.route, color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      '${_selecionados.length} empresa(s) selecionada(s)',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() => _selecionados.clear()),
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: const Text('Limpar',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _gerando ? null : _gerarRota,
                  icon: _gerando
                      ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.directions, size: 20),
                  label: Text(
                    _gerando ? 'Abrindo Maps...' : 'Iniciar Rota no Google Maps',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      )
          : null,
    );
  }

  Widget _empresaCard(String docId, Map<String, dynamic> data) {
    final selecionado = _selecionados.contains(docId);
    final status = data['status'] ?? 'leadFrio';
    final statusColor = AppTheme.statusColor(status);
    final score = (data['score'] ?? 0).toDouble();
    final scoreColor = AppTheme.scoreColor(score);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (selecionado) {
            _selecionados.remove(docId);
          } else {
            if (_selecionados.length >= 23) {
              // Google Maps suporta até 23 waypoints
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Máximo de 23 paradas por rota (limite do Google Maps).'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }
            _selecionados.add(docId);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: selecionado
              ? AppColors.primary.withOpacity(0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selecionado ? AppColors.primary : AppColors.divider,
            width: selecionado ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Checkbox visual
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: selecionado ? AppColors.primary : Colors.transparent,
                  border: Border.all(
                    color: selecionado ? AppColors.primary : AppColors.divider,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: selecionado
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
              const SizedBox(width: 12),

              // Dados da empresa
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['nome'] ?? 'Sem nome',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: statusColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          AppTheme.statusLabel(status),
                          style: TextStyle(
                              fontSize: 11,
                              color: statusColor,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 10),
                        if (data['municipio'] != null &&
                            (data['municipio'] as String).isNotEmpty) ...[
                          const Icon(Icons.location_on_outlined,
                              size: 11, color: AppColors.textSecondary),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              '${data['municipio']}/${data['uf'] ?? ''}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Score
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scoreColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 12, color: scoreColor),
                    const SizedBox(width: 3),
                    Text(
                      '${score.toInt()}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: scoreColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState({String msg = 'Nenhuma empresa encontrada.'}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.route, size: 56, color: AppColors.divider),
          const SizedBox(height: 16),
          Text(msg,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 15)),
        ],
      ),
    );
  }
}