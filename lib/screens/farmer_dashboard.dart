import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';
import '../app_theme.dart';
import '../models/camera_model.dart';
import '../services/dashboard_service.dart';
import '../services/camera_service.dart';
import '../services/notification_service.dart';
import '../services/socket_service.dart';
import 'detection_screen.dart';
import 'change_password_screen.dart';
import 'update_profile_screen.dart';
import 'analytics_screen.dart';
import 'notification_settings_screen.dart';
import 'camera_details_screen.dart';
import 'farmer_chat_screen.dart'; // Add Chat Screen
import 'farmer_notifications_screen.dart';
import '../widgets/weather_widget.dart';
import '../widgets/dashboard_camera_card.dart';

class FarmerDashboard extends StatefulWidget {
  final String deviceId;

  const FarmerDashboard({super.key, required this.deviceId});

  @override
  State<FarmerDashboard> createState() => _FarmerDashboardState();
}

class _FarmerDashboardState extends State<FarmerDashboard> {
  int selectedIndex = 0;
  int unreadCount = 0;
  int unreadMessageCount = 0;

  // Dashboard data
  DashboardStats? dashboardStats;
  List<CameraDevice> cameras = [];
  bool isDashboardLoading = true;
  String? dashboardError;

  // Profile data
  bool isProfileLoading = true;

