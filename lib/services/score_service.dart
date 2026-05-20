// lib/services/score_service.dart
// Score de prospecção com 3 critérios: capital social + CNAE + localização

class ScoreService {
  // Municípios estratégicos para o Banco do Brasil no Paraná
  // (cidades com maior volume comercial / agronegócio)
  static const List<String> _municipiosEstrategicos = [
    'CURITIBA', 'LONDRINA', 'MARINGA', 'PONTA GROSSA', 'CASCAVEL',
    'SAO JOSE DOS PINHAIS', 'FOZ DO IGUACU', 'COLOMBO', 'GUARAPUAVA',
    'PARANAGUA', 'ARAUCARIA', 'TOLEDO', 'APUCARANA', 'PINHAIS',
    'CAMPO LARGO', 'SAO MATEUS DO SUL', 'UNIAO DA VITORIA', 'IRATI',
    'FRANCISCO BELTRAO', 'CORNELIO PROCOPIO',
  ];

  static const List<String> _cnaesEstrategicos = [
    '01', // Agropecuária
    '10', // Ind. de Alimentos
    '11', // Bebidas
    '46', // Comércio Atacadista
    '47', // Comércio Varejista
    '41', // Construção de Edifícios
    '42', // Obras de Infraestrutura
    '49', // Transporte Terrestre
    '64', // Serviços Financeiros
    '68', // Atividades Imobiliárias
  ];

  /// Calcula o score de prospecção (0–100 pts)
  ///
  /// Critérios:
  ///  - Capital Social  → até 50 pts
  ///  - Segmento (CNAE) → até 30 pts
  ///  - Localização     → até 20 pts
  static double calcularScore({
    required double capitalSocial,
    required String cnae,
    String municipio = '',
    String uf = '',
  }) {
    double score = 0;

    // ── 1. Capital Social (máx 50 pts) ──────────────────────────────────
    if (capitalSocial >= 500000) {
      score += 50;
    } else if (capitalSocial >= 100000) {
      score += 35;
    } else if (capitalSocial >= 50000) {
      score += 25;
    } else if (capitalSocial >= 10000) {
      score += 15;
    } else {
      score += 5;
    }

    // ── 2. Segmento CNAE (máx 30 pts) ───────────────────────────────────
    if (cnae.length >= 2) {
      final prefixo = cnae.substring(0, 2);
      if (_cnaesEstrategicos.contains(prefixo)) {
        score += 30;
      } else {
        score += 10;
      }
    } else {
      score += 10;
    }

    // ── 3. Localização (máx 20 pts) ──────────────────────────────────────
    final munNorm = _normalizar(municipio);
    final ufNorm = uf.toUpperCase().trim();

    if (_municipiosEstrategicos.contains(munNorm)) {
      score += 20; // município estratégico
    } else if (ufNorm == 'PR' || ufNorm == 'SC' || ufNorm == 'RS') {
      score += 12; // Sul do Brasil (região de atuação prioritária)
    } else if (ufNorm.isNotEmpty) {
      score += 6; // outro estado
    }

    return score.clamp(0, 100);
  }

  /// Remove acentos e normaliza para comparação
  static String _normalizar(String s) {
    const de = 'áàãâäéèêëíìîïóòõôöúùûüçÁÀÃÂÄÉÈÊËÍÌÎÏÓÒÕÔÖÚÙÛÜÇ';
    const para = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
    var result = s.toUpperCase().trim();
    for (var i = 0; i < de.length; i++) {
      result = result.replaceAll(de[i], para[i]);
    }
    return result;
  }
}