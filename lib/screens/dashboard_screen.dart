// lib/screens/dashboard_screen.dart
// CORRIGIDO:
//  - StreamBuilder (dados em tempo real, não FutureBuilder)
//  - Pull-to-refresh
//  - Gráfico de pizza (distribuição por status) — fl_chart
//  - Gráfico de barras (score médio por status) — fl_chart
//  - Tratamento de erro quando Firestore offline
//  - Confirmação antes de logout

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _touchedIndex = -1;

  // Monta stats a partir de um snapshot já carregado
  Map<String, dynamic> _buildStats(QuerySnapshot snapshot) {
    final counts = <String, int>{
      'clienteBB_Minha': 0,
      'clienteBB_Outra': 0,
      'concorrente': 0,
      'novaOportunidade': 0,
      'leadFrio': 0,
    };
    final scoreSums = <String, double>{for (final k in counts.keys) k: 0};
    double totalScore = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] ?? 'leadFrio') as String;
      counts[status] = (counts[status] ?? 0) + 1;
      final s = (data['score'] ?? 0).toDouble();
      scoreSums[status] = (scoreSums[status] ?? 0) + s;
      totalScore += s;
    }

    final avgScores = <String, double>{};
    for (final k in counts.keys) {
      avgScores[k] = counts[k]! > 0 ? scoreSums[k]! / counts[k]! : 0;
    }

    return {
      'counts': counts,
      'total': snapshot.docs.length,
      'avgScore': snapshot.docs.isEmpty ? 0.0 : totalScore / snapshot.docs.length,
      'avgScores': avgScores,
    };
  }

  Future<void> _confirmarLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sair do GeoBank'),
        content: const Text('Tem certeza que deseja encerrar a sessão?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (ok == true) await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('clientes').snapshots(),
          builder: (context, snapshot) {
            // Erro de conexão
            if (snapshot.hasError) {
              return _errorState(snapshot.error.toString());
            }

            final isLoading = snapshot.connectionState == ConnectionState.waiting;
            final stats = snapshot.hasData ? _buildStats(snapshot.data!) : null;

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                // StreamBuilder atualiza sozinho — basta aguardar um frame
                await Future.delayed(const Duration(milliseconds: 300));
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Olá, gerente!',
                                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                                    const SizedBox(height: 2),
                                    Text(
                                      user?.email?.split('@').first ?? 'Usuário',
                                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const CircleAvatar(
                                    backgroundColor: AppColors.accent,
                                    child: Icon(Icons.person, color: AppColors.primary)),
                                onPressed: () => _confirmarLogout(context),
                                tooltip: 'Sair',
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(children: [
                              const Icon(Icons.location_on, color: AppColors.accent, size: 20),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text('GPS de Prospecção ativo',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: const Color(0xFF16A34A), borderRadius: BorderRadius.circular(20)),
                                child: const Text('Online', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                              ),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (isLoading)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    )
                  else if (stats != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // KPIs
                            Row(children: [
                              _kpiCard('Total', '${stats['total']}', Icons.business, AppColors.primary),
                              const SizedBox(width: 12),
                              _kpiCard('Score Médio',
                                  '${(stats['avgScore'] as double).toStringAsFixed(0)}',
                                  Icons.star,
                                  AppTheme.scoreColor(stats['avgScore'] as double)),
                            ]),
                            const SizedBox(height: 24),

                            // ── Gráfico de pizza ──────────────────────────
                            const Text('Distribuição da Carteira',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            const SizedBox(height: 4),
                            const Text('Participação de cada status no total de empresas',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(height: 16),

                            stats['total'] == 0
                                ? _emptyChart('Nenhuma empresa cadastrada ainda.')
                                : _pieChart(stats),

                            const SizedBox(height: 24),

                            // ── Gráfico de barras ─────────────────────────
                            const Text('Score Médio por Status',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            const SizedBox(height: 4),
                            const Text('Potencial médio de prospecção por categoria',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(height: 16),

                            stats['total'] == 0
                                ? _emptyChart('Adicione empresas para ver os scores.')
                                : _barChart(stats),

                            const SizedBox(height: 24),

                            // ── Contagem por status ───────────────────────
                            const Text('Carteira por Status',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            const SizedBox(height: 12),

                            ...(stats['counts'] as Map<String, int>).entries.map(
                                    (e) => _statusCard(e.key, e.value)),

                            const SizedBox(height: 20),
                            _legendCard(),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Gráfico de pizza ────────────────────────────────────────────────────────

  Widget _pieChart(Map<String, dynamic> stats) {
    final counts = stats['counts'] as Map<String, int>;
    final total = stats['total'] as int;

    final statusKeys = ['clienteBB_Minha', 'clienteBB_Outra', 'concorrente', 'novaOportunidade', 'leadFrio'];
    final sections = <PieChartSectionData>[];

    for (var i = 0; i < statusKeys.length; i++) {
      final key = statusKeys[i];
      final count = counts[key] ?? 0;
      if (count == 0) continue;
      final pct = count / total * 100;
      final isTouched = _touchedIndex == i;
      sections.add(PieChartSectionData(
        value: count.toDouble(),
        color: AppTheme.statusColor(key),
        radius: isTouched ? 62 : 54,
        title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        badgeWidget: isTouched
            ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: AppTheme.statusColor(key),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]),
          child: Text('$count empresa${count > 1 ? 's' : ''}',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        )
            : null,
        badgePositionPercentageOffset: 1.3,
      ));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    if (!event.isInterestedForInteractions || response?.touchedSection == null) {
                      _touchedIndex = -1;
                    } else {
                      _touchedIndex = response!.touchedSection!.touchedSectionIndex;
                    }
                  });
                },
              ),
              sections: sections,
              centerSpaceRadius: 48,
              sectionsSpace: 3,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14, runSpacing: 8,
          alignment: WrapAlignment.center,
          children: statusKeys.where((k) => (counts[k] ?? 0) > 0).map((k) {
            return Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: AppTheme.statusColor(k), shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(AppTheme.statusLabel(k), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ]);
          }).toList(),
        ),
      ]),
    );
  }

  // ── Gráfico de barras ───────────────────────────────────────────────────────

  Widget _barChart(Map<String, dynamic> stats) {
    final avgScores = stats['avgScores'] as Map<String, double>;
    final statusKeys = ['clienteBB_Minha', 'clienteBB_Outra', 'concorrente', 'novaOportunidade', 'leadFrio'];

    final groups = <BarChartGroupData>[];
    for (var i = 0; i < statusKeys.length; i++) {
      final key = statusKeys[i];
      final score = avgScores[key] ?? 0;
      groups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: score,
            color: AppTheme.statusColor(key),
            width: 22,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: 100,
              color: AppColors.surface,
            ),
          ),
        ],
      ));
    }

    final labels = ['Minha\nCart.', 'Outra\nCart.', 'Concor.', 'Nova\nEmp.', 'Lead\nFrio'];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            maxY: 100,
            barGroups: groups,
            gridData: FlGridData(
              show: true,
              horizontalInterval: 25,
              getDrawingHorizontalLine: (_) => FlLine(color: AppColors.divider, strokeWidth: 0.8),
              drawVerticalLine: false,
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: 25,
                  getTitlesWidget: (v, _) => Text(
                    '${v.toInt()}',
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  getTitlesWidget: (v, _) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      labels[v.toInt()],
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                tooltipBgColor: AppColors.primary,
                getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                  'Score: ${rod.toY.toStringAsFixed(0)}',
                  const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _emptyChart(String msg) => Container(
    height: 120,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.divider),
    ),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.bar_chart_outlined, size: 36, color: AppColors.divider),
      const SizedBox(height: 8),
      Text(msg, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
    ]),
  );

  Widget _errorState(String error) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.wifi_off_rounded, size: 60, color: AppColors.divider),
        const SizedBox(height: 16),
        const Text('Sem conexão com o servidor',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text(error, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ]),
    ),
  );

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }

  Widget _statusCard(String status, int count) {
    final color = AppTheme.statusColor(status);
    final label = AppTheme.statusLabel(status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
          child: Text('$count', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
        ),
      ]),
    );
  }

  Widget _legendCard() {
    final items = [
      ('clienteBB_Minha', '🔵 Minha Carteira BB'),
      ('clienteBB_Outra', '🟡 Outra Carteira BB'),
      ('concorrente',     '🔴 Cliente Concorrente'),
      ('novaOportunidade','🟣 Nova Empresa'),
      ('leadFrio',        '⚪ Lead Frio'),
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
          child: Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: AppTheme.statusColor(e.$1), shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Text(e.$2, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ]),
        )).toList(),
      ),
    );
  }
}