import 'package:flutter/material.dart';

/// A type-to-search dropdown used everywhere a picker is needed.
///
/// * Filters the list as you type.
/// * Fills the width it is given.
/// * `includeNull` adds a leading "all / none" entry (for filters).
/// * `allowCustom` (String values only) keeps whatever the user types even
///   when it is not in [items] — used to add a new category / type on the fly.
class SearchableDropdown<T> extends StatefulWidget {
  const SearchableDropdown({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.itemLabel,
    this.hintText,
    this.enabled = true,
    this.includeNull = false,
    this.nullLabel = 'All',
    this.allowCustom = false,
    this.validator,
  });

  final List<T> items;
  final T? value;
  final ValueChanged<T?> onChanged;

  /// How to render an item. Defaults to `toString()`.
  final String Function(T value)? itemLabel;

  final String? hintText;
  final bool enabled;
  final bool includeNull;
  final String nullLabel;
  final bool allowCustom;
  final String? Function(T? value)? validator;

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  final _controller = TextEditingController();

  String _label(T v) => widget.itemLabel?.call(v) ?? '$v';

  @override
  void initState() {
    super.initState();
    _controller.text = widget.value == null ? '' : _label(widget.value as T);
    if (widget.allowCustom) _controller.addListener(_onCustomEdit);
  }

  @override
  void didUpdateWidget(covariant SearchableDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.value == null ? '' : _label(widget.value as T);
    if (incoming != _controller.text &&
        !(widget.allowCustom && _controller.text.trim() == incoming.trim())) {
      _controller.text = incoming;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onCustomEdit);
    _controller.dispose();
    super.dispose();
  }

  void _onCustomEdit() {
    final text = _controller.text.trim();
    final match = widget.items
        .where((e) => _label(e).toLowerCase() == text.toLowerCase())
        .toList();
    if (match.isNotEmpty) {
      if (match.first != widget.value) widget.onChanged(match.first);
    } else {
      // Only String T can hold arbitrary text.
      widget.onChanged(text.isEmpty ? null : text as T);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = <DropdownMenuEntry<T?>>[
      if (widget.includeNull)
        DropdownMenuEntry<T?>(value: null, label: widget.nullLabel),
      for (final item in widget.items)
        DropdownMenuEntry<T?>(value: item, label: _label(item)),
    ];

    final field = DropdownMenu<T?>(
      controller: _controller,
      enabled: widget.enabled,
      initialSelection: widget.value,
      enableFilter: true,
      enableSearch: true,
      requestFocusOnTap: widget.enabled,
      hintText: widget.hintText,
      menuHeight: 320,
      expandedInsets: EdgeInsets.zero,
      dropdownMenuEntries: entries,
      onSelected: widget.onChanged,
    );

    if (widget.validator == null) return field;

    return FormField<T?>(
      initialValue: widget.value,
      validator: widget.validator,
      builder: (state) {
        // keep the FormField value in sync
        if (state.value != widget.value) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => state.didChange(widget.value),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            field,
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 0, 0),
                child: Text(
                  state.errorText!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
