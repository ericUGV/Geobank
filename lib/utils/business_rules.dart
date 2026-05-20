String verificarConcorrencia(String bancoCliente, String meuBanco) {
  if (bancoCliente != meuBanco) {
    return "concorrente";
  }
  return "cliente";
}

String calcularRegiao(double lat) {
  if (lat > -25.40) return "Norte";
  return "Sul";
}

bool precisaVisita(DateTime ultimaVisita) {
  return DateTime.now().difference(ultimaVisita).inDays > 30;
}