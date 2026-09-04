import 'package:flutter/material.dart';
import 'package:pos/shared/app_icon.dart';

import '../../../../shared/searchable_dropdown.dart';
import '../../data/model/login_model.dart';
import '../provider/users_provider.dart';

/// Add / edit form for a user. Pops a [UserDraft] on save.
class UserFormDialog extends StatefulWidget {
  const UserFormDialog({super.key, this.initial});

  final LoginModel? initial;

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _username =
      TextEditingController(text: widget.initial?.username ?? '');
  late final _fullName =
      TextEditingController(text: widget.initial?.fullName ?? '');
  final _password = TextEditingController();
  late String _role = widget.initial?.role ?? 'cashier';
  late bool _isActive = widget.initial?.isActive ?? true;
  bool _obscure = true;

  bool get _isEdit => widget.initial?.id != null;

  @override
  void dispose() {
    _username.dispose();
    _fullName.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      UserDraft(
        id: widget.initial?.id,
        username: _username.text.trim(),
        fullName: _fullName.text.trim(),
        role: _role,
        isActive: _isActive,
        password: _password.text.isEmpty ? null : _password.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit User' : 'Add User'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _username,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Username *'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Username is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fullName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Full name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                decoration: InputDecoration(
                  hintText:
                      _isEdit ? 'New password (leave blank to keep)' : 'Password *',
                  suffixIcon: IconButton(
                    icon: AppIcon(_obscure
                        ? AppIcons.visibility_outlined
                        : AppIcons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) {
                  if (_isEdit) return null;
                  if (v == null || v.isEmpty) return 'Password is required';
                  if (v.length < 4) return 'At least 4 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SearchableDropdown<String>(
                items: kUserRoles,
                value: _role,
                hintText: 'Role',
                itemLabel: (r) => r[0].toUpperCase() + r.substring(1),
                onChanged: (v) => setState(() => _role = v ?? 'cashier'),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                subtitle: const Text('Inactive users cannot log in'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
