import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream para contar dispositivos
  Stream<int> getDispositivosCount() {
    return _db.collection('dispositivos').snapshots().map((snap) => snap.docs.length);
  }

  // Stream para contar utilizações
  Stream<int> getUtilizacoesCount() {
    return _db.collection('utilizacoes').snapshots().map((snap) => snap.docs.length);
  }

  // Stream para contar categorias
  Stream<int> getCategoriasCount() {
    return _db.collection('categorias').snapshots().map((snap) => snap.docs.length);
  }
}
