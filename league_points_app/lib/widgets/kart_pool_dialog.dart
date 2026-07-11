import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/season_document.dart';
import '../models/kart.dart';

/// Lets the operator manage the season's kart pool: add/remove kart numbers
/// (tagged Pro or Junior), and mark a kart broken/down for the week
/// currently being viewed on the Kart Pick Order screen.
class KartPoolDialog extends StatefulWidget {
  const KartPoolDialog({super.key, required this.week});

  final int week;

  @override
  State<KartPoolDialog> createState() => _KartPoolDialogState();
}

class _KartPoolDialogState extends State<KartPoolDialog> {
  final _numberController = TextEditingController();
  KartClass _newKartClass = KartClass.pro;

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  void _addKart(SeasonDocument doc) {
    final number = int.tryParse(_numberController.text.trim());
    if (number == null) return;
    doc.addKart(number, _newKartClass);
    _numberController.clear();
  }

  Future<void> _loadFromFile(SeasonDocument doc) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final loaded = await doc.loadKartRosterFromFile();
      if (!loaded || !mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Kart roster loaded.')),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not read that kart roster file.')),
      );
    }
  }

  Future<void> _saveToFile(SeasonDocument doc) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await doc.saveKartRosterToFile();
      if (!saved || !mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Kart roster saved.')),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save the kart roster file.')),
      );
    }
  }

  /// Lays karts out in a fixed-column grid (3 per row by default) that wraps
  /// to fit whatever width the dialog is given.
  Widget _kartGrid(SeasonDocument doc, List<Kart> karts) {
    const spacing = 10.0;
    const columns = 3;
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final kart in karts)
              SizedBox(width: tileWidth, child: _kartTile(doc, kart)),
          ],
        );
      },
    );
  }

  Widget _kartTile(SeasonDocument doc, Kart kart) {
    final isDown = kart.isDownForWeek(widget.week);
    return Card(
      key: ValueKey(kart.number),
      margin: EdgeInsets.zero,
      color: isDown
          ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.35)
          : null,
      child: InkWell(
        onTap: () => doc.setKartDownForWeek(kart.number, widget.week, !isDown),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: isDown,
                onChanged: (value) => doc.setKartDownForWeek(
                  kart.number,
                  widget.week,
                  value ?? false,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Kart ${kart.number}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      isDown ? 'Down' : 'Available',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                tooltip: 'Remove from pool',
                onPressed: () => doc.removeKart(kart.number),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doc = context.watch<SeasonDocument>();
    final proKarts =
        doc.season.kartPool.where((k) => k.classType == KartClass.pro).toList()
          ..sort((a, b) => a.number.compareTo(b.number));
    final juniorKarts =
        doc.season.kartPool
            .where((k) => k.classType == KartClass.junior)
            .toList()
          ..sort((a, b) => a.number.compareTo(b.number));

    final screenSize = MediaQuery.sizeOf(context);
    final dialogWidth = (screenSize.width * 0.9).clamp(360.0, 720.0);
    final dialogHeight = (screenSize.height * 0.85).clamp(360.0, 640.0);

    return AlertDialog(
      title: const Text('Kart Pool'),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: dialogHeight),
        child: SizedBox(
          width: dialogWidth,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pro karts',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                if (proKarts.isEmpty) const Text('None yet.'),
                if (proKarts.isNotEmpty) _kartGrid(doc, proKarts),
                const SizedBox(height: 16),
                Text(
                  'Junior karts',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                if (juniorKarts.isEmpty) const Text('None yet.'),
                if (juniorKarts.isNotEmpty) _kartGrid(doc, juniorKarts),
                const Divider(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _loadFromFile(doc),
                      icon: const Icon(Icons.file_open_outlined, size: 18),
                      label: const Text('Load karts from file'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _saveToFile(doc),
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Save karts to file'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _numberController,
                        decoration: const InputDecoration(labelText: 'Kart #'),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onSubmitted: (_) => _addKart(doc),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<KartClass>(
                      value: _newKartClass,
                      items: const [
                        DropdownMenuItem(
                          value: KartClass.pro,
                          child: Text('Pro'),
                        ),
                        DropdownMenuItem(
                          value: KartClass.junior,
                          child: Text('Junior'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _newKartClass = value);
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: 'Add kart',
                      onPressed: () => _addKart(doc),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
