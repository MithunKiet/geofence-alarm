import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../utils/distance_utils.dart';

class RadiusSelector extends StatelessWidget {
  final double selectedRadius;
  final ValueChanged<double> onChanged;

  const RadiusSelector({
    super.key,
    required this.selectedRadius,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Alarm Radius',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: AppConstants.radiusOptions.map((radius) {
            final isSelected = selectedRadius == radius;
            return ChoiceChip(
              label: Text(DistanceUtils.formatRadius(radius)),
              selected: isSelected,
              onSelected: (_) => onChanged(radius),
              selectedColor:
                  Theme.of(context).colorScheme.primary.withAlpha(51),
              labelStyle: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade700,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade300,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
