import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutur_id_app/core/network/api_client.dart';
import 'package:tutur_id_app/core/services/cloudinary_service.dart';
import 'package:tutur_id_app/core/services/firebase_service.dart';
import 'package:tutur_id_app/core/services/midtrans_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
final firebaseServiceProvider = Provider<FirebaseService>(
  (ref) => FirebaseService(),
);

final cloudinaryServiceProvider = Provider<CloudinaryService>(
  (ref) => CloudinaryService(),
);

final midtransServiceProvider = Provider<MidtransService>((ref) {
  return MidtransService(ref.watch(apiClientProvider));
});
