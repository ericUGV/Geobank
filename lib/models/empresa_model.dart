import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
    Map data = doc.data() as Map;
    return Empresa(
      id: doc.id,
      nome: data['nome'] ?? '',
      cnpj: data['cnpj'] ?? '',
      cnae: data['cnae'] ?? '',
      capitalSocial: (data['capitalSocial'] ?? 0).toDouble(),
      status: data['status'] ?? 'leadFrio',
      localizacao: data['localizacao'] ?? GeoPoint(0, 0),
      dataAbertura: (data['dataAbertura'] as Timestamp).toDate(),
      score: (data['score'] ?? 0).toDouble(),
    );
  }

  // Cor baseada no Potencial (Score)
  static Color getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  // Cor baseada na Categoria (Status) - Proposta original
  static Color getStatusColor(String status) {
    switch (status) {
      case 'clienteBB_Minha': return Colors.blue;      // 🔵 Cliente BB
      case 'clienteBB_Outra': return Colors.yellow;    // 🟡 Outra Carteira
      case 'concorrente': return Colors.red;          // 🔴 Concorrente
      case 'novaOportunidade': return Colors.purple;   // 🟣 Nova Empresa
      default: return Colors.grey;                    // ⚪ Lead Frio
    }
  }
}
