import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/alarm_model.dart';
import '../providers/alarm_provider.dart';
import '../utils/distance_utils.dart';
import '../config/app_routes.dart';

class AlarmCard extends StatelessWidget {
  final AlarmModel alarm;

  const AlarmCard({super.key, required this.alarm});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AlarmProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final mutedColor = colorScheme.onSurfaceVariant;

    return Dismissible(
      key: ValueKey('alarm_${alarm.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) {
        if (alarm.id != null) provider.deleteAlarm(alarm.id!);
      },
      child: Opacity(
        opacity: alarm.isActive ? 1 : 0.6,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  color: alarm.isActive
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    alarm.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on,
                                          size: 14, color: mutedColor),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${alarm.latitude.toStringAsFixed(5)}, '
                                          '${alarm.longitude.toStringAsFixed(5)}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(color: mutedColor),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.radar,
                                          size: 14, color: mutedColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Radius: ${DistanceUtils.formatRadius(alarm.radius)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: mutedColor),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: alarm.isActive,
                              onChanged: (val) =>
                                  _toggleAlarm(context, provider, val),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Edit'),
                              onPressed: () => Navigator.of(context).pushNamed(
                                AppRoutes.alarmSettings,
                                arguments: alarm,
                              ),
                            ),
                            const SizedBox(width: 4),
                            TextButton.icon(
                              icon: Icon(Icons.delete_outline,
                                  size: 16, color: colorScheme.error),
                              label: Text('Delete',
                                  style: TextStyle(color: colorScheme.error)),
                              onPressed: () async {
                                if (await _confirmDelete(context) == true &&
                                    alarm.id != null &&
                                    context.mounted) {
                                  await provider.deleteAlarm(alarm.id!);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleAlarm(
      BuildContext context, AlarmProvider provider, bool value) async {
    final success = await provider.toggleAlarm(alarm.id!, value);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Failed to update alarm')),
      );
    }
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Alarm'),
        content: Text(
            'Are you sure you want to delete "${alarm.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
