import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// An inline-editable "finish position" cell for one racer in one week.
/// The director types the place the racer finished (e.g. 1, 2, 3...);
/// the computed points for that position are shown below it. Leaving the
/// field blank clears the result for that week (no race/no data).
class WeekPositionCell extends StatefulWidget {
  const WeekPositionCell({
    super.key,
    required this.finishPosition,
    required this.points,
    required this.onChanged,
  });

  final int? finishPosition;
  final int points;
  final ValueChanged<int?> onChanged;

  @override
  State<WeekPositionCell> createState() => _WeekPositionCellState();
}

class _WeekPositionCellState extends State<WeekPositionCell> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.finishPosition?.toString() ?? '');
  late final FocusNode _focusNode = FocusNode()..addListener(_onFocusChange);

  @override
  void didUpdateWidget(WeekPositionCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.finishPosition != widget.finishPosition && !_focusNode.hasFocus) {
      _controller.text = widget.finishPosition?.toString() ?? '';
    }
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) _commit();
  }

  void _commit() {
    final text = _controller.text.trim();
    final parsed = text.isEmpty ? null : int.tryParse(text);
    if (parsed != widget.finishPosition) widget.onChanged(parsed);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
              hintText: 'Pos',
            ),
            onSubmitted: (_) => _commit(),
          ),
          Text(
            '${widget.points} pts',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
