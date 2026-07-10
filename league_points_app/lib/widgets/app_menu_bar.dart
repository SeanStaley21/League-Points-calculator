import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/season_document.dart';
import '../screens/auto_import_screen.dart';
import 'confirm_dialog.dart';

enum _FileMenuAction { newSeason, open, save, saveAs, autoImport }

/// The File > New/Open/Save/Save As menu, plus the current file name and
/// unsaved-changes indicator, shown at the top of every screen.
class AppMenuBar extends StatelessWidget implements PreferredSizeWidget {
  const AppMenuBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  Future<void> _handleAction(BuildContext context, _FileMenuAction action) async {
    final doc = context.read<SeasonDocument>();

    switch (action) {
      case _FileMenuAction.newSeason:
        final proceed = await confirmDiscardUnsavedChanges(
          context,
          hasUnsavedChanges: doc.hasUnsavedChanges,
          onSave: doc.save,
        );
        if (proceed) doc.newSeason();
      case _FileMenuAction.open:
        final proceed = await confirmDiscardUnsavedChanges(
          context,
          hasUnsavedChanges: doc.hasUnsavedChanges,
          onSave: doc.save,
        );
        if (proceed) await doc.openFromPicker();
      case _FileMenuAction.save:
        await doc.save();
      case _FileMenuAction.saveAs:
        await doc.saveAs();
      case _FileMenuAction.autoImport:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Auto Import')),
              body: const AutoImportScreen(),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = context.watch<SeasonDocument>();
    final title = doc.displayName + (doc.hasUnsavedChanges ? ' *' : '');

    return AppBar(
      title: Text(title),
      actions: [
        PopupMenuButton<_FileMenuAction>(
          icon: const Icon(Icons.menu),
          tooltip: 'File',
          onSelected: (action) => _handleAction(context, action),
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _FileMenuAction.newSeason,
              child: ListTile(
                leading: Icon(Icons.note_add_outlined),
                title: Text('New'),
              ),
            ),
            PopupMenuItem(
              value: _FileMenuAction.open,
              child: ListTile(
                leading: Icon(Icons.folder_open),
                title: Text('Open...'),
              ),
            ),
            PopupMenuItem(
              value: _FileMenuAction.save,
              child: ListTile(
                leading: Icon(Icons.save_outlined),
                title: Text('Save'),
              ),
            ),
            PopupMenuItem(
              value: _FileMenuAction.saveAs,
              child: ListTile(
                leading: Icon(Icons.save_as_outlined),
                title: Text('Save As...'),
              ),
            ),
            PopupMenuDivider(),
            PopupMenuItem(
              value: _FileMenuAction.autoImport,
              child: ListTile(
                leading: Icon(Icons.upload_file_outlined),
                title: Text('Auto Import...'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
