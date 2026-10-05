import 'package:flutter/material.dart';
import 'package:pos/shared/app_icon.dart';

import '../../../../config/format.dart';
import '../provider/backup_provider.dart';

/// Shown at startup instead of the login screen when this machine has no data
/// and no users yet: offers to pull the Supabase backup in before anything
/// else happens. [onDone] is called after a restore or when the user skips.
class RestoreBackupScreen extends StatefulWidget {
  const RestoreBackupScreen({super.key, this.provider, required this.onDone});

  final BackupProvider? provider;

  /// `restored` is true when the backup was loaded, false on "Skip".
  final ValueChanged<bool> onDone;

  @override
  State<RestoreBackupScreen> createState() => _RestoreBackupScreenState();
}

class _RestoreBackupScreenState extends State<RestoreBackupScreen> {
  late final BackupProvider _provider = widget.provider ?? BackupProvider();

  final _url = TextEditingController();
  final _key = TextEditingController();
  bool _showKey = false;
  bool _showConnection = false;
  bool _restored = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _provider.load();
    if (!mounted) return;
    _url.text = _provider.settings.supabaseUrl;
    _key.text = _provider.settings.supabaseKey;
    // No baked-in / saved credentials → open the form straight away.
    _showConnection = !_provider.settings.isConfigured;
    setState(() {});
    await _provider.checkCloud();
  }

  @override
  void dispose() {
    if (widget.provider == null) _provider.dispose();
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _url.text.trim() != _provider.settings.supabaseUrl ||
      _key.text.trim() != _provider.settings.supabaseKey;

  /// Saves edited credentials (if any) and re-checks the cloud backup.
  Future<void> _connect() async {
    if (_dirty) {
      final ok = await _provider.saveConfig(_provider.settings.copyWith(
        supabaseUrl: _url.text.trim(),
        supabaseKey: _key.text.trim(),
      ));
      if (!ok) return;
    }
    await _provider.checkCloud();
  }

  Future<void> _restore() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
          'Every table from the cloud backup will be loaded into this '
          'computer. Afterwards, sign in with your usual username and '
          'password.',
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
    if (yes != true || !mounted) return;
    final ok = await _provider.restoreNow();
    if (ok && mounted) setState(() => _restored = true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: scheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                child: ListenableBuilder(
                  listenable: _provider,
                  builder: (context, _) => _restored
                      ? _doneView(scheme)
                      : _restoreView(scheme),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(ColorScheme scheme, String icon, String title, String body) {
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: scheme.primaryContainer,
          child: AppIcon(icon, size: 28, color: scheme.primary),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _doneView(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(
          scheme,
          AppIcons.check_circle,
          'Backup restored',
          _provider.message?.replaceAll(' Restart the app to see it.', '') ??
              'Your data is back on this computer.',
        ),
        FilledButton(
          onPressed: () => widget.onDone(true),
          child: const Text('Continue to sign in'),
        ),
      ],
    );
  }

  Widget _restoreView(ColorScheme scheme) {
    final busy = _provider.busy;
    final cloud = _provider.cloud;
    final canRestore = !busy &&
        !_provider.checkingCloud &&
        _provider.settings.isConfigured &&
        (cloud?.rows ?? 0) > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(
          scheme,
          AppIcons.download,
          'Restore your data',
          'This computer has no data and no users yet. If you used this POS '
              'before, restore your Supabase backup now.',
        ),
        if (_provider.loading)
          const Center(child: CircularProgressIndicator())
        else ...[
          _cloudStatus(scheme),
          if (_provider.error != null) ...[
            const SizedBox(height: 10),
            Text(
              _provider.error!,
              style: TextStyle(color: scheme.error, fontSize: 13),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () =>
                  setState(() => _showConnection = !_showConnection),
              child: Text(_showConnection
                  ? 'Hide Supabase connection'
                  : 'Change Supabase connection'),
            ),
          ),
          if (_showConnection) _connectionForm(busy),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: canRestore ? _restore : null,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const AppIcon(AppIcons.download, size: 16),
            label: Text(busy ? 'Restoring…' : 'Restore backup'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: busy ? null : () => widget.onDone(false),
            child: const Text('Skip — start fresh'),
          ),
        ],
      ],
    );
  }

  Widget _cloudStatus(ColorScheme scheme) {
    final String text;
    Color? color;
    if (!_provider.settings.isConfigured) {
      text = 'Enter your Supabase URL and key to look for a backup.';
    } else if (_provider.checkingCloud) {
      text = 'Looking for a backup…';
    } else if (_provider.cloud == null) {
      text = 'Could not check for a backup.';
      color = scheme.error;
    } else if (_provider.cloud!.rows == 0) {
      text = 'No backup was found in this Supabase project.';
      color = scheme.error;
    } else {
      final c = _provider.cloud!;
      final last = c.lastAt;
      final when = last == null
          ? ''
          : ' · last saved ${Fmt.date(last)} '
              '${last.hour.toString().padLeft(2, '0')}:'
              '${last.minute.toString().padLeft(2, '0')}';
      text = 'Backup found: ${c.rows} row(s)$when';
      color = const Color(0xFF2E7D32);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          if (_provider.checkingCloud) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontWeight: FontWeight.w600, color: color),
            ),
          ),
          if (_provider.settings.isConfigured && !_provider.checkingCloud)
            IconButton(
              tooltip: 'Check again',
              icon: const AppIcon(AppIcons.refresh, size: 16),
              onPressed: _provider.busy ? null : _provider.checkCloud,
            ),
        ],
      ),
    );
  }

  Widget _connectionForm(bool busy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _url,
          enabled: !busy,
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
          enabled: !busy,
          obscureText: !_showKey,
          decoration: InputDecoration(
            labelText: 'API key',
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
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton(
            onPressed: busy ||
                    _url.text.trim().isEmpty ||
                    _key.text.trim().isEmpty
                ? null
                : _connect,
            child: const Text('Connect & check'),
          ),
        ),
      ],
    );
  }
}
