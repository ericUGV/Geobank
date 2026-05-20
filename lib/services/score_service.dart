class ScoreService {
  static double calcularScore({
    required double capitalSocial,
    required String cnae,
  }) {
    double score = 0;

    // 1. Pontuação por Capital Social (Máximo 60 pts)
    if (capitalSocial >= 500000) score += 60; // Grande porte
    else if (capitalSocial >= 100000) score += 40; // Médio porte
    else if (capitalSocial >= 10000) score += 20; // Pequeno porte
    else score += 5;

    // 2. Pontuação por Segmento (Máximo 40 pts)
    // Exemplos de CNAEs estratégicos para o BB (Indústrias e Agronegócio)
    List<String> cnaesEstrategicos = [
      "01", // Agro
      "10", // Indústria de Alimentos
      "46", // Comércio Atacadista
    ];

    // Verifica se os primeiros dois dígitos do CNAE são estratégicos
    String prefixo = cnae.substring(0, 2);
    if (cnaesEstrategicos.contains(prefixo)) {
      score += 40;
    } else {
      score += 15; // Outros segmentos
    }

    return score;
  }
}
