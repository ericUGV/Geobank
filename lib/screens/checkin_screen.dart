import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

// Supporting both docId and empresaId for backwards compat
class CheckinScreen extends StatefulWidget {
  final String? docId;
  final String? empresaId;
  final String nomeEmpresa;
  final String statusAtual;

  const CheckinScreen({
    this.docId,
    this.empresaId,
    required this.nomeEmpresa,
    this.statusAtual = 'leadFrio',
  });

  @override
  _CheckinScreenState createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  late String _statusSelecionado;
  final _comentarioController = TextEditingController();
  bool _saving = false;

  final List<Map<String, dynamic>> _statusOptions = [
    {'value': 'clienteBB_Minha', 'label': 'Minha Carteira BB', 'icon': '🔵'},
    {'value': 'clienteBB_Outra', 'label': 'Outra Carteira BB', 'icon': '🟡'},
    {'value': 'concorrente', 'label': 'Cliente Concorrente', 'icon': '🔴'},
    {'value': 'novaOportunidade', 'label': 'Nova Oportunidade', 'icon': '🟣'},
    {'value': 'leadFrio', 'label': 'Lead Frio', 'icon': '⚪'},
  ];

  @override
  void initState() {
    super.initState();
    _statusSelecionado = widget.statusAtual;
  }

  String get _docId => widget.docId ?? widget.empresaId ?? '';

  Future<void> _salvarCheckIn() async {
    if (_docId.isEmpty) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('clientes').doc(_docId).update({
        'status': _statusSelecionado,
        'ultimaVisita': DateTime.now().toIso8601String().split('T').first,
        'ultimoComentario': _comentarioController.text,
      });
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text("Visita registrada com sucesso!"),
          ]),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text("Registrar Visita"),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Company header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.business, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.nomeEmpresa, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                        const Text("Check-in de visita", style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Status section
            const Text("Status da Prospecção", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text("Selecione o status atual desta empresa", style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),

            ..._statusOptions.map((opt) {
              final selected = _statusSelecionado == opt['value'];
              final color = AppTheme.statusColor(opt['value'] as String);
              return GestureDetector(
                onTap: () => setState(() => _statusSelecionado = opt['value'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: selected ? color.withOpacity(0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? color : AppColors.divider,
                      width: selected ? 2 : 1,
                    ),
                    boxShadow: selected ? [BoxShadow(color: color.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))] : [],
                  ),
                  child: Row(
                    children: [
                      Text(opt['icon'] as String, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          opt['label'] as String,
                          style: TextStyle(
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            color: selected ? color : AppColors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (selected) Icon(Icons.check_circle, color: color, size: 20),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 24),

            // Notes section
            const Text("Resumo da Visita", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text("Anote os pontos principais da visita (opcional)", style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: _comentarioController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "Ex: Cliente demonstrou interesse em conta PJ, retornar em 15 dias...",
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _salvarCheckIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 20),
                          SizedBox(width: 8),
                          Text("Concluir Visita", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Alias for backwards compatibility
typedef CheckInScreen = CheckinScreen;
