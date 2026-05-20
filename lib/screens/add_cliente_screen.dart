import 'package:flutter/material.dart';
import '../services/cliente_service.dart';
import '../theme/app_theme.dart';

class AddClienteScreen extends StatefulWidget {
  @override
  _AddClienteScreenState createState() => _AddClienteScreenState();
}

class _AddClienteScreenState extends State<AddClienteScreen> {
  final nome = TextEditingController();
  final cnpj = TextEditingController();
  final service = ClienteService();
  String _status = 'leadFrio';
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text("Novo Cliente"),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Nome / Razão Social", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            TextField(
              controller: nome,
              decoration: InputDecoration(
                hintText: "Nome da empresa",
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.divider)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.divider)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text("CNPJ", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            TextField(
              controller: cnpj,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: "00.000.000/0000-00",
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.divider)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.divider)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text("Status", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _status,
                  items: const [
                    DropdownMenuItem(value: 'clienteBB_Minha', child: Text("🔵 Minha Carteira BB")),
                    DropdownMenuItem(value: 'clienteBB_Outra', child: Text("🟡 Outra Carteira BB")),
                    DropdownMenuItem(value: 'concorrente', child: Text("🔴 Cliente Concorrente")),
                    DropdownMenuItem(value: 'novaOportunidade', child: Text("🟣 Nova Oportunidade")),
                    DropdownMenuItem(value: 'leadFrio', child: Text("⚪ Lead Frio")),
                  ],
                  onChanged: (v) => setState(() => _status = v!),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : () async {
                  setState(() => _saving = true);
                  await service.addCliente({
                    "nome": nome.text,
                    "cnpj": cnpj.text,
                    "lat": -25.42, "lng": -49.27,
                    "banco": "Banco do Brasil",
                    "status": _status,
                  });
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Salvar Cliente", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
