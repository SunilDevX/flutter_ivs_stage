import 'package:flutter/material.dart';

import '../../flutter_ivs_stage.dart';

/// A widget that provides camera preview functionality before joining a stage
///
/// This widget allows users to see their camera feed and toggle between
/// front and back cameras before joining a stage session.
class CameraPreviewWidget extends StatefulWidget {
  /// Camera type to use initially ('front' or 'back')
  final String initialCameraType;

  /// Aspect mode for the preview ('fill' or 'fit')
  final String aspectMode;

  /// Whether to show camera toggle controls
  final bool showControls;

  /// Background color when no preview is available
  final Color backgroundColor;

  /// Border radius for the preview container
  final double borderRadius;

  /// Callback when camera type changes
  final Function(String cameraType)? onCameraChanged;

  /// Callback when preview fails to initialize
  final Function(String error)? onError;

  const CameraPreviewWidget({
    super.key,
    this.initialCameraType = 'front',
    this.aspectMode = 'fill',
    this.showControls = true,
    this.backgroundColor = Colors.black,
    this.borderRadius = 12.0,
    this.onCameraChanged,
    this.onError,
  });

  @override
  State<CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget> {
  bool _isPreviewActive = false;
  String _currentCameraType = 'front';
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    _currentCameraType = widget.initialCameraType;
    _initializePreview();
  }

  Future<void> _initializePreview() async {
    if (_isInitializing) return;

    setState(() {
      _isInitializing = true;
    });

    try {
      await FlutterIvsStage.initPreview(
        cameraType: _currentCameraType,
        aspectMode: widget.aspectMode,
      );
      setState(() {
        _isPreviewActive = true;
        _isInitializing = false;
      });
    } catch (e) {
      setState(() {
        _isInitializing = false;
      });
      widget.onError?.call(e.toString());
    }
  }

  Future<void> _toggleCamera() async {
    final newCameraType = _currentCameraType == 'front' ? 'back' : 'front';

    try {
      await FlutterIvsStage.toggleCamera(newCameraType);
      setState(() {
        _currentCameraType = newCameraType;
      });
      widget.onCameraChanged?.call(newCameraType);
    } catch (e) {
      widget.onError?.call('Failed to toggle camera: $e');
    }
  }

  Future<void> _stopPreview() async {
    if (_isPreviewActive) {
      try {
        await FlutterIvsStage.stopPreview();
        setState(() {
          _isPreviewActive = false;
        });
      } catch (e) {
        widget.onError?.call('Failed to stop preview: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Stack(
          children: [
            // Main preview area
            Positioned.fill(child: _buildPreviewArea()),

            // Camera controls overlay
            if (widget.showControls && _isPreviewActive)
              _buildControlsOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewArea() {
    if (_isInitializing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (!_isPreviewActive) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt,
              size: 64,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Camera preview not available',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _initializePreview, child: Text('Retry')),
          ],
        ),
      );
    }

    // The actual camera preview will be rendered by the native platform view
    // This is handled automatically when initPreview is called
    return Center(
      child: Text(
        'Camera Preview Active',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.8),
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: _currentCameraType == 'front'
                ? Icons.camera_front
                : Icons.camera_rear,
            label: _currentCameraType == 'front' ? 'Front' : 'Back',
            onPressed: _toggleCamera,
          ),
          _buildControlButton(
            icon: Icons.flip_camera_ios,
            label: 'Flip',
            onPressed: _toggleCamera,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stopPreview();
    super.dispose();
  }
}
