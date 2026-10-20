import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agile_travelers/services/gateway_client.dart';
import 'package:agile_travelers/services/network_unavailable_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response envelope({
  Object? data,
  Map<String, String>? error,
  int status = 200,
}) => http.Response.bytes(
  utf8.encode(jsonEncode({'data': data, 'error': error, 'cached': false})),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

GatewayClient clientFor(
  Future<http.Response> Function(http.Request) handler, {
  String baseUrl = 'https://gateway.test',
  Duration timeout = const Duration(seconds: 5),
}) => GatewayClient(
  baseUrl: baseUrl,
  client: MockClient(handler),
  timeout: timeout,
);

void main() {
  group('GatewayClient', () {
    test('GET unwraps data and sends query parameters', () async {
      final client = clientFor((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/routes');
        expect(request.url.queryParameters, {'type': 'stops', 'query': 'Upp'});
        return envelope(data: {'stops': []});
      });
      final data = await client.get(
        '/routes',
        query: {'type': 'stops', 'query': 'Upp'},
      );
      expect(data, {'stops': []});
    });

    test('POST sends a JSON body to the configured base URL', () async {
      final client = clientFor(
        (request) async {
          expect(request.method, 'POST');
          expect(request.url.toString(), 'https://gateway.test/api/suggestions');
          expect(request.headers['Content-Type'], contains('application/json'));
          expect(jsonDecode(request.body), {'a': 1});
          return envelope(data: {'ok': true});
        },
        baseUrl: 'https://gateway.test/api/',
      );
      expect(await client.post('/suggestions', body: {'a': 1}), {'ok': true});
    });

    test('never sends credentials of its own', () async {
      final client = clientFor((request) async {
        expect(request.url.queryParameters.keys, isNot(contains('accessId')));
        expect(request.headers.keys, isNot(contains('x-goog-api-key')));
        return envelope(data: {});
      });
      await client.get('/routes');
    });

    test('reports an unconfigured gateway URL as a friendly error', () async {
      final client = clientFor((_) async => envelope(data: {}), baseUrl: '');
      expect(
        () => client.get('/routes'),
        throwsA(
          isA<GatewayException>().having(
            (e) => e.message,
            'message',
            isNot(contains('GATEWAY')),
          ),
        ),
      );
    });

    test('maps a socket failure to the offline exception', () async {
      final client = clientFor((_) async => throw const SocketException('x'));
      expect(
        () => client.get('/routes'),
        throwsA(isA<NetworkUnavailableException>()),
      );
    });

    test('maps a client-side timeout to the offline exception', () async {
      final client = clientFor(
        (_) => Completer<http.Response>().future,
        timeout: const Duration(milliseconds: 20),
      );
      expect(
        () => client.get('/routes'),
        throwsA(isA<NetworkUnavailableException>()),
      );
    });

    test('maps the offline error code to the offline exception', () async {
      final client = clientFor(
        (_) async => envelope(
          error: {'code': 'offline', 'message': 'ignored'},
          status: 503,
        ),
      );
      expect(
        () => client.get('/routes'),
        throwsA(isA<NetworkUnavailableException>()),
      );
    });

    test('surfaces gateway error codes and friendly messages', () async {
      for (final code in ['unavailable', 'invalid_input', 'rate_limited']) {
        final client = clientFor(
          (_) async => envelope(
            error: {'code': code, 'message': 'Friendly $code message.'},
            status: 503,
          ),
        );
        await expectLater(
          client.get('/routes'),
          throwsA(
            isA<GatewayException>()
                .having((e) => e.code, 'code', code)
                .having((e) => e.message, 'message', 'Friendly $code message.'),
          ),
        );
      }
    });

    test('handles 5xx responses with no usable body', () async {
      final client = clientFor(
        (_) async => http.Response('<html>Bad Gateway 502</html>', 502),
      );
      await expectLater(
        client.get('/routes'),
        throwsA(
          isA<GatewayException>().having(
            (e) => e.message,
            'message',
            allOf(contains('temporarily unavailable'), isNot(contains('502'))),
          ),
        ),
      );
    });

    test('handles a 2xx response without data', () async {
      final client = clientFor((_) async => http.Response('[]', 200));
      expect(() => client.get('/routes'), throwsA(isA<GatewayException>()));
    });
  });
}
