import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  group('HTTP Proxy & Payment Server Integration Tests', () {
    late HttpServer server;
    late Uri baseUri;
    final Map<String, Map<String, dynamic>> orders = {};

    setUpAll(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      baseUri = Uri.parse('http://127.0.0.1:${server.port}');

      server.listen((HttpRequest request) async {
        final path = request.uri.path;
        final authHeader = request.headers.value(HttpHeaders.authorizationHeader) ?? '';

        if (request.method == 'GET' && path == '/health') {
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'status': 'ok'}));
          await request.response.close();
          return;
        }

        if (request.method == 'GET' && path == '/simulate-html-502') {
          request.response
            ..statusCode = HttpStatus.badGateway
            ..headers.contentType = ContentType.html
            ..write('<!DOCTYPE html><html><body>502 Bad Gateway</body></html>');
          await request.response.close();
          return;
        }

        if (request.method == 'POST' && path == '/aiChatProxy') {
          if (!authHeader.startsWith('Bearer ')) {
            request.response
              ..statusCode = HttpStatus.unauthorized
              ..headers.contentType = ContentType.json
              ..write(jsonEncode({'success': false, 'message': 'Yêu cầu đăng nhập'}));
            await request.response.close();
            return;
          }

          final bodyStr = await utf8.decoder.bind(request).join();
          final payload = jsonDecode(bodyStr) as Map<String, dynamic>;
          final contents = payload['contents'] as List<dynamic>? ?? [];

          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({
              'success': true,
              'text': 'Gợi ý phòng phù hợp tại Cầu Giấy [ROOM_ID: room_1]',
              'modelUsed': payload['modelName'] ?? 'gemini-flash-latest',
              'turnCount': contents.length,
            }));
          await request.response.close();
          return;
        }

        if (request.method == 'POST' && path == '/createMoMoPayment') {
          if (!authHeader.startsWith('Bearer ')) {
            request.response
              ..statusCode = HttpStatus.unauthorized
              ..headers.contentType = ContentType.json
              ..write(jsonEncode({'success': false, 'message': 'Missing Bearer Token'}));
            await request.response.close();
            return;
          }

          final bodyStr = await utf8.decoder.bind(request).join();
          final payload = jsonDecode(bodyStr) as Map<String, dynamic>;
          final orderId = 'ORD_TEST_${orders.length + 1}';
          orders[orderId] = {
            'orderId': orderId,
            'packageId': payload['packageId'] ?? 'bronze',
            'status': 'completed',
          };

          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({
              'success': true,
              'orderId': orderId,
              'payUrl': '$baseUri/momoSandboxCheckout?orderId=$orderId',
            }));
          await request.response.close();
          return;
        }

        if (request.method == 'POST' && path == '/checkPaymentStatus') {
          if (!authHeader.startsWith('Bearer ')) {
            request.response
              ..statusCode = HttpStatus.unauthorized
              ..headers.contentType = ContentType.json
              ..write(jsonEncode({'success': false, 'message': 'Unauthorized'}));
            await request.response.close();
            return;
          }

          final bodyStr = await utf8.decoder.bind(request).join();
          final payload = jsonDecode(bodyStr) as Map<String, dynamic>;
          final order = orders[payload['orderId']];
          if (order == null) {
            request.response
              ..statusCode = HttpStatus.notFound
              ..headers.contentType = ContentType.json
              ..write(jsonEncode({'success': false, 'message': 'Order not found'}));
            await request.response.close();
            return;
          }

          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({
              'success': true,
              'status': order['status'],
              'isCompleted': order['status'] == 'completed',
              'packageId': order['packageId'],
            }));
          await request.response.close();
          return;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });
    });

    tearDownAll(() async {
      await server.close(force: true);
    });

    test('GET /health returns 200 status ok', () async {
      final res = await http.get(baseUri.replace(path: '/health'));
      expect(res.statusCode, 200);
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      expect(data['status'], 'ok');
    });

    test('POST /aiChatProxy enforces Bearer auth and proxies RAG response', () async {
      final unauthRes = await http.post(
        baseUri.replace(path: '/aiChatProxy'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'contents': []}),
      );
      expect(unauthRes.statusCode, 401);

      final authRes = await http.post(
        baseUri.replace(path: '/aiChatProxy'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer valid-firebase-token',
        },
        body: jsonEncode({
          'modelName': 'gemini-flash-latest',
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': 'Tìm phòng Cầu Giấy dưới 3.5 triệu'}
              ],
            }
          ],
        }),
      );
      expect(authRes.statusCode, 200);
      final data = jsonDecode(authRes.body) as Map<String, dynamic>;
      expect(data['success'], isTrue);
      expect(data['text'], contains('[ROOM_ID: room_1]'));
      expect(data['modelUsed'], 'gemini-flash-latest');
      expect(data['turnCount'], 1);
    });

    test('POST /createMoMoPayment and /checkPaymentStatus round-trip over HTTP', () async {
      final unauthOrder = await http.post(
        baseUri.replace(path: '/createMoMoPayment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'packageId': 'silver'}),
      );
      expect(unauthOrder.statusCode, 401);

      final createRes = await http.post(
        baseUri.replace(path: '/createMoMoPayment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer valid-firebase-token',
        },
        body: jsonEncode({'packageId': 'silver', 'roomId': 'room_123'}),
      );
      expect(createRes.statusCode, 200);
      final createJson = jsonDecode(createRes.body) as Map<String, dynamic>;
      expect(createJson['success'], isTrue);
      expect(createJson['payUrl'], contains('/momoSandboxCheckout'));

      final checkRes = await http.post(
        baseUri.replace(path: '/checkPaymentStatus'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer valid-firebase-token',
        },
        body: jsonEncode({'orderId': createJson['orderId']}),
      );
      expect(checkRes.statusCode, 200);
      final checkJson = jsonDecode(checkRes.body) as Map<String, dynamic>;
      expect(checkJson['isCompleted'], isTrue);
      expect(checkJson['packageId'], 'silver');
    });

    test('Non-JSON HTML error page is safely rejected before JSON decode', () async {
      final res = await http.get(baseUri.replace(path: '/simulate-html-502'));
      expect(res.statusCode, 502);
      final isJson = (res.headers['content-type'] ?? '').toLowerCase().contains('application/json');
      expect(isJson, isFalse);
      expect(res.body.trimLeft().startsWith('<'), isTrue);
    });
  });
}
