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
    final options = AppConstants.radiusOptions;
    final colorScheme = Theme.of(context).colorScheme;
    final selectedIndex = options.indexOf(selectedRadius);
    final sliderIndex = (selectedIndex == -1 ? 0 : selectedIndex).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Alarm Radius',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                DistanceUtils.formatRadius(selectedRadius),
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: sliderIndex,
            min: 0,
            max: (options.length - 1).toDouble(),
            divisions: options.length - 1,
            label: DistanceUtils.formatRadius(options[sliderIndex.round()]),
            onChanged: (value) => onChanged(options[value.round()]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DistanceUtils.formatRadius(options.first),
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              Text(
                DistanceUtils.formatRadius(options.last),
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
