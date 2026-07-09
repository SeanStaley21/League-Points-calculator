import 'package:flutter/material.dart';

/// Shows a Yes/No confirmation dialog. Returns true if the user confirmed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: Colors.red)
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// If [hasUnsavedChanges] is true, asks the user whether to save before
/// proceeding with a destructive action (New/Open/Exit). Returns:
/// - true: proceed (either there was nothing to save, or user chose not to save)
/// - false: cancel the pending action
/// [onSave] is called if the user chooses "Save" and must return whether the
/// save actually completed (e.g. false if a Save As picker was cancelled).
Future<bool> confirmDiscardUnsavedChanges(
  BuildContext context, {
  required bool hasUnsavedChanges,
  required Future<bool> Function() onSave,
}) async {
  if (!hasUnsavedChanges) return true;

  final choice = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Unsaved changes'),
      content: const Text(
          'You have unsaved changes. Do you want to save them first?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop('cancel'),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop('discard'),
          child: const Text("Don't Save"),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop('save'),
          child: const Text('Save'),
        ),
      ],
    ),
  );

  if (choice == 'save') {
    return onSave();
  }
  return choice == 'discard';
}