  final socketService = SocketService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _loadNotificationCount();
    _initSocket();
  }

  Future<void> _loadDashboardData() async {
    try {
      setState(() {
        isDashboardLoading = true;
        dashboardError = null;
      });

      final results = await Future.wait([
        DashboardService.getStats(widget.deviceId),
        CameraService.getCameras(widget.deviceId),
      ]);

      if (mounted) {
        setState(() {
          dashboardStats = results[0] as DashboardStats;
          cameras = results[1] as List<CameraDevice>;
          isDashboardLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          dashboardError = e.toString();
          isDashboardLoading = false;
        });
      }
    }
  }

  Future<void> _loadNotificationCount() async {
    try {
      final count =
          await NotificationService.getUnreadCount(widget.deviceId);
      if (mounted) {
        setState(() => unreadCount = count);
      }
    } catch (_) {}
  }

  void _initSocket() {
    socketService.connect();

    socketService.onReconnect = () {
      _loadNotificationCount();
      _loadDashboardData();
    };

    // Listen for new detections
    socketService.listen("new_detection", (data) {
      // Play alert sound
      _playAlertSound();
      
      if (mounted && selectedIndex != 1) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Row(
               children: [
                 const Icon(Icons.warning_amber_rounded, color: Colors.white),
                 const SizedBox(width: 8),
                 Text("New Alert Detected!", style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
               ],
             ),
             backgroundColor: AppColors.danger,
             behavior: SnackBarBehavior.floating,
             margin: const EdgeInsets.all(16),
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
             action: SnackBarAction(
               label: "VIEW",
               textColor: Colors.white,
               onPressed: () {
                 setState(() => selectedIndex = 1);
               },
             ),
           ),
         );
      }
    });

    // Listen for new notifications
    socketService.listen("new_notification", (data) {
      if (mounted) {
        setState(() => unreadCount++);
      }
    });

    // Listen for camera status changes
    socketService.listen("camera_status_change", (data) {
      if (mounted) {
        _loadDashboardData();
      }
    });

    // Listen for monitoring changes
    socketService.listen("monitoring_changed", (data) {
      if (mounted) {
        if (data['deviceId'] == widget.deviceId) {
          final enabled = data['enabled'] ?? true;
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: Text(enabled ? "Officer enabled active monitoring" : "Officer paused monitoring"),
               backgroundColor: enabled ? Colors.green : Colors.orange,
             ),
          );
          _loadDashboardData();
        }
      }
    });

    // Listen for new messages
    socketService.listen("new_message", (data) {
       if (mounted && selectedIndex != 3) {
          setState(() => unreadMessageCount++);
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: Row(
                 children: [
                   const Icon(Icons.message_rounded, color: Colors.white),
                   const SizedBox(width: 8),
                   Text("New message from Officer", style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                 ],
               ),
               backgroundColor: Colors.blue,
               behavior: SnackBarBehavior.floating,
               margin: const EdgeInsets.all(16),
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
               action: SnackBarAction(
                 label: "VIEW",
                 textColor: Colors.white,
                 onPressed: () {
                   setState(() {
                     selectedIndex = 3;
                     unreadMessageCount = 0;
                   });
                 },
               ),
             ),
          );
       } else if (mounted && selectedIndex == 3) {
         // Already on Chat tab — just refresh, no badge
       }
    });
  }

  void _playAlertSound() {
    try {
      _audioPlayer.stop();
      _audioPlayer.setVolume(1.0);
      _audioPlayer.play(AssetSource('sounds/alert.wav'));
    } catch (e) {
      debugPrint("Alert sound error: $e");
    }
  }

  @override
  void dispose() {
    socketService.disconnect();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titles = ["Dashboard", "Alerts", "Analytics", "Chat", "Profile", "Notifications"];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? AppColors.surfaceDark : Colors.white;
    final selectedColor = AppColors.getPrimary(Theme.of(context).brightness);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(titles[selectedIndex < titles.length ? selectedIndex : 0]),
        actions: [
          _buildNotificationBell(),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: selectedIndex == 0
            ? _buildHome()
            : selectedIndex == 1
                ? _buildAlerts()
                : selectedIndex == 2
                    ? _buildAnalytics()
                    : selectedIndex == 3
                        ? _buildChat()
                        : selectedIndex == 4
                            ? _buildMenu()
                            : FarmerNotificationsScreen(deviceId: widget.deviceId),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(Icons.dashboard_rounded, "Dashboard", 0, selectedColor),
                _navItem(Icons.radar_rounded, "Alerts", 1, selectedColor),
                _navItem(Icons.bar_chart_rounded, "Analytics", 2, selectedColor),
                _navItemWithBadge(Icons.chat_bubble_rounded, "Chat", 3, selectedColor, unreadMessageCount),
                _navItem(Icons.person_rounded, "Profile", 4, selectedColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationBell() {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, size: 28),
            onPressed: () {
              setState(() {
                selectedIndex = 5; // Route to Notifications tab instead of Chat
                unreadCount = 0;
              });
            },
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(
                  begin: -1,
                  end: 1,
                  duration: 2000.ms,
                  curve: Curves.easeInOut),
          if (unreadCount > 0)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  unreadCount > 99 ? "99+" : unreadCount.toString(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Nav item without badge
  Widget _navItem(IconData icon, String label, int index, Color selectedColor) {
    return _navItemWithBadge(icon, label, index, selectedColor, 0);
  }

  /// Nav item with optional unread badge
  Widget _navItemWithBadge(
      IconData icon, String label, int index, Color selectedColor, int badge) {
    final isSelected = selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedIndex = index;
          // Clear badge when tapping
          if (index == 3) unreadMessageCount = 0;
        });
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: EdgeInsets.symmetric(
              horizontal: isSelected ? 20 : 16,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isSelected ? selectedColor : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isSelected
                      ? Colors.white
                      : (isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Unread badge dot
          if (badge > 0)
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    badge > 9 ? '9+' : badge.toString(),
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }


  // ═══════════════════════════════════════
  // HOME TAB (DASHBOARD)
  // ═══════════════════════════════════════

  Widget _buildHome() {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: AppColors.primary,
      child: SingleChildScrollView(
        key: const ValueKey("home"),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
              decoration: const BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "EcoWatch",
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        _buildStatusBadge(),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Text(
                      "Device: ${widget.deviceId}",
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Quick Stats Row ──
                    isDashboardLoading
                        ? _buildStatsSkeletonRow()
                        : dashboardError != null
                            ? _buildStatsErrorRow()
                            : Row(
                                children: [
                                  _statChip(
                                    Icons.videocam_rounded,
                                    "${dashboardStats?.activeCameras ?? 0}/${dashboardStats?.cameraCount ?? 0}",
                                    "Cameras",
                                  ),
                                  const SizedBox(width: 12),
                                  _statChip(
                                    Icons.warning_amber_rounded,
                                    dashboardStats?.lastDetectedAnimal ??
                                        "None",
                                    "Last Alert",
                                  ),
                                  const SizedBox(width: 12),
                                  _statChip(
                                    Icons.timer_rounded,
                                    dashboardStats?.systemUptime ?? "0h",
                                    "Uptime",
                                  ),
                                ],
                              ),
                  ],
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: -0.05, end: 0, duration: 400.ms),

            const SizedBox(height: 12),
            
            // ── Live Weather Widget ──
            WeatherWidget(deviceId: widget.deviceId)
                .animate()
                .fadeIn(delay: 200.ms, duration: 400.ms)
                .slideY(begin: 0.1, end: 0, delay: 200.ms, duration: 400.ms),

            const SizedBox(height: 12),

            // ── Section Title ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                "Live Camera Feeds",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextPrimary(Theme.of(context).brightness),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Camera Cards ──
            if (isDashboardLoading) ...[
              _buildCameraCardSkeleton(),
              _buildCameraCardSkeleton(),
            ] else if (dashboardError != null)
              _buildCameraErrorState()
            else if (cameras.isEmpty)
              _buildCameraEmptyState()
            else
              ...cameras.asMap().entries.map((entry) {
                final cam = entry.value;
                return _buildCameraCard(
                  cam.name,
                  cam.location.isNotEmpty ? cam.location : "Zone ${entry.key + 1}",
                  entry.key,
                  cam.isConnected ? "connected" : "disconnected",
                  cam.streamUrl,
                );
              }),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    final isOnline = dashboardStats?.systemStatus != null &&
        dashboardStats!.systemStatus.toLowerCase() != "offline";
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Status: ",
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isOnline ? AppColors.success : AppColors.textTertiary,
              shape: BoxShape.circle,
            ),
          )
              .animate(
                onPlay: (c) => c.repeat(reverse: true),
              )
              .fadeIn(duration: 1000.ms)
              .then()
              .fadeOut(duration: 1000.ms),
          const SizedBox(width: 6),
          Text(
            isOnline ? "Online" : "Offline",
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSkeletonRow() {
    return Row(
      children: [
        Expanded(child: _skeletonChip()),
        const SizedBox(width: 12),
        Expanded(child: _skeletonChip()),
        const SizedBox(width: 12),
        Expanded(child: _skeletonChip()),
      ],
    );
  }

  Widget _skeletonChip() {
    return Container(
      height: 86,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1200.ms, color: Colors.white24);
  }

  Widget _buildStatsErrorRow() {
    return GestureDetector(
      onTap: _loadDashboardData,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.refresh_rounded,
                color: Colors.white.withOpacity(0.8), size: 20),
            const SizedBox(width: 8),
            Text(
              "Tap to retry",
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.8), size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.white.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraCardSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(16),
        ),
      )
          .animate(onPlay: (c) => c.repeat())
          .shimmer(duration: 1200.ms, color: Colors.white10),
    );
  }

  Widget _buildCameraEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.getCard(Theme.of(context).brightness),
          borderRadius: BorderRadius.circular(20),
          border: isDark ? null : Border.all(color: const Color(0xFFD6EDDE)),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : const Color(0xFF1E7A48).withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.videocam_off_rounded,
              size: 48,
              color: AppColors.getTextTertiary(Theme.of(context).brightness).withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              "No Cameras Registered",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextPrimary(Theme.of(context).brightness),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Add cameras via the admin panel\nto start monitoring.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.getTextSecondary(Theme.of(context).brightness),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraErrorState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: GestureDetector(
        onTap: _loadDashboardData,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.getCard(Theme.of(context).brightness),
            borderRadius: BorderRadius.circular(20),
            border: isDark ? null : Border.all(color: const Color(0xFFD6EDDE)),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.3)
                    : const Color(0xFF1E7A48).withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.danger,
              ),
              const SizedBox(height: 16),
              Text(
                "Failed to load cameras",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextPrimary(Theme.of(context).brightness),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Tap to retry",
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraCard(
      String title, String subtitle, int index, String status, String streamUrl) {
    if (index >= cameras.length) return const SizedBox.shrink();
    return DashboardCameraCard(
      camera: cameras[index],
      deviceId: widget.deviceId,
      index: index,
    );
  }

  // ═══════════════════════════════════════
  // DETECTIONS TAB
  // ═══════════════════════════════════════

  Widget _buildAlerts() {
    return DetectionScreen(
      key: const ValueKey("detections"),
      deviceId: widget.deviceId,
      embedded: true,
    );
  }

  // ═══════════════════════════════════════
  // ANALYTICS TAB
  // ═══════════════════════════════════════

  Widget _buildAnalytics() {
    return AnalyticsScreen(
      key: const ValueKey("analytics"),
      deviceId: widget.deviceId,
    );
  }

  // ═══════════════════════════════════════
  // CHAT TAB
  // ═══════════════════════════════════════

  Widget _buildChat() {
    return FarmerChatScreen(
      key: const ValueKey("chat"),
      deviceId: widget.deviceId,
    );
  }

  // ═══════════════════════════════════════
  // MENU / PROFILE TAB
  // ═══════════════════════════════════════

  Widget _buildMenu() {
    return SingleChildScrollView(
      key: const ValueKey("menu"),
      child: Column(
        children: [
          // ── Profile Header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
            decoration: const BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(32),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.deviceId,
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "Farmer",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Device Status Card (API-driven) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.getCard(Theme.of(context).brightness),
                borderRadius: BorderRadius.circular(16),
                border: Theme.of(context).brightness == Brightness.light
                    ? Border.all(color: const Color(0xFFD6EDDE))
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black.withOpacity(0.3)
                        : const Color(0xFF1E7A48).withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Device Information",
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  _deviceInfoRow("Device ID", widget.deviceId),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("System Status",
                          style: GoogleFonts.inter(
                              color: AppColors.getTextSecondary(Theme.of(context).brightness), fontSize: 13)),
                      Row(
                        children: [
                          Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: dashboardStats != null
                                      ? AppColors.success
                                      : AppColors.textTertiary,
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text(
                              dashboardStats?.systemStatus ?? "Loading...",
                              style: GoogleFonts.inter(
                                  color: AppColors.getTextPrimary(Theme.of(context).brightness),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _deviceInfoRow(
                    "Cameras",
                    dashboardStats != null
                        ? "${dashboardStats!.activeCameras}/${dashboardStats!.cameraCount} connected"
                        : "Loading...",
                  ),
                  const SizedBox(height: 12),
                  _deviceInfoRow(
                    "Last Sync",
                    dashboardStats != null
                        ? _formatLastSync(dashboardStats!.lastSyncTime)
                        : "Loading...",
                  ),
                ],
              ),
            ),
          )
              .animate()
              .fadeIn(delay: 100.ms, duration: 400.ms)
              .slideY(begin: 0.05, end: 0, delay: 100.ms, duration: 400.ms),

          const SizedBox(height: 16),

          // ── Menu Items ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.getCard(Theme.of(context).brightness),
                borderRadius: BorderRadius.circular(16),
                border: Theme.of(context).brightness == Brightness.light
                    ? Border.all(color: const Color(0xFFD6EDDE))
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black.withOpacity(0.3)
                        : const Color(0xFF1E7A48).withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _menuItem(
                    icon: Icons.person_outline_rounded,
                    title: "Update Profile",
                    subtitle: "Edit your personal information",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UpdateProfileScreen(
                            deviceId: widget.deviceId,
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 72),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: appThemeMode,
                    builder: (context, theme, child) {
                      final isDark = theme == ThemeMode.dark;
                      return SwitchListTile(
                        value: isDark,
                        onChanged: (value) {
                          appThemeMode.value =
                              value ? ThemeMode.dark : ThemeMode.light;
                        },
                        activeColor: AppColors.getPrimaryLight(Theme.of(context).brightness),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 4),
                        title: Text(
                          "Dark Mode",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          "Toggle premium dark theme",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        secondary: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.getPrimary(Theme.of(context).brightness).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isDark
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            color: AppColors.getPrimary(Theme.of(context).brightness),
                            size: 22,
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 72),
                  _menuItem(
                    icon: Icons.lock_outline_rounded,
                    title: "Change Password",
                    subtitle: "Update your security credentials",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChangePasswordScreen(
                            deviceId: widget.deviceId,
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 72),
                  _menuItem(
                    icon: Icons.notifications_active_outlined,
                    title: "Notification Sound",
                    subtitle: "Change alert tone",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const NotificationSettingsScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 72),
                  _menuItem(
                    icon: Icons.shield_rounded,
                    title: "Privacy Policy",
                    subtitle: "Read our data policy",
                    onTap: _showPrivacyPolicy,
                  ),
                  const Divider(height: 1, indent: 72),
                  _menuItem(
                    icon: Icons.info_outline_rounded,
                    title: "About EcoWatch",
                    subtitle: "Version 1.0.0",
                    onTap: _showAboutApp,
                  ),
                ],
              ),
            ),
          )
              .animate()
              .fadeIn(delay: 200.ms, duration: 400.ms)
              .slideY(begin: 0.05, end: 0, delay: 200.ms, duration: 400.ms),

          const SizedBox(height: 16),

          // ── Logout ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: _menuItem(
                icon: Icons.logout_rounded,
                title: "Logout",
                subtitle: "Sign out of your account",
                isDanger: true,
                onTap: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                },
              ),
            ),
          )
              .animate()
              .fadeIn(delay: 350.ms, duration: 400.ms),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  String _formatLastSync(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return "Just now";
      if (diff.inMinutes < 60) return "${diff.inMinutes} minutes ago";
      if (diff.inHours < 24) return "${diff.inHours} hours ago";
      return "${diff.inDays} days ago";
    } catch (_) {
      return timestamp == "Never" ? "Never" : "Unknown";
    }
  }

  Widget _deviceInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                color: AppColors.getTextSecondary(Theme.of(context).brightness), fontSize: 13)),
        Flexible(
          child: Text(value,
              style: GoogleFonts.inter(
                  color: AppColors.getTextPrimary(Theme.of(context).brightness),
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
              textAlign: TextAlign.right),
        ),
      ],
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDanger
        ? AppColors.danger
        : AppColors.getTextPrimary(Theme.of(context).brightness);
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDanger
              ? AppColors.danger.withOpacity(0.1)
              : AppColors.getPrimary(Theme.of(context).brightness).withOpacity(isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon,
            color: isDanger
                ? AppColors.danger
                : AppColors.getPrimary(Theme.of(context).brightness),
            size: 22),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: isDanger
              ? AppColors.danger.withOpacity(0.8)
              : AppColors.getTextSecondary(Theme.of(context).brightness),
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: isDanger
            ? AppColors.danger
            : AppColors.getTextTertiary(Theme.of(context).brightness),
      ),
      onTap: onTap,
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCard(Theme.of(context).brightness),
        title: Text("Privacy Policy",
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(Theme.of(context).brightness))),
        content: SingleChildScrollView(
          child: Text(
            "EcoWatch is committed to protecting your privacy.\n\n"
            "Data Collection:\n"
            "We collect device data, ML detection images, and system status logs to provide the core wildlife monitoring service.\n\n"
            "Data Usage:\n"
            "Your data is used strictly for analytics, notifications, and dashboard stats related to your farm. It is not sold to third parties.\n\n"
            "Security:\n"
            "We use enterprise-grade encryption for passwords and transmit live feeds securely.",
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.getTextSecondary(Theme.of(context).brightness), height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close", style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showAboutApp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCard(Theme.of(context).brightness),
        title: Row(
          children: [
            Icon(Icons.eco_rounded, color: AppColors.getPrimary(Theme.of(context).brightness), size: 28),
            const SizedBox(width: 8),
            Text("EcoWatch",
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(Theme.of(context).brightness))),
          ],
        ),
        content: Text(
          "Version 1.0.0\n\nEcoWatch is an intelligent ecosystem surveillance system designed to "
          "help farmers monitor wildlife, track detections, and secure agricultural areas using AI cameras and real-time connectivity.",
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.getTextSecondary(Theme.of(context).brightness), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close", style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}