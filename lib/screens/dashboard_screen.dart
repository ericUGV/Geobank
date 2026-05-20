import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatelessWidget {
  Future<Map<String, dynamic>> _loadStats() async {
    final snap = await FirebaseFirestore.instance.collection('clientes').get();
    Map<String, int> counts = {
      'clienteBB_Minha': 0, 'clienteBB_Outra': 0,
      'concorrente': 0, 'novaOportunidade': 0, 'leadFrio': 0,
    };
    double totalScore = 0;
    for (var d in snap.docs) {
      final status = d['status'] ?? 'leadFrio';
      counts[status] = (counts[status] ?? 0) + 1;
      totalScore += (d['score'] ?? 0).toDouble();
    }
    return {
      'counts': counts,
      'total': snap.docs.length,
      'avgScore': snap.docs.isEmpty ? 0.0 : totalScore / snap.docs.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Olá, gerente!", style: TextStyle(color: Colors.white70, fontSize: 14)),
                              const SizedBox(height: 2),
                              Text(
                                user?.email?.split('@').first ?? "Usuário",
                                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const CircleAvatar(backgroundColor: AppColors.accent, child: Icon(Icons.person, color: AppColors.primary)),
                          onSelected: (v) async {
                            if (v == 'logout') await FirebaseAuth.instance.signOut();
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout, color: Colors.red, size: 18), SizedBox(width: 8), Text("Sair")])),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: AppColors.accent, size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              "GPS de Prospecção ativo",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text("Online", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Stats
            SliverToBoxAdapter(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _loadStats(),
                builder: (context, snap) {
                  if (!snap.hasData) return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: AppColors.primary)));

                  final counts = snap.data!['counts'] as Map<String, int>;
                  final total = snap.data!['total'] as int;
                  final avgScore = snap.data!['avgScore'] as double;

                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // KPI row
                        Row(
                          children: [
                            _kpiCard("Total", "$total", Icons.business, AppColors.primary, flex: 1),
                            const SizedBox(width: 12),
                            _kpiCard("Score Médio", "${avgScore.toStringAsFixed(0)}", Icons.star, AppTheme.scoreColor(avgScore), flex: 1),
                          ],
                        ),
                        const SizedBox(height: 20),

                        const Text("Carteira por Status", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 12),

                        _statusCard('clienteBB_Minha', counts),
                        _statusCard('clienteBB_Outra', counts),
                        _statusCard('concorrente', counts),
                        _statusCard('novaOportunidade', counts),
                        _statusCard('leadFrio', counts),

                        const SizedBox(height: 20),
                        const Text("Legenda de Cores", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 12),
                        _legendCard(),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _statusCard(String status, Map<String, int> counts) {
    final color = AppTheme.statusColor(status);
    final label = AppTheme.statusLabel(status);
    final count = counts[status] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
            child: Text("$count", style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _legendCard() {
    final items = [
      ('clienteBB_Minha', '🔵 Minha Carteira BB'),
      ('clienteBB_Outra', '🟡 Outra Carteira BB'),
      ('concorrente', '🔴 Cliente Concorrente'),
      ('novaOportunidade', '🟣 Nova Empresa'),
      ('leadFrio', '⚪ Lead Frio'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: items.map((e) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: AppTheme.statusColor(e.$1), shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Text(e.$2, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        )).toList(),
      ),
    );
  }
}
