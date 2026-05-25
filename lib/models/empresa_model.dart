// lib/models/empresa_model.dart
// CORRIGIDO:
//  - fromFirestore() com null-check em dataAbertura (não crasha se campo ausente)
//  - getStatusColor() usa cores consistentes com AppTheme

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class Empresa {
  final String id;
  final String nome;
  final String cnpj;
  final String cnae;
  final double capitalSocial;
  final String status;
  final GeoPoint localizacao;
  final DateTime dataAbertura;
  final double score;

  Empresa({
    required this.id,
    required this.nome,
    required this.cnpj,
    required this.cnae,
    required this.capitalSocial,
    required this.status,
    required this.localizacao,
    required this.dataAbertura,
    required this.score,
  });

  factory Empresa.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // FIX: null-safe parse de dataAbertura — campo ausente em cadastros manuais
    DateTime dataAbertura;
    final raw = data['dataAbertura'];
    if (raw is Timestamp) {
      dataAbertura = raw.toDate();
    } else if (raw is String && raw.isNotEmpty) {
      dataAbertura = DateTime.tryParse(raw) ?? DateTime(2000);
    } else {
      dataAbertura = DateTime(2000);
    }

    return Empresa(
      id:            doc.id,
      nome:          (data['nome']         ?? '').toString(),
      cnpj:          (data['cnpj']         ?? '').toString(),
      cnae:          (data['cnae']         ?? '').toString(),
      capitalSocial: (data['capitalSocial'] ?? 0).toDouble(),
      status:        (data['status']       ?? 'leadFrio').toString(),
      localizacao:   data['localizacao']   as GeoPoint? ?? const GeoPoint(0, 0),
      dataAbertura:  dataAbertura,
      score:         (data['score']        ?? 0).toDouble(),
    );
  }

  // FIX: delega para AppTheme.scoreColor — consistente com o resto do app
  static Color getScoreColor(double score) => AppTheme.scoreColor(score);

  // FIX: delega para AppTheme.statusColor — cores idênticas às do mapa e carteira
  static Color getStatusColor(String status) => AppTheme.statusColor(status);
}