class ProspecaoService {
  static Map<String, dynamic> analisar(Map<String, dynamic> data) {
    int score = 0;
    if (data['descricao_porte'] == 'DEMAIS') score += 40;
    if (data['descricao_situacao_cadastral'] == 'ATIVA') score += 30;
    score += 30;

    return {"score": score, "status": "Prospect"};
  }
}