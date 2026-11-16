import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tasknest_app/services/api_client.dart';
import 'package:tasknest_app/services/session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<bool> restoreWith(http.Response Function(http.Request) handler) {
    return http.runWithClient(
      () => Session().tryRestore(),
      () => MockClient((r) async => handler(r)),
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({'tasknest_token': 'abc'});
    ApiClient.resetCacheForTests();
  });

  test('restores session from /me response shaped {"user": {...}}', () async {
    final ok = await restoreWith(
      (_) => http.Response(
        jsonEncode({
          'user': {
            'id': 1,
            'name': 'Daniel Director',
            'email': 'd@x.test',
            'role': 'director',
          },
        }),
        200,
      ),
    );
    expect(ok, isTrue);
  });

  test('401 clears the stored token', () async {
    final ok = await restoreWith((_) => http.Response('{"message":"x"}', 401));
    expect(ok, isFalse);
    expect(await ApiClient.getToken(), isNull);
  });

  test('server error keeps the token', () async {
    final ok = await restoreWith((_) => http.Response('oops', 500));
    expect(ok, isFalse);
    expect(await ApiClient.getToken(), 'abc');
  });
}
