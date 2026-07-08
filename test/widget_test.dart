import 'package:flutter_test/flutter_test.dart';

import 'package:neurax/src/models/session_user.dart';

void main() {
  test('session user parses Google profile', () {
    final user = SessionUser.fromJson({
      'id': 'google-id',
      'name': 'Seandy Adryan',
      'email': 'seandy@example.com',
      'photoUrl': null,
    });

    expect(user.name, 'Seandy Adryan');
    expect(user.photoUrl, isNull);
  });
}
