import 'dart:async';
import 'package:dio/dio.dart';
import 'constants.dart';
import 'secure_storage.dart';

/// A normalized error the UI layer can rely on, mirroring the backend's
/// ErrorResponse shape (timestamp, status, error, message, path, fieldErrors).
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final Map<String, String>? fieldErrors;

  ApiException({required this.message, this.statusCode, this.fieldErrors});

  /// The first field-level validation message, if any — handy for forms.
  String? get firstFieldError =>
      (fieldErrors != null && fieldErrors!.isNotEmpty) ? fieldErrors!.values.first : null;

  @override
  String toString() => message;
}

/// Called by ApiClient right after tokens are refreshed, or when the
/// refresh itself fails and the session must be dropped. Wired up to
/// AuthProvider from main.dart so the whole app reacts to logout.
typedef SessionExpiredCallback = void Function();

class ApiClient {
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(milliseconds: AppConfig.connectTimeoutMs),
        receiveTimeout: const Duration(milliseconds: AppConfig.receiveTimeoutMs),
        contentType: 'application/json',
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final isAuthEndpoint = options.path.contains('/auth/');
          final skipAuth = options.extra['skipAuth'] == true || isAuthEndpoint;

          if (skipAuth) {
            options.headers.remove('Authorization');
          } else {
            final token = await SecureStorage.instance.getAccessToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          // validateStatus lets 4xx through as a normal response, so we
          // convert those into DioExceptions here, uniformly.
          if (response.statusCode != null && response.statusCode! >= 400) {
            handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                response: response,
                type: DioExceptionType.badResponse,
              ),
              true,
            );
            return;
          }
          handler.next(response);
        },
        onError: (DioException error, handler) async {
          final requestOptions = error.requestOptions;
          final status = error.response?.statusCode;

          final isConnErr = error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.connectionError ||
              error.type == DioExceptionType.sendTimeout ||
              error.type == DioExceptionType.receiveTimeout;

          final isAuthEndpoint = requestOptions.path.contains('/auth/');
          final isSafeToRetry = requestOptions.method.toUpperCase() == 'GET' || isAuthEndpoint;

          if (isConnErr && isSafeToRetry && requestOptions.extra['hostRetried'] != true) {
            requestOptions.extra['hostRetried'] = true;
            final workingHost = await _discoverWorkingBaseUrl();
            if (workingHost != null) {
              AppConfig.customBaseUrl = workingHost;
              _dio.options.baseUrl = workingHost;
              requestOptions.baseUrl = workingHost;
              try {
                final cloned = await _dio.fetch(requestOptions);
                handler.resolve(cloned);
                return;
              } catch (_) {
                // fall through
              }
            }
          } else if (isConnErr && requestOptions.extra['hostRetried'] != true) {
            requestOptions.extra['hostRetried'] = true;
            final workingHost = await _discoverWorkingBaseUrl();
            if (workingHost != null) {
              AppConfig.customBaseUrl = workingHost;
              _dio.options.baseUrl = workingHost;
            }
          }

          if (status == 401 && !isAuthEndpoint && requestOptions.extra['retried'] != true) {
            final refreshed = await _refreshTokens();
            if (refreshed) {
              requestOptions.extra['retried'] = true;
              final token = await SecureStorage.instance.getAccessToken();
              requestOptions.headers['Authorization'] = 'Bearer $token';
              try {
                final cloned = await _dio.fetch(requestOptions);
                handler.resolve(cloned);
                return;
              } catch (_) {
                // fall through to normal error handling
              }
            } else {
              onSessionExpired?.call();
            }
          }

          handler.next(error);
        },
      ),
    );
  }

  Future<String?> _discoverWorkingBaseUrl() async {
    for (final host in AppConfig.candidateBaseUrls) {
      try {
        final testDio = Dio(
          BaseOptions(
            connectTimeout: const Duration(milliseconds: 2500),
            receiveTimeout: const Duration(milliseconds: 2500),
          ),
        );
        final res = await testDio.get('$host/categories');
        if (res.statusCode != null && res.statusCode! < 500) {
          return host;
        }
      } catch (_) {}
    }
    return null;
  }

  static final ApiClient instance = ApiClient._internal();
  late final Dio _dio;

  SessionExpiredCallback? onSessionExpired;

  Completer<bool>? _refreshCompleter;

  Future<bool> _refreshTokens() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }
    _refreshCompleter = Completer<bool>();

    try {
      final refreshToken = await SecureStorage.instance.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        _refreshCompleter!.complete(false);
        return false;
      }

      final response = await _dio.post(
        '/auth/refresh-token',
        data: {'refreshToken': refreshToken},
        options: Options(extra: {'skipAuth': true}),
      );

      if (response.statusCode == 200 && response.data != null) {
        final newAccess = response.data['accessToken'] as String?;
        final newRefresh = response.data['refreshToken'] as String?;
        if (newAccess != null && newRefresh != null) {
          await SecureStorage.instance.updateTokens(
            accessToken: newAccess,
            refreshToken: newRefresh,
          );
          _refreshCompleter!.complete(true);
          return true;
        }
      }
      _refreshCompleter!.complete(false);
      return false;
    } catch (_) {
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  Dio get dio => _dio;

  /// Converts any thrown error into an [ApiException] with a clean message.
  ApiException mapError(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      if (error.error is ApiException) {
        return error.error as ApiException;
      }
      final data = error.response?.data;
      final status = error.response?.statusCode;

      if (data is Map<String, dynamic>) {
        Map<String, String>? fieldErrors;
        if (data['fieldErrors'] is Map) {
          fieldErrors = (data['fieldErrors'] as Map).map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          );
        }
        final message = data['message']?.toString() ??
            data['error']?.toString() ??
            _fallbackMessage(error);
        return ApiException(message: message, statusCode: status, fieldErrors: fieldErrors);
      } else if (data is String && data.trim().isNotEmpty) {
        return ApiException(message: data.trim(), statusCode: status);
      }

      return ApiException(message: _fallbackMessage(error), statusCode: status);
    }
    return ApiException(message: error.toString());
  }

  String _fallbackMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The server is taking too long to respond. Please try again.';
      case DioExceptionType.connectionError:
        return 'Could not reach the server. Check your connection and the API base URL.';
      default:
        return error.message ?? 'Something went wrong. Please try again.';
    }
  }
}
