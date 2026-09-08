import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import 'constants.dart';

class ApiResponse {
  final int statusCode;
  final String body;
  final dynamic data;
  final bool isSuccess;
  final String? errorMessage;

  ApiResponse({
    required this.statusCode,
    required this.body,
    this.data,
    required this.isSuccess,
    this.errorMessage,
  });
}

class ApiClient {
  static void Function()? onSessionExpired;

  static Future<ApiResponse> get(
    String endpoint, {
    String? token,
    Map<String, String>? queryParams,
    Duration timeout = const Duration(seconds: 10),
    int maxRetries = 1,
  }) async {
    return _sendWithRetry(
      'GET',
      endpoint,
      token: token,
      queryParams: queryParams,
      timeout: timeout,
      maxRetries: maxRetries,
    );
  }

  static Future<ApiResponse> post(
    String endpoint, {
    String? token,
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    return _sendWithRetry(
      'POST',
      endpoint,
      token: token,
      body: body,
      timeout: timeout,
      maxRetries: 0, // Never retry state-changing POST requests
    );
  }

  static Future<ApiResponse> delete(
    String endpoint, {
    String? token,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    return _sendWithRetry(
      'DELETE',
      endpoint,
      token: token,
      timeout: timeout,
      maxRetries: 0,
    );
  }

  static Future<ApiResponse> _sendWithRetry(
    String method,
    String endpoint, {
    String? token,
    Map<String, String>? queryParams,
    Map<String, dynamic>? body,
    required Duration timeout,
    required int maxRetries,
  }) async {
    final baseUrl = ApiConfig.baseUrl;
    var uri = Uri.parse('$baseUrl$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    int attempts = 0;
    while (true) {
      attempts++;
      final stopwatch = Stopwatch()..start();
      try {
        http.Response response;
        if (method == 'GET') {
          response = await http.get(uri, headers: headers).timeout(timeout);
        } else if (method == 'POST') {
          response = await http
              .post(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
              .timeout(timeout);
        } else if (method == 'DELETE') {
          response = await http.delete(uri, headers: headers).timeout(timeout);
        } else {
          throw UnsupportedError('Method $method is not supported');
        }

        stopwatch.stop();
        dev.log(
          '[$method] $uri -> ${response.statusCode} (${stopwatch.elapsedMilliseconds}ms)',
          name: 'ApiClient',
        );

        final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
        dynamic parsedData;
        String? extractedError;

        final bodyText = utf8.decode(response.bodyBytes).trim();
        if (bodyText.isNotEmpty) {
          try {
            parsedData = jsonDecode(bodyText);
            if (parsedData is Map<String, dynamic>) {
              extractedError = parsedData['friendly_message'] ??
                  parsedData['message'] ??
                  parsedData['error'];
            }
          } catch (_) {
            if (!isSuccess && !bodyText.startsWith('<')) {
              extractedError = bodyText;
            }
          }
        }

        if (response.statusCode == 401) {
          onSessionExpired?.call();
        }

        return ApiResponse(
          statusCode: response.statusCode,
          body: bodyText,
          data: parsedData,
          isSuccess: isSuccess,
          errorMessage: extractedError ?? (isSuccess ? null : 'Помилка сервера HTTP ${response.statusCode}'),
        );
      } catch (e) {
        stopwatch.stop();
        dev.log(
          '[$method] $uri failed after ${stopwatch.elapsedMilliseconds}ms: $e',
          name: 'ApiClient',
          error: e,
        );

        if (attempts <= maxRetries && method == 'GET') {
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }

        String userMsg = 'Помилка зʼєднання з сервером';
        if (e is TimeoutException) {
          userMsg = 'Час очікування відповіді сервера вичерпано. Можливо, сервер прокидається (Render cold start).';
        }

        return ApiResponse(
          statusCode: 0,
          body: '',
          data: null,
          isSuccess: false,
          errorMessage: userMsg,
        );
      }
    }
  }
}
