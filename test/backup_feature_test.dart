import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos/features/backup/backup_scheduler.dart';
import 'package:pos/features/backup/data/backup_service.dart';
import 'package:pos/features/backup/data/datasource/backup_settings_datasource.dart';
import 'package:pos/features/backup/data/model/backup_settings_model.dart';
import 'package:pos/features/backup/data/repository/backup_repository.dart';
import 'package:pos/features/backup/presentation/provider/backup_provider.dart';
import 'package:pos/features/backup/presentation/screen/backup_screen.dart';

class _FakeSettingsDataSource extends BackupSettingsDataSource {
  _FakeSettingsDataSource([BackupSettingsModel? initial])
      : stored = initial ?? const BackupSettingsModel();

  BackupSettingsModel stored;

  @override
  Future<void> ensureSchema() async {}

  @override
  Future<BackupSettingsModel> fetch() async => stored;

  @override
  Future<BackupSettingsModel> saveConfig(BackupSettingsModel s) async {
    stored = stored.copyWith(
      enabled: s.enabled,
      supabaseUrl: s.supabaseUrl,
      supabaseKey: s.supabaseKey,
    );
    return stored;
  }

  @override
  Future<BackupSettingsModel> markRun({
    required bool ok,
    required String status,
    DateTime? at,
  }) async {
    stored = stored.copyWith(
      lastBackupAt: at ?? DateTime.now(),
      lastStatus: status,
      lastBackupOk: ok,
    );
    return stored;
  }
}

class _FakeService extends BackupService {
  _FakeService({this.throwing = false})
      : super(supabaseUrl: 'https://x.supabase.co', supabaseKey: 'k');

  final bool throwing;

  @override
  Future<BackupOutcome> backup() async {
    if (throwing) throw BackupException('Supabase rejected the key.');
    return const BackupOutcome(tables: 25, rows: 812);
  }

  @override
  Future<BackupOutcome> restore() async =>
      const BackupOutcome(tables: 20, rows: 400);
}

class _FakeRepository extends BackupRepository {
  _FakeRepository(super.dataSource, {this.service});

  final BackupService? service;

  @override
  BackupService serviceFor(BackupSettingsModel s) =>
      service ?? _FakeService();
}

void main() {
  tearDown(BackupScheduler.instance.stop);

  group('BackupSettingsModel', () {
    test('isConfigured needs both url and key', () {
      expect(const BackupSettingsModel().isConfigured, isFalse);
      expect(
        const BackupSettingsModel(supabaseUrl: 'https://x.supabase.co')
            .isConfigured,
        isFalse,
      );
      expect(
        const BackupSettingsModel(
          supabaseUrl: 'https://x.supabase.co',
          supabaseKey: 'k',
        ).isConfigured,
        isTrue,
      );
    });

    test('isDueNow: enabled + configured + stale (or never)', () {
      const base = BackupSettingsModel(
        enabled: true,
        supabaseUrl: 'https://x.supabase.co',
        supabaseKey: 'k',
      );
      expect(base.isDueNow, isTrue); // never backed up
      expect(
        base.copyWith(lastBackupAt: DateTime.now()).isDueNow,
        isFalse,
      );
      expect(
        base
            .copyWith(
                lastBackupAt:
                    DateTime.now().subtract(const Duration(hours: 7)))
            .isDueNow,
        isTrue,
      );
      expect(base.copyWith(enabled: false).isDueNow, isFalse);
    });
  });

  test('provider saves config and records a manual backup', () async {
    final ds = _FakeSettingsDataSource();
    final p = BackupProvider(_FakeRepository(ds));
    await p.load();

    final ok = await p.saveConfig(const BackupSettingsModel(
      enabled: true,
      supabaseUrl: 'https://demo.supabase.co',
      supabaseKey: 'service-key',
    ));
    expect(ok, isTrue);
    expect(ds.stored.enabled, isTrue);
    expect(p.settings.isConfigured, isTrue);

    await p.backupNow();
    expect(p.error, isNull);
    expect(p.settings.lastBackupOk, isTrue);
    expect(p.settings.lastStatus, contains('812'));
  });

  test('provider surfaces a backup failure and marks it', () async {
    final ds = _FakeSettingsDataSource(const BackupSettingsModel(
      enabled: true,
      supabaseUrl: 'https://demo.supabase.co',
      supabaseKey: 'bad',
    ));
    final p = BackupProvider(
      _FakeRepository(ds, service: _FakeService(throwing: true)),
    );
    await p.load();
    await p.backupNow();

    expect(p.error, contains('rejected'));
    expect(p.settings.lastBackupOk, isFalse);
  });

  testWidgets('screen shows the connection form; backup disabled until set up',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final p = BackupProvider(_FakeRepository(_FakeSettingsDataSource()));
    await tester.pumpWidget(MaterialApp(home: BackupScreen(provider: p)));
    await tester.pumpAndSettle();

    expect(find.text('Supabase connection'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Project URL'), findsOneWidget);
    expect(find.text('Back up now'), findsOneWidget);

    final backupBtn = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Back up now'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    expect(backupBtn.onPressed, isNull); // not configured yet
  });
}
