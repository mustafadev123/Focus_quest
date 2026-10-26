import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/validation/validation.dart';

/// "Estimated time (minutes)": a 5–120 slider with a numeric text box as the
/// accessible alternative. Both edit the same [controller]; the validation
/// message is shown full-width below the row.
class MinutesField extends StatefulWidget {
  const MinutesField({super.key, required this.controller, this.onChanged});

  final TextEditingController controller;
  final VoidCallback? onChanged;

  @override
  State<MinutesField> createState() => _MinutesFieldState();
}

class _MinutesFieldState extends State<MinutesField> {
  static const _min = Limits.minEstimatedMinutes;
  static const _max = Limits.maxEstimatedMinutes;

  /// The last valid value, which the slider keeps showing while the text
  /// box holds an invalid entry.
  late double _sliderValue = _parsedOr(_min).toDouble();

  int _parsedOr(int fallback) {
    final value = parseMinutes(widget.controller.text);
    return value == null || validateEstimatedMinutes(value) != null
        ? fallback
        : value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall;

    return FormField<String>(
      validator: (_) =>
          validateEstimatedMinutes(parseMinutes(widget.controller.text)),
      builder: (field) {
        void changed() {
          field.didChange(widget.controller.text);
          widget.onChanged?.call();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(child: Text('$_min', style: muted)),
                Expanded(
                  child: Slider(
                    value: _sliderValue,
                    min: _min.toDouble(),
                    max: _max.toDouble(),
                    divisions: _max - _min,
                    label: '${_sliderValue.round()} min',
                    semanticFormatterCallback: (v) =>
                        '${v.round()} minutes estimated',
                    onChanged: (value) {
                      setState(() => _sliderValue = value);
                      widget.controller.text = value.round().toString();
                      changed();
                    },
                  ),
                ),
                ExcludeSemantics(child: Text('$_max', style: muted)),
                const SizedBox(width: 12),
                SizedBox(
                  width: 72,
                  child: Semantics(
                    label: 'Estimated time in minutes',
                    child: TextField(
                      controller: widget.controller,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        isDense: true,
                        error: field.hasError ? const SizedBox.shrink() : null,
                      ),
                      onChanged: (_) {
                        setState(() => _sliderValue =
                            _parsedOr(_sliderValue.round()).toDouble());
                        changed();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ExcludeSemantics(child: Text('min', style: muted)),
              ],
            ),
            if (field.errorText case final error?)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  error,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
          ],
        );
      },
    );
  }
}
