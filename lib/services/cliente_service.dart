import 'package:cloud_firestore/cloud_firestore.dart';

class ClienteService {
  final _db = FirebaseFirestore.instance;

  Future<void> addCliente(Map<String, dynamic> data) async {
    await _db.collection('clientes').add(data);
  }

  Future<List<QueryDocumentSnapshot>> getClientes() async {
    final snapshot = await _db.collection('clientes').get();
    return snapshot.docs;
  }
}