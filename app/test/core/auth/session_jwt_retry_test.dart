import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/auth/supabase_auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('retries one rejected JWT lookup after refreshing session', () async {
    var attempts = 0;
    var refreshes = 0;

    final role = await retryRoleLookupOnJwtFailure<String>(
      load: () async {
        attempts++;
        if (attempts == 1) {
          throw PostgrestException(message: 'Invalid JWT', code: 'PGRST301');
        }
        return 'patient';
      },
      refresh: () async {
        refreshes++;
      },
    );

    expect(role, 'patient');
    expect(attempts, 2);
    expect(refreshes, 1);
  });

  test('does not refresh a non-JWT RLS or database failure', () async {
    var refreshes = 0;
    await expectLater(
      retryRoleLookupOnJwtFailure<void>(
        load: () async {
          throw PostgrestException(message: 'Permission denied', code: '42501');
        },
        refresh: () async {
          refreshes++;
        },
      ),
      throwsA(isA<PostgrestException>()),
    );
    expect(refreshes, 0);
  });

  test('does not refresh again on token-refreshed auth event', () async {
    var attempts = 0;
    var refreshes = 0;
    await expectLater(
      retryRoleLookupOnJwtFailure<void>(
        allowRefresh: false,
        load: () async {
          attempts++;
          throw PostgrestException(message: 'JWT expired', code: 'PGRST303');
        },
        refresh: () async {
          refreshes++;
        },
      ),
      throwsA(isA<PostgrestException>()),
    );
    expect(attempts, 1);
    expect(refreshes, 0);
  });

  test('never retries indefinitely when the new JWT also fails', () async {
    var attempts = 0;
    var refreshes = 0;
    await expectLater(
      retryRoleLookupOnJwtFailure<void>(
        load: () async {
          attempts++;
          throw PostgrestException(message: 'Invalid JWT', code: 'PGRST301');
        },
        refresh: () async {
          refreshes++;
        },
      ),
      throwsA(isA<PostgrestException>()),
    );
    expect(attempts, 2);
    expect(refreshes, 1);
  });
}
