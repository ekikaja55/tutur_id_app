import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // setup auth
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate();
    if (googleUser == null) {
      throw Exception("User cancel login attempt");
    }
    final GoogleSignInAuthentication googleAuth = googleUser.authentication;
    final credentials = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    return _auth.signInWithCredential(credentials);
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // setup firestore generic
  Future<Map<String, dynamic>?> getDocument(
    String collection,
    String docId,
  ) async {
    final doc = await _firestore.collection(collection).doc(docId).get();
    return doc.data();
  }

  // queryBuilder adalah sebuah fungsi callback (Higher-Order Function) yang menerima input bertipe Query dan mengembalikan nilai bertipe Query pula.
  // Mengapa dipakai? Supaya fungsi getCollection ini fleksibel! Pemanggil fungsi bisa menyaring data (filter, sort, limit) dari luar tanpa perlu mengubah isi fungsi getCollection.

  // contoh  Mengambil collection "users" yang berumur > 20 dan di-limit 10 data tapi bisa nullable
  // getCollection('users', queryBuilder: (q) {
  //   return q.where('age', isGreaterThan: 20).limit(10);
  // });

  // 1. snapshot.docs: Ini adalah List berisi kumpulan QueryDocumentSnapshot (dokumen-dokumen mentah dari Firestore).
  // 2. .map((doc) => ...): Seperti .map() di JavaScript, ini memproses tiap dokumen satu per satu untuk diubah bentuknya.
  // 3. doc.data() as Map<String, dynamic>: doc.data() mengambil isi field dokumen Firestore tersebut sebagai Map.
  // 4. { ...doc.data(), 'id': doc.id }:
  // Ini menggunakan Spread Operator (...) persis seperti di JS ({ ...doc.data() }).
  // Tujuannya mengopi seluruh field dokumen, lalu menambahkan/menyisipkan ID dokumen (doc.id) ke dalam Map tersebut. Ini sangat berguna karena ID dokumen di Firestore biasanya terpisah dari isi field-nya.
  // 6. .toList(): Fungsi .map() di Dart mengembalikan Iterable (kumpulan data malas/lazy list). .toList() bertugas mengubah kembali bentuknya menjadi List resmi sesuai tipe return fungsi, yaitu List<Map<String, dynamic>>.
  Future<List<Map<String, dynamic>>> getCollection(
    String collection, {
    Query Function(Query)? queryBuilder,
  }) async {
    Query query = _firestore.collection(collection);
    if (queryBuilder != null) {
      query = queryBuilder(query);
    }
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id})
        .toList();
  }

  Future<void> setDocument(
    String collection,
    String docId,
    Map<String, dynamic> data, {
    bool merge = true,
  }) async {
    await _firestore
        .collection(collection)
        .doc(docId)
        .set(data, SetOptions(merge: merge));
  }

  Future<void> updateDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    await _firestore.collection(collection).doc(docId).update(data);
  }

  Future<void> deleteDocument(String collection, String docId) async {
    await _firestore.collection(collection).doc(docId).delete();
  }

  Stream<Map<String, dynamic>?> streamDocument(
    String collection,
    String docId,
  ) {
    return _firestore
        .collection(collection)
        .doc(docId)
        .snapshots()
        .map((doc) => doc.data());
  }

  Stream<List<Map<String, dynamic>>> streamCollection(
    String collection, {
    Query Function(Query)? queryBuilder,
  }) {
    Query query = _firestore.collection(collection);
    if (queryBuilder != null) {
      query = queryBuilder(query);
    }

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id})
          .toList(),
    );
  }

  // handling sub collection
  Stream<List<Map<String, dynamic>>> streamSubcollection(
    String parentCollection,
    String parentId,
    String subcollection, {
    Query Function(Query)? queryBuilder,
  }) {
    Query query = _firestore
        .collection(parentCollection)
        .doc(parentId)
        .collection(subcollection);
    if (queryBuilder != null) {
      query = queryBuilder(query);
    }
    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id})
          .toList(),
    );
  }

  Future<void> setSubcollectionDocument(
    String parentCollection,
    String parentId,
    String subcollection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    await _firestore
        .collection(parentCollection)
        .doc(parentId)
        .collection(subcollection)
        .doc(docId)
        .set(data, SetOptions(merge: true));
  }

  Future<void> updateSubcollectionDocument(
    String parentCollection,
    String parentId,
    String subcollection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    await _firestore
        .collection(parentCollection)
        .doc(parentId)
        .collection(subcollection)
        .doc(docId)
        .update(data);
  }
}
