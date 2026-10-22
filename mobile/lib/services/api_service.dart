import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';

final _log = Logger('ApiService');

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.details});

  final String message;
  final int? statusCode;
  final Object? details;

  bool get isUnauthorized => statusCode == 401;
  bool get isNetworkError => statusCode == null;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({
    Dio? dio,
    Future<String?> Function()? tokenProvider,
    this.authScheme = 'Token',
    Duration timeout = const Duration(seconds: 15),
  }) : _tokenProvider = tokenProvider,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: _readBaseUrl(),
               connectTimeout: timeout,
               sendTimeout: timeout,
               receiveTimeout: timeout,
               contentType: Headers.jsonContentType,
               headers: {'Accept': 'application/json'},
             ),
           ) {
    _dio.interceptors.addAll([
      _LoggingInterceptor(),
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (!options.headers.containsKey('Authorization') &&
              _tokenProvider != null) {
            final token = await _tokenProvider();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = '$authScheme $token';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) {
          final hadToken = error.requestOptions.headers.containsKey(
            'Authorization',
          );
          if (error.response?.statusCode == 401 && hadToken) {
            _log.warning('Server rejected the session token (401)');
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    ]);
  }

  final Dio _dio;
  final Future<String?> Function()? _tokenProvider;
  final String authScheme;

  void Function()? onUnauthorized;

  static String _readBaseUrl() {
    final value = dotenv.env['BASE_URL'];
    if (value == null || value.isEmpty) {
      throw StateError('BASE_URL is missing from .env');
    }
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    String? token,
    CancelToken? cancelToken,
  }) => _request(
    'GET',
    path,
    query: query,
    token: token,
    cancelToken: cancelToken,
  );

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    String? token,
    CancelToken? cancelToken,
  }) => _request(
    'POST',
    path,
    body: body,
    token: token,
    cancelToken: cancelToken,
  );

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    String? token,
    CancelToken? cancelToken,
  }) =>
      _request('PUT', path, body: body, token: token, cancelToken: cancelToken);

  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    String? token,
    CancelToken? cancelToken,
  }) => _request(
    'PATCH',
    path,
    body: body,
    token: token,
    cancelToken: cancelToken,
  );

  Future<dynamic> delete(
    String path, {
    Map<String, dynamic>? body,
    String? token,
    CancelToken? cancelToken,
  }) => _request(
    'DELETE',
    path,
    body: body,
    token: token,
    cancelToken: cancelToken,
  );

  void dispose() => _dio.close();

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    String? token,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path.startsWith('/') ? path : '/$path',
        data: body,
        queryParameters: query == null
            ? null
            : {
                for (final e in query.entries)
                  if (e.value != null) e.key: e.value,
              },
        cancelToken: cancelToken,
        options: Options(
          method: method,
          headers: {
            if (token != null && token.isNotEmpty)
              'Authorization': '$authScheme $token',
          },
        ),
      );
      final data = response.data;
      return (data is String && data.isEmpty) ? null : data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  ApiException _mapError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException('Request timed out. Please try again.');
      case DioExceptionType.connectionError:
        return const ApiException('No internet connection.');
      case DioExceptionType.cancel:
        return const ApiException('Request was cancelled.');
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        final data = e.response?.data;
        return ApiException(
          _extractMessage(data) ?? 'Request failed ($status)',
          statusCode: status,
          details: data,
        );
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        _log.severe('Unexpected network failure', e.error, e.stackTrace);
        return const ApiException('Something went wrong. Please try again.');
    }
  }

  String? _extractMessage(dynamic data) {
    if (data is String && data.isNotEmpty && !data.trimLeft().startsWith('<')) {
      return data;
    }
    if (data is! Map) return null;

    for (final key in const ['detail', 'error', 'message']) {
      final v = data[key];
      if (v is String && v.isNotEmpty) return v;
    }

    for (final entry in data.entries) {
      final v = entry.value;
      final text = v is List && v.isNotEmpty
          ? v.first.toString()
          : (v is String ? v : null);
      if (text == null) continue;
      return entry.key == 'non_field_errors' ? text : '${entry.key}: $text';
    }
    return null;
  }
}

class _LoggingInterceptor extends Interceptor {
  static final _httpLog = Logger('Http');
  static const _startedAtKey = 'startedAtMs';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startedAtKey] = DateTime.now().millisecondsSinceEpoch;
    _httpLog.fine('--> ${options.method} ${options.uri.path}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final options = response.requestOptions;
    _httpLog.info(
      '<-- ${response.statusCode} ${options.method} ${options.uri.path} '
      '(${_elapsedMs(options)}ms)',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final options = err.requestOptions;
    final outcome = err.response?.statusCode ?? err.type.name;
    _httpLog.warning(
      '<-- $outcome ${options.method} ${options.uri.path} '
      '(${_elapsedMs(options)}ms)',
    );
    handler.next(err);
  }

  int _elapsedMs(RequestOptions options) {
    final startedAt = options.extra[_startedAtKey] as int?;
    return startedAt == null
        ? 0
        : DateTime.now().millisecondsSinceEpoch - startedAt;
  }
}
