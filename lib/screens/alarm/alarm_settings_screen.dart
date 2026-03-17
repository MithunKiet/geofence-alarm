import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/alarm_model.dart';
import '../../providers/alarm_provider.dart';
import '../../config/app_routes.dart';
import '../../config/constants.dart';
import '../../utils/validators.dart';
import '../../utils/distance_utils.dart';
import '../../widgets/radius_selector.dart';
import '../../widgets/custom_button.dart';

class AlarmSettingsScreen extends StatefulWidget {
  final AlarmModel? existingAlarm;

  const AlarmSettingsScreen({super.key, this.existingAlarm});

  @override
  State<AlarmSettingsScreen> createState() => _AlarmSettingsScreenState();
}

class _AlarmSettingsScreenState extends State<AlarmSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();

  double? _latitude;
  double? _longitude;
  double _radius = AppConstants.defaultRadius;
  bool _isSaving = false;
  GoogleMapController? _previewMapController;

  bool get _isEditing => widget.existingAlarm != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final alarm = widget.existingAlarm!;
      _titleController.text = alarm.title;
      _latitude = alarm.latitude;
      _longitude = alarm.longitude;
      _radius = alarm.radius;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _previewMapController?.dispose();
    super.dispose();
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.of(context).pushNamed(
      AppRoutes.mapPicker,
      arguments: {
        'latitude': _latitude,
        'longitude': _longitude,
        'radius': _radius,
      },
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _latitude = result['latitude'] as double;
        _longitude = result['longitude'] as double;
        _radius = result['radius'] as double;
      });

      if (_previewMapController != null) {
        await _previewMapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(_latitude!, _longitude!),
            AppConstants.defaultMapZoom,
          ),
        );
      }
    }
  }

  Future<void> _saveAlarm() async {
    if (!_formKey.currentState!.validate()) return;

    final locationError = Validators.validateLocation(_latitude, _longitude);
    if (locationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(locationError), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    final provider = context.read<AlarmProvider>();
    bool success;

    if (_isEditing) {
      final updated = widget.existingAlarm!.copyWith(
        title: _titleController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        radius: _radius,
      );
      success = await provider.updateAlarm(updated);
    } else {
      final newAlarm = AlarmModel(
        title: _titleController.text.trim(),
        latitude: _latitude!,
        longitude: _longitude!,
        radius: _radius,
        isActive: true,
        createdAt: DateTime.now(),
      );
      final result = await provider.addAlarm(newAlarm);
      success = result != null;
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to save alarm'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Alarm' : 'New Alarm'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title field
            Text(
              'Alarm Name',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'e.g. Home, Office, Gym...',
                prefixIcon: Icon(Icons.label_outline),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 50,
              validator: Validators.validateAlarmTitle,
            ),
            const SizedBox(height: 24),

            // Location section
            Text(
              'Location',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (_latitude != null && _longitude != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 200,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(_latitude!, _longitude!),
                      zoom: AppConstants.defaultMapZoom,
                    ),
                    onMapCreated: (c) => _previewMapController = c,
                    markers: {
                      Marker(
                        markerId: const MarkerId('preview'),
                        position: LatLng(_latitude!, _longitude!),
                      ),
                    },
                    circles: {
                      Circle(
                        circleId: const CircleId('preview_radius'),
                        center: LatLng(_latitude!, _longitude!),
                        radius: _radius,
                        fillColor: Colors.indigo.withAlpha(51),
                        strokeColor: Colors.indigo,
                        strokeWidth: 2,
                      ),
                    },
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    scrollGesturesEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                    zoomGesturesEnabled: false,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '📍 ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}  '
                '· Radius: ${DistanceUtils.formatRadius(_radius)}',
                style:
                    Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              icon: const Icon(Icons.map),
              label: Text(_latitude == null ? 'Pick on Map' : 'Change Location'),
              onPressed: _openMapPicker,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Radius selector
            RadiusSelector(
              selectedRadius: _radius,
              onChanged: (r) => setState(() => _radius = r),
            ),
            const SizedBox(height: 32),

            // Save button
            CustomButton(
              label: _isEditing ? 'Update Alarm' : 'Save Alarm',
              onPressed: _saveAlarm,
              isLoading: _isSaving,
              icon: Icons.save,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
