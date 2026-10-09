import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('presentation widgets do not print raw backend exceptions', () {
    final violations = <String>[];
    final root = Directory('lib');
    expect(root.existsSync(), isTrue);

    final files = root.listSync(recursive: true).whereType<File>().where((
      file,
    ) {
      final path = file.path.replaceAll('\\', '/');
      return path.endsWith('.dart') &&
          (path.contains('/presentation/') || path.contains('/app/router/'));
    });

    final rawException = RegExp(
      r'(?:snapshot\.error|state\.error|\berror)\?*\.toString\(\)',
    );

    for (final file in files) {
      final source = file.readAsStringSync();
      if (rawException.hasMatch(source)) {
        violations.add(file.path);
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'UI must show a friendly Bengali message, never a raw '
          'server/SQL/provider exception. Files: ${violations.join(', ')}',
    );
  });
}
