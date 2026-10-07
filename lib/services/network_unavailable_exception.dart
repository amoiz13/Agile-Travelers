import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

class NetworkUnavailableException implements Exception {
  const NetworkUnavailableException();

  static const message =
      'No internet connection. Check your Wi-Fi or mobile data and try again.';

  @override
  String toString() => message;
}

bool isNetworkUnavailable(Object error) =>
    error is SocketException ||
    error is HandshakeException ||
    error is http.ClientException ||
    error is TimeoutException;
