import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../config/constants.dart';
import '../../services/location_service.dart';
import '../../widgets/radius_selector.dart';
import '../../widgets/custom_button.dart';
import '../../utils/distance_utils.dart';

class MapPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final double? initialRadius;

  const MapPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialRadius,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  LatLng? _pendingCameraTarget;
  MapType _mapType = MapType.normal;
  double _radius = AppConstants.defaultRadius;
  bool _isLoadingLocation = false;
  bool _isMapReady = false;
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedLocation =
          LatLng(widget.initialLatitude!, widget.initialLongitude!);
    } else {
      _setDefaultLocationToCurrentPosition();
    }
    _radius = widget.initialRadius ?? AppConstants.defaultRadius;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // _updateOverlays() reads Theme.of(context), which isn't safe to call
    // from initState() before the first build - do the initial overlay
    // computation here instead.
    _updateOverlays();
  }

  Future<void> _setDefaultLocationToCurrentPosition() async {
    final position = await LocationService.instance.getCurrentLocation();
    if (!mounted || position == null || _selectedLocation != null) return;

    final target = LatLng(position.latitude, position.longitude);
    setState(() {
      _selectedLocation = target;
      _updateOverlays();
    });

    if (_mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(target, AppConstants.defaultMapZoom),
      );
    } else {
      _pendingCameraTarget = target;
    }
  }

  void _updateOverlays() {
    _markers.clear();
    _circles.clear();

    if (_selectedLocation != null) {
      final primary = Theme.of(context).colorScheme.primary;
      _markers.add(
        Marker(
          markerId: const MarkerId('selected_location'),
          position: _selectedLocation!,
          infoWindow: InfoWindow(
            title: 'Alarm Location',
            snippet: 'Radius: ${DistanceUtils.formatRadius(_radius)}',
          ),
        ),
      );

      _circles.add(
        Circle(
          circleId: const CircleId('geofence_radius'),
          center: _selectedLocation!,
          radius: _radius,
          fillColor: primary.withAlpha(51),
          strokeColor: primary,
          strokeWidth: 2,
        ),
      );
    }
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    final position = await LocationService.instance.getCurrentLocation();
    if (!mounted) return;
    setState(() => _isLoadingLocation = false);

    if (position != null && _mapController != null) {
      final target = LatLng(position.latitude, position.longitude);
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(target, AppConstants.defaultMapZoom),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to get current location')),
      );
    }
  }

  void _onMapTapped(LatLng position) {
    setState(() {
      _selectedLocation = position;
      _updateOverlays();
    });
  }

  void _onRadiusChanged(double radius) {
    setState(() {
      _radius = radius;
      _updateOverlays();
    });
  }

  void _confirmSelection() {
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please tap on the map to select a location'),
        ),
      );
      return;
    }

    Navigator.of(context).pop({
      'latitude': _selectedLocation!.latitude,
      'longitude': _selectedLocation!.longitude,
      'radius': _radius,
    });
  }

  void _onMapTypeSelected(MapType type) {
    if (_mapType == type) return;
    setState(() => _mapType = type);
  }

  @override
  Widget build(BuildContext context) {
    final initialPosition = _selectedLocation ??
        const LatLng(AppConstants.defaultLatitude, AppConstants.defaultLongitude);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        actions: [
          PopupMenuButton<MapType>(
            tooltip: 'Map type',
            icon: const Icon(Icons.layers_outlined),
            onSelected: _onMapTypeSelected,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: MapType.normal,
                child: Row(
                  children: [
                    if (_mapType == MapType.normal)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(Icons.check, size: 18),
                      )
                    else
                      const SizedBox(width: 26),
                    const Text('Default'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: MapType.satellite,
                child: Row(
                  children: [
                    if (_mapType == MapType.satellite)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(Icons.check, size: 18),
                      )
                    else
                      const SizedBox(width: 26),
                    const Text('Satellite'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: initialPosition,
                    zoom: AppConstants.defaultMapZoom,
                  ),
                  onMapCreated: (controller) async {
                    _mapController = controller;
                    if (_pendingCameraTarget != null) {
                      await controller.animateCamera(
                        CameraUpdate.newLatLngZoom(
                          _pendingCameraTarget!,
                          AppConstants.defaultMapZoom,
                        ),
                      );
                      _pendingCameraTarget = null;
                    }
                    if (mounted) setState(() => _isMapReady = true);
                  },
                  onTap: _onMapTapped,
                  markers: _markers,
                  circles: _circles,
                  mapType: _mapType,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  mapToolbarEnabled: false,
                  zoomControlsEnabled: true,
                ),
                if (!_isMapReady)
                  Container(
                    color: colorScheme.surface,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'currentLocationFab',
                    onPressed: _isLoadingLocation ? null : _goToCurrentLocation,
                    tooltip: 'Go to my location',
                    child: _isLoadingLocation
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withAlpha(30),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_selectedLocation != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 16, color: colorScheme.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${_selectedLocation!.latitude.toStringAsFixed(6)}, '
                            '${_selectedLocation!.longitude.toStringAsFixed(6)}',
                            style: TextStyle(
                                fontSize: 13, color: colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(Icons.touch_app,
                            size: 16, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          'Tap on the map to select a location',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                RadiusSelector(
                  selectedRadius: _radius,
                  onChanged: _onRadiusChanged,
                ),
                const SizedBox(height: 16),
                CustomButton(
                  label: 'Confirm Location',
                  onPressed: _confirmSelection,
                  icon: Icons.check,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

