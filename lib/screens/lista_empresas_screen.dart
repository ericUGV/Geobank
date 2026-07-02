import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/navigation_service.dart';
import '../theme/app_theme.dart';
import 'checkin_screen.dart';

class ListaEmpresasScreen extends StatefulWidget {
  @override
  _ListaEmpresasScreenState createState() => _ListaEmpresasScreenState();
}

class _ListaEmpresasScreenState extends State<ListaEmpresasScreen> {
  String _busca = "";
  String _filtroStatus = "todos";
  final TextEditingController _searchController = TextEditingController();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  final List<Map<String, String>> _statusOptions = [
    {'key': 'todos', 'label': 'Todos'},
    {'key': 'clienteBB_Minha', 'label': 'Minha Carteira'},
    {'key': 'concorrente', 'label': 'Concorrente'},
    {'key': 'novaOportunidade', 'label': 'Nova Empresa'},
    {'key': 'leadFrio', 'label': 'Lead Frio'},
  ];

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
                  const Text("Minha Carteira", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text("Gestão exclusiva dos seus clientes", style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 14),
                  // Search bar
                  TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _busca = v.toLowerCase()),
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: "Pesquisar na minha carteira...",
                      hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                      suffixIcon: _busca.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18, color: AppColors.textSecondary),
                              onPressed: () { _searchController.clear(); setState(() => _busca = ""); },
                            )
                          : null,
                      filled: true, fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
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
                    final color = opt['key'] == 'todos' ? AppColors.primary : AppTheme.statusColor(opt['key']!);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(opt['label']!, style: TextStyle(fontSize: 12, color: selected ? Colors.white : AppColors.textSecondary, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
                        selected: selected,
                        onSelected: (_) => setState(() => _filtroStatus = opt['key']!),
                        backgroundColor: Colors.white,
                        selectedColor: color,
                        checkmarkColor: Colors.white,
                        side: BorderSide(color: selected ? color : AppColors.divider),
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const Divider(height: 1, color: AppColors.divider),

            // List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('clientes').orderBy('score', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _emptyState("Nenhuma empresa na sua carteira.", Icons.business_outlined);
                  }

                  // Filtra para mostrar apenas clientes do usuário logado
                  var docs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    
                    // Verificação de Propriedade: apenas documentos do usuário atual
                    final isMine = data['gerenteId'] == _currentUserId;
                    if (!isMine) return false;

                    final nome = (data['nome'] ?? '').toString().toLowerCase();
                    final statusOk = _filtroStatus == 'todos' || data['status'] == _filtroStatus;
                    
                    return nome.contains(_busca) && statusOk;
                  }).toList();

                  if (docs.isEmpty) return _emptyState("Nenhum resultado encontrado na sua carteira.", Icons.search_off);

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      return _empresaCard(context, doc.id, data);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empresaCard(BuildContext context, String docId, Map<String, dynamic> data) {
    final status = data['status'] ?? 'leadFrio';
    final statusColor = AppTheme.statusColor(status);
    final statusLabel = AppTheme.statusLabel(status);
    final score = (data['score'] ?? 0).toDouble();
    final scoreColor = AppTheme.scoreColor(score);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        border: Border(left: BorderSide(color: statusColor, width: 4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showEmpresaDetails(context, docId, data),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      data['nome'] ?? 'Sem nome',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: scoreColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, size: 12, color: scoreColor),
                        const SizedBox(width: 3),
                        Text("${score.toInt()}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: scoreColor)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (data['cnpj'] != null) ...[
                Text("CNPJ: ${data['cnpj']}", style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 3),
              ],
              if (data['cnae'] != null) ...[
                Text(data['cnae'], style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 7, height: 7, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (data['ultimaVisita'] != null)
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          "Visitado: ${data['ultimaVisita']}",
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmpresaDetails(BuildContext context, String docId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text(data['nome'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            _detailRow(Icons.badge_outlined, "CNPJ", data['cnpj'] ?? '-'),
            _detailRow(Icons.category_outlined, "CNAE", data['cnae'] ?? '-'),
            _detailRow(Icons.account_balance_outlined, "Banco Domicílio", data['bancoDomicilio'] ?? '-'),
            _detailRow(Icons.attach_money, "Capital Social", data['capitalSocial'] != null ? "R\$ ${data['capitalSocial']}" : '-'),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      if (data['localizacao'] != null) {
                        NavigationService.abrirRota(data['localizacao'], data['nome']);
                      }
                    },
                    icon: const Icon(Icons.navigation_outlined, size: 18),
                    label: const Text("Navegar"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => CheckinScreen(docId: docId, nomeEmpresa: data['nome'] ?? '')));
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text("Check-in"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
        ]),
      ],
    ),
  );

  Widget _emptyState(String msg, IconData icon) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 60, color: AppColors.divider),
      const SizedBox(height: 16),
      Text(msg, style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
    ]),
  );
}
