import 'dart:convert';
import 'dart:io';

import 'package:agile_travelers/services/gemini_recommendation_service.dart';
import 'package:agile_travelers/services/network_unavailable_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('GeminiRecommendationService', () {
    test('requests JSON destination ideas and parses the response', () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'generativelanguage.googleapis.com');
        expect(request.url.path, contains(':generateContent'));
        expect(request.headers['x-goog-api-key'], 'test-key');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(
          body['generationConfig']['responseMimeType'],
          'application/json',
        );
        expect(request.body, contains('quiet lakeside walk'));
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': jsonEncode({
                        'relevant': true,
                        'message': '',
                        'destinations': [
                          {
                            'destination': 'Uppsala',
                            'reason': 'Explore historic streets and parks.',
                          },
                        ],
                      }),
                    },
                  ],
                },
              },
            ],
          }),
          200,
        );
      });
      final service = GeminiRecommendationService(
        apiKey: 'test-key',
        client: client,
      );

      final results = await service.recommendDestinations(
        origin: 'Stockholm',
        preferencePrompt: 'I want a quiet lakeside walk and good coffee.',
      );

      expect(results.isRelevant, isTrue);
      expect(results.destinations, hasLength(1));
      expect(results.destinations.single.destination, 'Uppsala');
      expect(results.destinations.single.reason, contains('historic'));
    });

    test(
      'shows helpful guidance when personalized suggestions are unavailable',
      () async {
        final service = GeminiRecommendationService(
          apiKey: '',
          client: MockClient((_) async => throw StateError('must not request')),
        );

        expect(
          () => service.recommendDestinations(
            origin: 'Stockholm',
            preferencePrompt: 'I like history.',
          ),
          throwsA(
            isA<GeminiRecommendationException>().having(
              (error) => error.message,
              'message',
              contains('search by destination'),
            ),
          ),
        );
      },
    );

    test(
      'shows friendly guidance when personalized suggestions are unavailable',
      () async {
        final service = GeminiRecommendationService(
          apiKey: 'test-key',
          client: MockClient((_) async => http.Response('{}', 403)),
        );

        expect(
          () => service.recommendDestinations(
            origin: 'Stockholm',
            preferencePrompt: 'I like history.',
          ),
          throwsA(
            isA<GeminiRecommendationException>().having(
              (error) => error.message,
              'message',
              contains('search by destination'),
            ),
          ),
        );
      },
    );

    test('returns a helpful validation result for unrelated prompts', () async {
      final service = GeminiRecommendationService(
        apiKey: 'test-key',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {
                        'text': jsonEncode({
                          'relevant': false,
                          'message': "I couldn't make a trip recommendation from that prompt.",
                          'destinations': [],
                        }),
                      },
                    ],
                  },
                },
              ],
            }),
            200,
          ),
        ),
      );

      final result = await service.recommendDestinations(
        origin: 'Stockholm',
        preferencePrompt: 'xyzqwerty unrelated nonsense',
      );

      expect(result.isRelevant, isFalse);
      expect(result.destinations, isEmpty);
      expect(result.message, contains("couldn't make a trip recommendation"));
    });

    test('explains model-not-found without technical details', () async {
      final service = GeminiRecommendationService(
        apiKey: 'test-key',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {'message': 'The configured model was retired.'},
            }),
            404,
          ),
        ),
      );

      expect(
        () => service.recommendDestinations(
          origin: 'Stockholm',
          preferencePrompt: 'I like history.',
        ),
        throwsA(
          isA<GeminiRecommendationException>().having(
            (error) => error.message,
            'message',
            contains('search by destination'),
          ),
        ),
      );
    });

    test(
      'reports a specific offline exception when recommendation is offline',
      () async {
        final service = GeminiRecommendationService(
          apiKey: 'test-key',
          client: MockClient(
            (_) async => throw const SocketException('network unreachable'),
          ),
        );

        await expectLater(
          service.recommendDestinations(
            origin: 'Stockholm',
            preferencePrompt: 'I like history.',
          ),
          throwsA(isA<NetworkUnavailableException>()),
        );
      },
    );

    test('uses a fallback model when the primary model is busy', () async {
      var requestCount = 0;
      final service = GeminiRecommendationService(
        apiKey: 'test-key',
        client: MockClient((request) async {
          requestCount++;
          if (requestCount == 1) {
            expect(request.url.path, contains('gemini-3.6-flash'));
            return http.Response('{}', 503);
          }
          expect(request.url.path, contains('gemini-flash-latest'));
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {
                        'text': jsonEncode({
                          'relevant': true,
                          'message': '',
                          'destinations': [
                            {
                              'destination': 'Uppsala',
                              'reason': 'Parks and a historic centre.',
                            },
                          ],
                        }),
                      },
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }),
      );

      final result = await service.recommendDestinations(
        origin: 'Stockholm',
        preferencePrompt: 'I like nature.',
      );

      expect(requestCount, 2);
      expect(result.destinations.single.destination, 'Uppsala');
    });

    test('shows busy message when all Gemini models are overloaded', () async {
      var requestCount = 0;
      final service = GeminiRecommendationService(
        apiKey: 'test-key',
        client: MockClient((_) async {
          requestCount++;
          return http.Response('{}', 503);
        }),
      );

      await expectLater(
        service.recommendDestinations(
          origin: 'Stockholm',
          preferencePrompt: 'I like nature.',
        ),
        throwsA(
          isA<GeminiRecommendationException>().having(
            (error) => error.message,
            'message',
            contains('temporarily busy'),
          ),
        ),
      );
      expect(requestCount, 2);
    });

    test('falls back if the primary model returns not found', () async {
      var requestCount = 0;
      final service = GeminiRecommendationService(
        apiKey: 'test-key',
        client: MockClient((request) async {
          requestCount++;
          if (requestCount == 1) return http.Response('{}', 404);
          expect(request.url.path, contains('gemini-flash-latest'));
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {
                        'text': jsonEncode({
                          'relevant': false,
                          'message': 'Try a travel-related prompt.',
                          'destinations': [],
                        }),
                      },
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }),
      );

      final result = await service.recommendDestinations(
        origin: 'Stockholm',
        preferencePrompt: 'nonsense',
      );

      expect(requestCount, 2);
      expect(result.isRelevant, isFalse);
    });
  });
}
