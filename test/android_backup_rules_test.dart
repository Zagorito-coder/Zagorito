import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const domains = <String>[
    'root',
    'file',
    'database',
    'sharedpref',
    'external',
    'device_root',
    'device_file',
    'device_database',
    'device_sharedpref',
  ];

  test('Android désactive explicitement la sauvegarde applicative', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(manifest, contains('android:allowBackup="false"'));
    expect(
      manifest,
      contains('android:fullBackupContent="@xml/backup_rules"'),
    );
    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
  });

  test('Android 11 exclut tous les domaines de sauvegarde', () {
    final rules = File('android/app/src/main/res/xml/backup_rules.xml')
        .readAsStringSync();

    for (final domain in domains) {
      expect(
        rules,
        contains('<exclude domain="$domain" path="." />'),
        reason: 'Domaine Android 11 non exclu : $domain',
      );
    }
  });

  test('Android 12+ exclut cloud et transfert appareil-à-appareil', () {
    final rules = File(
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    ).readAsStringSync();

    expect(rules, contains('<cloud-backup'));
    expect(rules, contains('<device-transfer>'));
    for (final domain in domains) {
      final exclusion = '<exclude domain="$domain" path="." />';
      expect(
        exclusion.allMatches(rules).length,
        2,
        reason: 'Le domaine $domain doit être exclu dans les deux sections',
      );
    }
  });
}
