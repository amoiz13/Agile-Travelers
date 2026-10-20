import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'network_unavailable_exception.dart';

// Supplied at build time: flutter run --dart-define=GATEWAY_URL=https://...
const gatewayUrl = String.fromEnvironment('GATEWAY_URL');

class GatewayException implements Exception {
  const GatewayException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

// The only place in the app that talks over the network. Every response uses
// the gateway envelope: { data, error: { code, message } | null, cached }.
class GatewayClient {
  GatewayClient({
    required this.baseUrl,
    required this.client,
    this.timeout = const Duration(seconds: 45),
  });

  final String baseUrl;
  final http.Client client;
  final Duration timeout;

  static const _unavailableMessage =
      'This feature isn’t available right now. Please try again later.';
  static const _genericMessage =
      'Something went wrong. Please try again shortly.';

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String> query = const {},
  }) => _send((uri) => client.get(uri), path, query: query);

  Future<Map<String, dynamic>> post(
    String path, {
    required Map<String, dynamic> body,
  }) => _send(
    (uri) => client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ),
    path,
  );

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function(Uri uri) request,
    String path, {
    Map<String, String> query = const {},
  }) async {
    final uri = _uri(path, query);
    final http.Response response;
    try {
      response = await request(uri).timeout(timeout);
    } on Exception catch (error) {
      if (isNetworkUnavailable(error)) {
        throw const NetworkUnavailableException();
      }
      throw const GatewayException('unavailable', _genericMessage);
    }

    final envelope = _decode(response.body);
    final error = envelope?['error'];
    if (error is Map) {
      final code = error['code']?.toString() ?? 'unavailable';
      if (code == 'offline') throw const NetworkUnavailableException();
      final message = error['message'];
      throw GatewayException(
        code,
        message is String && message.trim().isNotEmpty
            ? message
            : _statusMessage(response.statusCode),
      );
    }
    final data = envelope?['data'];
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data is! Map) {
      throw GatewayException(
        'unavailable',
        _statusMessage(response.statusCode),
      );
    }
    return Map<String, dynamic>.from(data);
  }

  Uri _uri(String path, Map<String, String> query) {
    final base = Uri.tryParse(baseUrl.trim());
    if (base == null || !base.hasScheme || base.host.isEmpty) {
      throw const GatewayException('unavailable', _unavailableMessage);
    }
    final basePath = base.path.replaceAll(RegExp(r'/+$'), '');
    return base.replace(
      path: '$basePath$path',
      queryParameters: query.isEmpty ? null : query,
    );
  }

  Map<String, dynamic>? _decode(String body) {
    try {
      final value = jsonDecode(body);
      return value is Map ? Map<String, dynamic>.from(value) : null;
    } on FormatException {
      return null;
    }
  }

  String _statusMessage(int status) => status == 429
      ? 'Too many requests. Please wait a moment and try again.'
      : status >= 500
      ? 'Search is temporarily unavailable. Please try again shortly.'
      : _genericMessage;
}
