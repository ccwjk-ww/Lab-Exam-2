import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DioClient {
  static Dio createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: dotenv.env['GEMINI_BASE_URL'] ?? '',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.addAll([
      _ApiKeyInterceptor(),
      _LoggingInterceptor(),
      _ErrorInterceptor(),
    ]);

    return dio;
  }
}

/// Interceptor: Attach API Key to every request
class _ApiKeyInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    options.queryParameters['key'] = apiKey;
    handler.next(options);
  }
}

/// Interceptor: Log requests and responses (debug only)
class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('>>> [REQUEST] ${options.method} ${options.uri}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('<<< [RESPONSE] ${response.statusCode} ${response.realUri}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('!!! [ERROR] ${err.type}: ${err.message}');
    }
    handler.next(err);
  }
}

/// Interceptor: Transform DioException to readable error
class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    String message;
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = 'Connection timeout. Please check your internet.';
        break;
      case DioExceptionType.badResponse:
        message = 'Server error: ${err.response?.statusCode}';
        break;
      case DioExceptionType.connectionError:
        message = 'No internet connection.';
        break;
      default:
        message = 'An unexpected error occurred.';
    }
    handler.next(DioException(
      requestOptions: err.requestOptions,
      error: message,
      type: err.type,
      response: err.response,
    ));
  }
}
