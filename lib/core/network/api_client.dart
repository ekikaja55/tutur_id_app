import 'package:dio/dio.dart';

class ApiClient {
  late final Dio dio;
  ApiClient({String? baseUrl}) {
    dio = Dio(
    BaseOptions(
        baseUrl: baseUrl ?? '',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    dio.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true, error: true),
    );
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return dio.get(path, queryParameters: queryParameters, options: options);
  }


  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return dio.post(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response> put(
    String path, {
    dynamic data,
    Options? options,
  }) {
    return dio.put(path, data: data, options: options);
  }

  Future<Response> delete(
    String path, {
    dynamic data,
    Options? options,
  }) {
    return dio.delete(path, data: data, options: options);
  }
}
