import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../app_theme.dart';
import '../models/camera_model.dart';
import '../services/camera_service.dart';
import 'detection_screen.dart';

class CameraDetailsScreen extends StatefulWidget {
  final CameraDevice camera;
  final String deviceId;

  const CameraDetailsScreen({
    super.key,
    required this.camera,
    required this.deviceId,
  });

  @override
  State<CameraDetailsScreen> createState() =>
      _CameraDetailsScreenState();
}

class _CameraDetailsScreenState extends State<CameraDetailsScreen> {
  bool isNightVision = false;
  bool isRecording = false;

  RTCPeerConnection? _pc;
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  MediaRecorder? _mediaRecorder;
  String? _videoFilePath;

  @override
  void initState() {
    super.initState();
    initStream();
  }

  Future<void> initStream() async {
    print("===== INIT WEBRTC STREAM START =====");
    await _renderer.initialize();

    /// 🔥 FIX 1: ADD TURN SERVER
    _pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {
          'urls': 'turn:openrelay.metered.ca:80',
          'username': 'openrelayproject',
          'credential': 'openrelayproject'
        },
        {
          'urls': 'turn:openrelay.metered.ca:443',
          'username': 'openrelayproject',
          'credential': 'openrelayproject'
        }
      ]
    });
    print("[WebRTC] PeerConnection created");

    _pc!.onConnectionState = (state) {
      print("[WebRTC] ConnectionState changed to: $state");
    };

    _pc!.onIceConnectionState = (state) {
      print("[WebRTC] ICE ConnectionState changed to: $state");
    };

    _pc!.onIceGatheringState = (state) {
      print("[WebRTC] ICE GatheringState changed to: $state");
    };

    _pc!.onSignalingState = (state) {
      print("[WebRTC] SignalingState changed to: $state");
    };

    /// 🔥 FIX 2: BETTER TRACK HANDLING
    _pc!.onTrack = (event) {
      print("[WebRTC] Track received: kind=${event.track.kind}, id=${event.track.id}");
      if (event.streams.isNotEmpty) {
        print("[WebRTC] Event has streams, attaching to renderer");
        _renderer.srcObject = event.streams[0];
      } else {
        print("[WebRTC] No stream ID found, creating local stream fallback");
        if (_renderer.srcObject == null) {
          createLocalMediaStream('remote_stream').then((stream) {
            stream.addTrack(event.track);
            _renderer.srcObject = stream;
            setState(() {});
          });
        } else {
          _renderer.srcObject!.addTrack(event.track);
        }
      }
      setState(() {});
    };

    try {
      final streamUrl = CameraService.getStreamUrl(widget.deviceId);
      print("[WebRTC] Final Stream URL: $streamUrl");

      // Request video and audio tracks from the WHEP server
      print("[WebRTC] Adding receive-only Video Transceiver");
      await _pc!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );

      try {
        print("[WebRTC] Adding receive-only Audio Transceiver");
        await _pc!.addTransceiver(
          kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
          init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
        );
      } catch (e) {
        print("[WebRTC] Audio transceiver error: $e");
      }

      print("[WebRTC] Creating SDP Offer...");
      var offer = await _pc!.createOffer();
      print("[WebRTC] Offer created. Length: ${offer.sdp?.length}");
      await _pc!.setLocalDescription(offer);
      print("[WebRTC] Local description set.");

      print("[HTTP] Sending POST to WHEP URL...");
      final res = await http.post(
        Uri.parse(streamUrl),
        headers: {
          "Content-Type": "application/sdp",
          "Accept": "application/sdp",
        },
        body: offer.sdp,
      );

      print("[HTTP] Response status: ${res.statusCode}");
      print("[HTTP] Response headers: ${res.headers}");
      print("[HTTP] Response body length: ${res.body.length}");
      print("[HTTP] Response body snippet: ${res.body.length > 200 ? res.body.substring(0, 200) + '...' : res.body}");

      if (res.statusCode >= 200 && res.statusCode < 300) {
        String sdp = res.body;

        // If Mediamtx or Cloudflare WHEP returns a Link header for patch,
        // or just relies on the SDP response body.

        // Some servers wrap the SDP in JSON, but standard WHEP usually returns raw SDP.
        // We will assume WHEP raw SDP for now.
        print("[WebRTC] Setting Remote Description from Answer...");
        await _pc!.setRemoteDescription(
          RTCSessionDescription(sdp, "answer"),
        );
        print("[WebRTC] Remote description successfully set!");
      } else {
        print("[WebRTC] ERROR: Status code was not 200-299. Did the POST fail?");
      }
    } catch (e, stackTrace) {
      print("[WebRTC] FATAL ERROR: $e");
      print("[WebRTC] Stack trace: $stackTrace");
    }
    print("===== INIT WEBRTC STREAM END =====");
  }

  @override
  void dispose() {
    _mediaRecorder?.stop();
    _renderer.dispose();
    _pc?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isOffline = !widget.camera.isConnected;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280.0,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: _buildVideoPlayer(isOffline),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.camera.name,
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.getTextPrimary(
                                  Theme.of(context).brightness),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Location: ${widget.camera.location}",
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.getTextSecondary(
                                  Theme.of(context).brightness),
                            ),
                          ),
                        ],
                      ),
                      _buildStatusBadge(isOffline),
                    ],
                  ),

                  const SizedBox(height: 32),

                  const SizedBox(height: 32),

                  if (!isOffline) _buildQuickActions(),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🎥 VIDEO PLAYER
  Widget _buildVideoPlayer(bool isOffline) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black),

        if (isOffline)
          Center(
            child: Column(
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                const Icon(Icons.videocam_off_rounded,
                    color: Colors.white54, size: 64),
                const SizedBox(height: 16),
                Text(
                  "Camera Offline",
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        else
          _renderer.srcObject != null
              ? RTCVideoView(
            _renderer,
            objectFit:
            RTCVideoViewObjectFit
                .RTCVideoViewObjectFitCover,
          )
              : const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          ),

        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.5),
                Colors.transparent,
                Colors.black.withOpacity(0.8),
              ],
            ),
          ),
        ),

        if (!isOffline)
          Positioned(
            top: 60,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  )
                      .animate(onPlay: (c) =>
                      c.repeat(reverse: true))
                      .fadeIn(duration: 800.ms),
                  const SizedBox(width: 6),
                  Text(
                    "LIVE",
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusBadge(bool isOffline) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isOffline ? Colors.grey : Colors.green,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isOffline ? "Offline" : "Online",
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Quick Actions",
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextPrimary(Theme.of(context).brightness),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _actionButton(
              icon: Icons.camera_alt_rounded,
              label: "Snapshot",
              color: AppColors.accent, // Updated color
              onTap: _takeSnapshot,
            ),
            _actionButton(
              icon: isRecording ? Icons.stop_rounded : Icons.fiber_manual_record_rounded,
              label: isRecording ? "Stop" : "Record",
              color: isRecording ? AppColors.danger : const Color(0xFFFACC15), // Amber color
              onTap: _toggleRecording,
            ),
            _actionButton(
              icon: Icons.fullscreen_rounded,
              label: "Fullscreen",
              color: AppColors.primary, // Updated color
              onTap: _enterFullscreen,
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextSecondary(Theme.of(context).brightness),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _takeSnapshot() async {
    if (_renderer.srcObject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active stream to capture.')),
      );
      return;
    }

    try {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final request = await Gal.requestAccess(toAlbum: true);
        if (!request) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission to save to gallery denied.')),
          );
          return;
        }
      }

      final videoTrack = _renderer.srcObject!.getVideoTracks().firstOrNull;
      if (videoTrack == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No video track found.')),
        );
        return;
      }

      final buffer = await videoTrack.captureFrame();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/snapshot_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(buffer.asUint8List());

      await Gal.putImage(file.path, album: 'EcoWatch');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Snapshot saved to gallery!')),
      );
    } catch (e) {
      print("Snapshot error: \$e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save snapshot.')),
      );
    }
  }

  Future<void> _toggleRecording() async {
    if (_renderer.srcObject == null || _renderer.srcObject!.getVideoTracks().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active stream to record.')),
      );
      return;
    }

    try {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final request = await Gal.requestAccess(toAlbum: true);
        if (!request) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission to save to gallery denied.')),
          );
          return;
        }
      }

      if (isRecording) {
        // Stop recording
        await _mediaRecorder?.stop();
        setState(() {
          isRecording = false;
        });

        if (_videoFilePath != null) {
          final file = File(_videoFilePath!);
          if (await file.exists()) {
            // Give MediaRecorder a moment to finish writing the file to disk
            await Future.delayed(const Duration(milliseconds: 1000));
            try {
              await Gal.putVideo(_videoFilePath!, album: 'EcoWatch');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Recording saved to gallery!')),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error saving video format to gallery.')),
                );
              }
            }
          }
        }
      } else {
        // Start recording
        // Check for microphone permission just in case
        await Permission.microphone.request();

        final dir = await getTemporaryDirectory();
        _videoFilePath = '${dir.path}/record_${DateTime.now().millisecondsSinceEpoch}.mp4';

        _mediaRecorder = MediaRecorder();
        await _mediaRecorder!.start(
          _videoFilePath!,
          videoTrack: _renderer.srcObject!.getVideoTracks().firstOrNull,
        );

        setState(() {
          isRecording = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording started...')),
        );
      }
    } catch (e) {
      print("Recording error: \$e");
      setState(() {
        isRecording = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to record video.')),
      );
    }
  }

  void _enterFullscreen() async {
    if (_renderer.srcObject == null) return;

    // Force landscape mode
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: RTCVideoView(
                  _renderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                ),
              ),
              Positioned(
                top: 20,
                right: 40,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Positioned(
                top: 30,
                left: 40,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(duration: 800.ms),
                      const SizedBox(width: 8),
                      Text("LIVE", style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Restore portrait mode when returning
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
}