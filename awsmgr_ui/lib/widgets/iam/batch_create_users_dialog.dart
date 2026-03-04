import 'package:flutter/material.dart';

/// Dialog for batch-creating multiple IAM users at once.
class BatchCreateUsersDialog extends StatefulWidget {
  const BatchCreateUsersDialog({super.key});

  @override
  State<BatchCreateUsersDialog> createState() => _BatchCreateUsersDialogState();
}

class _BatchCreateUsersDialogState extends State<BatchCreateUsersDialog> {
  final List<_UserEntry> _users = [_UserEntry()];
  final _scrollController = ScrollController();

  void _addUser() {
    setState(() => _users.add(_UserEntry()));
    // Scroll to bottom after adding
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _removeUser(int index) {
    if (_users.length > 1) {
      setState(() => _users.removeAt(index));
    }
  }

  bool get _canCreate {
    return _users.every((user) => user.isValid);
  }

  List<Map<String, dynamic>> _getUsersData() {
    return _users.map((user) => user.toJson()).toList();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (var user in _users) {
      user.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.group_add, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Batch Create Users',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Create multiple IAM users at once',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Users list
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  return _UserEntryWidget(
                    key: ValueKey(_users[index]),
                    entry: _users[index],
                    index: index,
                    canRemove: _users.length > 1,
                    onRemove: () => _removeUser(index),
                    onChanged: () => setState(() {}),
                  );
                },
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _addUser,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add User'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_users.length} user(s)',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _canCreate
                              ? () => Navigator.pop(context, _getUsersData())
                              : null,
                          icon: const Icon(Icons.group_add, size: 18),
                          label: const Text('Create All'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// User Entry Model
class _UserEntry {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool setPassword = false;
  bool requireReset = false;
  bool obscurePassword = true;

  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;

  bool get isValid {
    if (usernameController.text.isEmpty) return false;
    if (setPassword) {
      return _hasMinLength && _hasUppercase && _hasLowercase && _hasNumber;
    }
    return true;
  }

  void validatePassword() {
    final password = passwordController.text;
    _hasMinLength = password.length >= 8;
    _hasUppercase = password.contains(RegExp(r'[A-Z]'));
    _hasLowercase = password.contains(RegExp(r'[a-z]'));
    _hasNumber = password.contains(RegExp(r'[0-9]'));
  }

  Map<String, dynamic> toJson() {
    return {
      'username': usernameController.text,
      if (setPassword) 'password': passwordController.text,
      if (setPassword) 'require_reset': requireReset,
    };
  }

  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
  }
}

// User Entry Widget
class _UserEntryWidget extends StatefulWidget {
  final _UserEntry entry;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _UserEntryWidget({
    super.key,
    required this.entry,
    required this.index,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_UserEntryWidget> createState() => _UserEntryWidgetState();
}

class _UserEntryWidgetState extends State<_UserEntryWidget> {
  @override
  void initState() {
    super.initState();
    widget.entry.passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    widget.entry.validatePassword();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '#${widget.index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: widget.entry.usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username *',
                      hintText: 'Enter username',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.person, size: 20),
                      isDense: true,
                    ),
                    onChanged: (_) => widget.onChanged(),
                  ),
                ),
                if (widget.canRemove) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red,
                    onPressed: widget.onRemove,
                    tooltip: 'Remove',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: widget.entry.setPassword,
              onChanged: (value) {
                setState(() {
                  widget.entry.setPassword = value ?? false;
                  if (!widget.entry.setPassword) {
                    widget.entry.passwordController.clear();
                    widget.entry.requireReset = false;
                  }
                });
                widget.onChanged();
              },
              title: const Text('Set password', style: TextStyle(fontSize: 14)),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
            if (widget.entry.setPassword) ...[
              const SizedBox(height: 8),
              TextField(
                controller: widget.entry.passwordController,
                obscureText: widget.entry.obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password *',
                  hintText: 'Enter password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.lock, size: 20),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: Icon(
                      widget.entry.obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        widget.entry.obscurePassword =
                            !widget.entry.obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _buildChip('8+ chars', widget.entry._hasMinLength),
                  _buildChip('A-Z', widget.entry._hasUppercase),
                  _buildChip('a-z', widget.entry._hasLowercase),
                  _buildChip('0-9', widget.entry._hasNumber),
                ],
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: widget.entry.requireReset,
                onChanged: (value) {
                  setState(() =>
                      widget.entry.requireReset = value ?? false);
                  widget.onChanged();
                },
                title: const Text(
                  'Require reset',
                  style: TextStyle(fontSize: 13),
                ),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, bool met) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: met ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: met ? Colors.green.shade300 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            met ? Icons.check : Icons.close,
            size: 12,
            color: met ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: met ? Colors.green.shade700 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
