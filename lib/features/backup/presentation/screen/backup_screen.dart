import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pos/shared/app_icon.dart';

import '../../../../config/format.dart';
import '../../../../shared/feature_ui.dart';
import '../../../login/data/permissions.dart';
import '../../../login/presentation/access_scope.dart';
import '../../data/model/backup_settings_model.dart';
import '../provider/backup_provider.dart';

/// Backup Settings: connect a Supabase project, run a backup now, or restore a
/// fresh machine from the cloud copy.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key, this.provider});

  static const String routeName = '/backup';

  final BackupProvider? provider;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  late final BackupProvider _provider = widget.provider ?? BackupProvider();

  final _url = TextEditingController();
  final _key = TextEditingController();
  bool _enabled = false;
  bool _showKey = false;
  bool _formPrimed = false;

  @override
  void initState() {
    super.initState();
    _provider.addListener(_onProvider);
    _provider.load();
  }

  @override
  void dispose() {
    _provider.removeListener(_onProvider);
    if (widget.provider == null) _provider.dispose();
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  void _onProvider() {
    if (!_formPrimed && !_provider.loading) {
      final s = _provider.settings;
      _url.text = s.supabaseUrl;
      _key.text = s.supabaseKey;
      _enabled = s.enabled;
      _formPrimed = true;
      if (mounted) setState(() {});
    }
  }

  BackupSettingsModel get _edited => _provider.settings.copyWith(
        enabled: _enabled,
        supabaseUrl: _url.text.trim(),
        supabaseKey: _key.text.trim(),
      );

  bool get _dirty {
    final s = _provider.settings;
    return _enabled != s.enabled ||
        _url.text.trim() != s.supabaseUrl ||
        _key.text.trim() != s.supabaseKey;
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = AccessScope.of(context).can('backup', PermAction.edit);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup'),
        actions: [
          IconButton(
            tooltip: 'Reload',
            icon: const AppIcon(AppIcons.refresh),
            onPressed: _provider.load,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListenableBuilder(
        listenable: _provider,
        builder: (context, _) {
          if (_provider.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              if (_provider.message != null)
                _Banner(
                  text: _provider.message!,
                  icon: AppIcons.check_circle,
                  color: const Color(0xFF2E7D32),
                ),
              if (_provider.error != null)
                _Banner(
                  text: _provider.error!,
                  icon: AppIcons.error_outline,
                  color: const Color(0xFFC62828),
                ),
              _connectionCard(canEdit),
              const SizedBox(height: 16),
              _statusCard(),
              const SizedBox(height: 16),
              _actionsCard(canEdit),
              const SizedBox(height: 16),
              _exportClearCard(canEdit),
            ],
          );
        },
      ),
    );
  }

  Widget _connectionCard(bool canEdit) {
    return SectionCard(
      title: 'Supabase connection',
      subtitle: 'The whole database is mirrored into one "pos_backup" table in '
          'your Supabase project. The key stays on this machine.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-backup every 6 hours'),
            subtitle: const Text('While the app is open'),
            value: _enabled,
            onChanged: canEdit ? (v) => setState(() => _enabled = v) : null,
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _url,
            enabled: canEdit,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Project URL',
              hintText: 'https://xxxxxxxx.supabase.co',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _key,
            enabled: canEdit,
            obscureText: !_showKey,
            decoration: InputDecoration(
              labelText: 'API key (publishable or service_role)',
              helperText: 'Settings → API → Project API keys',
              suffixIcon: IconButton(
                tooltip: _showKey ? 'Hide' : 'Show',
                icon: AppIcon(
                  _showKey
                      ? AppIcons.visibility_off_outlined
                      : AppIcons.visibility_outlined,
                  size: 18,
                ),
                onPressed: () => setState(() => _showKey = !_showKey),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: (canEdit && _dirty && !_provider.busy)
                  ? () => _provider.saveConfig(_edited)
                  : null,
              icon: const AppIcon(AppIcons.save_outlined),
              label: const Text('Save connection'),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'First time: run lib/features/backup/data/sql/supabase_backup.sql '
            'in the Supabase SQL editor.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard() {
    final s = _provider.settings;
    final scheme = Theme.of(context).colorScheme;
    final last = s.lastBackupAt;
    final lastText = last == null
        ? 'Never'
        : '${Fmt.date(last)}  '
            '${last.hour.toString().padLeft(2, '0')}:'
            '${last.minute.toString().padLeft(2, '0')}';

    return SectionCard(
      title: 'Status',
      child: Column(
        children: [
          _row('Last backup', lastText),
          if (s.lastStatus.isNotEmpty)
            _row(
              'Result',
              s.lastStatus,
              color: s.lastBackupOk
                  ? const Color(0xFF2E7D32)
                  : scheme.error,
            ),
          _row(
            'Auto-backup',
            s.enabled
                ? (s.isConfigured
                    ? 'On — every 6 hours'
                    : 'On — waiting for the URL / key')
                : 'Off',
          ),
        ],
      ),
    );
  }

  Widget _actionsCard(bool canEdit) {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      title: 'Run now',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed:
                (canEdit && _provider.settings.isConfigured && !_provider.busy)
                    ? _provider.backupNow
                    : null,
            icon: _provider.busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const AppIcon(AppIcons.history),
            label: const Text('Back up now'),
          ),
          const SizedBox(height: 20),
          Text(
            'Restore',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Pulls the whole backup from Supabase into this machine. It only '
            'runs when the local database is empty, so it can never overwrite '
            'live data.',
            style: TextStyle(fontSize: 12, color: scheme.outline),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed:
                (canEdit && _provider.settings.isConfigured && !_provider.busy)
                    ? _confirmRestore
                    : null,
            icon: const AppIcon(AppIcons.download, size: 16),
            label: const Text('Restore from Supabase'),
          ),
        ],
      ),
    );
  }

  Widget _exportClearCard(bool canEdit) {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      title: 'Export & clear',
      subtitle: 'Save every table to CSV files, then wipe the local data for a '
          'fresh start. Login and the shop header are kept.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed:
                (canEdit && !_provider.busy) ? _exportAndClear : null,
            icon: _provider.busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const AppIcon(AppIcons.download,
                    size: 16, color: Color(0xFFC62828)),
            label: const Text('Export to CSV, then clear'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFC62828),
              side: const BorderSide(color: Color(0xFFC62828)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You pick the folder. A "pos_export_<date>" folder is created with '
            'one CSV per table before anything is deleted.',
            style: TextStyle(fontSize: 12, color: scheme.outline),
          ),
        ],
      ),
    );
  }

  Future<void> _exportAndClear() async {
    final dir = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose where to save the CSV export',
    );
    if (dir == null || !mounted) return;

    final folder = await _provider.exportCsv(dir);
    if (folder == null || !mounted) return; // error already surfaced

    final proceed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete all local data?'),
        content: Text(
          'The CSV export is saved at:\n$folder\n\n'
          'Every product, customer, invoice, stock and account entry will now '
          'be permanently removed from this machine. Login and the shop header '
          'stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep data'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC62828)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (proceed == true && mounted) await _provider.clearLocal();
  }

  Future<void> _confirmRestore() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restore from Supabase?'),
        content: const Text(
          'Every table from the cloud backup will be loaded into this machine. '
          'This only works on an empty database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (yes == true) await _provider.restoreNow();
  }

  Widget _row(String label, String value, {Color? color}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: color)),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.icon, required this.color});

  final String text;
  final String icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
