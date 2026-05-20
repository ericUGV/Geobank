class Cliente {
  String id;
  String nome;
  double lat;
  double lng;
  String banco;
  String gerenteId;
  String status;
  String potencial;

  Cliente({
    required this.id,
    required this.nome,
    required this.lat,
    required this.lng,
    required this.banco,
    required this.gerenteId,
    required this.status,
    required this.potencial,
  });
}