import 'package:dio/dio.dart';
import 'package:tutur_id_app/core/errors/failure.dart';

ServerFailure handleDioError(
  DioException e, {
  String defaultMessage = 'Terjadi kesalahan pada server',
}) {
  final statusCode = e.response?.statusCode;
  String errorMessage = defaultMessage;

  if (e.response?.data is Map) {
    final data = e.response?.data as Map<String, dynamic>;
    // format error Midtrans
    if (data['error_messages'] != null) {
      errorMessage = (data['error_messages'] as List).join(', ');
    }
    // error API standar umum (misal: { "message": "..." })
    else if (data['message'] != null) {
      errorMessage = data['message'].toString();
    }
  } else if (e.message != null && e.message!.isNotEmpty) {
    errorMessage = e.message!;
  }

  return ServerFailure(message: errorMessage, statusCode: statusCode);
}
