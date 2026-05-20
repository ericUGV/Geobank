import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  static salvar(Map<String, dynamic> data) async {
    await FirebaseFirestore.instance.collection('empresas').add(data);
  }
}
