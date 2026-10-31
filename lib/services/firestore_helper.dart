import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class AppFirestore {
  static FirebaseFirestore get instance {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseId: 'default',
        );
      }
    } catch (_) {}
    return FirebaseFirestore.instance;
  }
}

