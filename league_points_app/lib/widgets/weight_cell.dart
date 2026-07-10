import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// An inline-editable driver-weight cell. Leaving it blank clears the
/// recorded weight for that racer/week.
class WeightCell extends StatefulWidget {
  const WeightCell({
    super.key,
    required this.weight,
    required this.onChanged,
  });

  final double? weight;
  final ValueChanged<double?> onChanged;

  @override
  State<WeightCell> createState() => _WeightCellState();
}

class _WeightCellState extends State<WeightCell> {
  late final TextEditingController _controller =
      TextEditingController(text: _format(widget.weight));
  late final FocusNode _focusNode = FocusNode()..addListener(_onFocusChange);

  static String _format(double? weight) {
    if (weight == null) return '';
    return weight == weight.roundToDouble()
        ? weight.toInt().toString()
        : weight.toString();
  }

  @override
  void didUpdateWidget(WeightCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weight != widget.weight && !_focusNode.hasFocus) {
      _controller.text = _format(widget.weight);
    }
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) _commit();
  }

  void _commit() {
    final text = _controller.text.trim();
    final parsed = text.isEmpty ? null : double.tryParse(text);
    if (parsed != widget.weight) widget.onChanged(parsed);
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
      width: 88,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$'))],
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
          hintText: 'lbs',
        ),
        onSubmitted: (_) => _commit(),
      ),
    );
  }
}
