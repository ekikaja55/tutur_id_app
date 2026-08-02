import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tutur_id_app/core/errors/dio_error_handler.dart';
import 'package:tutur_id_app/core/errors/failure.dart';
import 'package:tutur_id_app/core/utils/app_logger.dart';

import '../network/api_client.dart';

class MidtransService {
  final ApiClient _apiClient;
  MidtransService(this._apiClient);

  Future<String> createTransactionToken({
    required String orderId,
    required int grossAmount,
    required String customerName,
    required String customerEmail,
  }) async {
    try {
      AppLogger.net('Mencoba membuat transaksi untuk Order ID: $orderId');
      final isProduction = dotenv.env['MIDTRANS_IS_PRODUCTION'] == 'true';
      final serverKey = isProduction
          ? dotenv.env['MIDTRANS_PRODUCTION_SERVER_KEY']
          : dotenv.env['MIDTRANS_SANDBOX_SERVER_KEY'];

      final baseUrl = isProduction
          ? 'https://app.midtrans.com/snap/v1/transactions'
          : 'https://app.sandbox.midtrans.com/snap/v1/transactions';

      final authString = base64Encode(utf8.encode('$serverKey'));

      final response = await _apiClient.post(
        baseUrl,
        options: Options(headers: {'Authorization': 'Basic $authString'}),
        data: {
          'transaction_details': {
            'order_id': orderId,
            'gross_amount': grossAmount,
          },
          'customer_details': {
            'first_name': customerName,
            'email': customerEmail,
          },
        },
      );

      AppLogger.s(
        'Transaksi berhasil dibuat. Token: ${response.data['token']}',
      );

      return response.data['token'];
    } on DioException catch (e, stackTrace) {
      AppLogger.e(
        'Gagal membuat transaksi Midtrans [Status ${e.response?.statusCode}]',
        error: e.response?.data ?? e.message,
        stackTrace: stackTrace,
      );
      throw handleDioError(e, defaultMessage: "Failed to create transaction");
    } catch (e) {
      throw ServerFailure(message: 'Server Error : $e', statusCode: 500);
    }
  }
}
