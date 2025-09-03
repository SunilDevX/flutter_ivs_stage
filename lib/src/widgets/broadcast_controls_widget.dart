import 'package:flutter/material.dart';

import '../../flutter_ivs_stage.dart';

/// Widget for broadcast controls
class BroadcastControlsWidget extends StatefulWidget {
  final bool isBroadcasting;
  final String? streamKey;
  final String? streamUrl;

  const BroadcastControlsWidget({
    super.key,
    required this.isBroadcasting,
    this.streamKey,
    this.streamUrl,
  });

  @override
  State<BroadcastControlsWidget> createState() =>
      _BroadcastControlsWidgetState();
}

class _BroadcastControlsWidgetState extends State<BroadcastControlsWidget> {
  late TextEditingController _endpointController;
  late TextEditingController _streamKeyController;
  bool _showSetup = false;
  bool _isSettingUp = false;

  @override
  void initState() {
    super.initState();
    _endpointController = TextEditingController(text: widget.streamUrl);
    _streamKeyController = TextEditingController(text: widget.streamKey);
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _streamKeyController.dispose();
    super.dispose();
  }

  Future<void> _toggleBroadcast() async {
    if (widget.isBroadcasting) {
      // Stop broadcasting
      await FlutterIvsStage.toggleBroadcasting();
    } else {
      // Show setup if not shown yet
      setState(() {
        _showSetup = !_showSetup;
      });
    }
  }

  Future<void> _startBroadcast() async {
    final endpoint = _endpointController.text.trim();
    final streamKey = _streamKeyController.text.trim();

    if (endpoint.isEmpty || streamKey.isEmpty) {
      _showError('Please enter both endpoint and stream key');
      return;
    }

    setState(() {
      _isSettingUp = true;
    });

    try {
      final success = await FlutterIvsStage.setBroadcastAuth(
        endpoint,
        streamKey,
      );
      if (success) {
        await FlutterIvsStage.toggleBroadcasting();
        setState(() {
          _showSetup = false;
        });
      } else {
        _showError('Invalid endpoint or stream key');
      }
    } catch (e) {
      _showError('Failed to start broadcast: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSettingUp = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Broadcast button
        ElevatedButton.icon(
          onPressed: _toggleBroadcast,
          icon: Icon(
            widget.isBroadcasting
                ? Icons.stop_circle
                : Icons.broadcast_on_personal,
            size: 20,
          ),
          label: Text(
            widget.isBroadcasting ? 'Stop Broadcast' : 'Start Broadcast',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isBroadcasting ? Colors.red : Colors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),

        // Setup controls
        if (_showSetup) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[600]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Broadcast Setup',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Endpoint field
                TextField(
                  controller: _endpointController,
                  decoration: InputDecoration(
                    labelText: 'RTMP Endpoint',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    hintText: 'rtmp://your-endpoint.com/live',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    filled: true,
                    fillColor: Colors.grey[700],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),

                // Stream key field
                TextField(
                  controller: _streamKeyController,
                  decoration: InputDecoration(
                    labelText: 'Stream Key',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    hintText: 'Your stream key',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    filled: true,
                    fillColor: Colors.grey[700],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  obscureText: true,
                ),
                const SizedBox(height: 12),

                // Start button
                ElevatedButton(
                  onPressed: _isSettingUp ? null : _startBroadcast,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSettingUp
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Start Streaming',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
