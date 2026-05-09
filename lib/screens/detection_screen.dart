import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app_theme.dart';
import '../models/detection_model.dart';
import '../services/detection_service.dart';
import '../services/socket_service.dart';
import '../config/api_config.dart';

class DetectionScreen extends StatefulWidget {
  final String deviceId;
  final bool embedded;

  const DetectionScreen({
    super.key,
    required this.deviceId,
    this.embedded = false,
  });

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  List<Detection> detections = [];
  bool loading = true;

  String? currentSort = "newest";
  String? filterRisk;
  String? filterAnimal;

  final socketService = SocketService();
  final String serverUrl = ApiConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    loadDetections();
    socketService.connect();
    socketService.listen("new_detection", (data) {
      final newDetection = Detection.fromJson(data);
      if (newDetection.deviceId == widget.deviceId) {
        setState(() {
          detections.insert(0, newDetection);
        });
      }
    });
  }

  Future<void> loadDetections() async {
    try {
      if (!mounted) return;
      setState(() => loading = true);
      final result = await DetectionService.fetchDetections(
        widget.deviceId,
        sort: currentSort,
        filterRisk: filterRisk,
        filterAnimal: filterAnimal,
      );
      if (!mounted) return;
      setState(() {
        detections = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> _deleteDetection(String id) async {
    final success = await DetectionService.deleteDetection(id);
    if (success) {
      setState(() {
        detections.removeWhere((d) => d.id == id);
      });
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to delete detection")),
      );
    }
  }

  Future<void> _deleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Delete All Alerts?", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text("Are you sure you want to remove ALL alerts? This action cannot be undone.", style: GoogleFonts.inter()),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel", style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("Delete All", style: GoogleFonts.inter(color: AppColors.danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => loading = true);
      try {
        for (var d in detections.toList()) {
          await DetectionService.deleteDetection(d.id);
        }
        setState(() {
          detections.clear();
          loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All alerts deleted successfully")),
        );
      } catch (e) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to delete some alerts")),
        );
      }
    }
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Filter", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 20),

                Text("Risk Level", style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    _filterChip("All", filterRisk == null, () => setModalState(() => filterRisk = null)),
                    _filterChip("High 🔴", filterRisk == "high", () => setModalState(() => filterRisk = "high")),
                    _filterChip("Medium 🟡", filterRisk == "medium", () => setModalState(() => filterRisk = "medium")),
                    _filterChip("Low 🟢", filterRisk == "low", () => setModalState(() => filterRisk = "low")),
                  ],
                ),

                const SizedBox(height: 8),
                Text(
                  "High: Elephant, Tiger, Leopard  •  Medium: Bear, Boar, Monkey  •  Low: Person, Cat, Deer, Dog",
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textTertiary),
                ),

                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      loadDetections();
                    },
                    child: Text("Apply Filter", style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _filterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    socketService.disconnect();
    super.dispose();
  }

  /// Classify risk based on animal name (matches backend logic)
  Map<String, dynamic> _classifyRisk(String animal) {
    final a = animal.toUpperCase();
    if (['ELEPHANT', 'TIGER', 'LEOPARD'].contains(a)) {
      return {'color': AppColors.danger, 'label': 'High Risk'};
    } else if (['BEAR', 'BOAR', 'MONKEY', 'WILD BOAR'].contains(a)) {
      return {'color': AppColors.warning, 'label': 'Medium Risk'};
    } else {
      return {'color': const Color(0xFF4ADE80), 'label': 'Low Risk'};
    }
  }

  /// Status color for officer response
  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'investigating':
        return const Color(0xFF60A5FA);
      case 'resolved':
        return const Color(0xFF4ADE80);
      case 'pending':
      default:
        return const Color(0xFFFFB347);
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'investigating':
        return Icons.manage_search_rounded;
      case 'resolved':
        return Icons.task_alt_rounded;
      case 'pending':
      default:
        return Icons.hourglass_empty_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // ── Header ──
          if (!widget.embedded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
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
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Alerts",
                                style: GoogleFonts.poppins(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                "${detections.length} total alerts detected",
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (detections.isNotEmpty)
                          GestureDetector(
                            onTap: _deleteAll,
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.delete_sweep_rounded,
                                color: AppColors.danger,
                                size: 22,
                              ),
                            ),
                          ),
                        GestureDetector(
                          onTap: _showFilterOptions,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.filter_list_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Embedded header — single count line only
          if (widget.embedded)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "${detections.length} total alerts detected",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (detections.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.danger),
                      onPressed: _deleteAll,
                    ),
                  IconButton(
                    icon: const Icon(Icons.filter_list_rounded, color: AppColors.textSecondary),
                    onPressed: _showFilterOptions,
                  ),
                ],
              ),
            ),

          // ── Body ──
          Expanded(
            child: loading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Loading alerts...",
                          style: GoogleFonts.inter(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  )
                : detections.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: loadDetections,
                        color: AppColors.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                          itemCount: detections.length,
                          itemBuilder: (context, index) {
                            final d = detections[index];
                            return _buildDetectionCard(d, index);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "All Clear!",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "No wildlife alerts recorded yet.\nYour farm is secure.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionCard(Detection d, int index) {
    final String imageUrl;
    if (d.imageUrl.startsWith('http')) {
      imageUrl = d.imageUrl;
    } else {
      final filename = d.imageUrl.split('/').last;
      imageUrl = "$serverUrl/api/images/$filename";
    }

    final confidencePercent = (d.confidence * 100).toStringAsFixed(0);
    final animalUpper = d.animal.toUpperCase();

    final risk = _classifyRisk(d.animal);
    final Color riskColor = risk['color'] as Color;
    final String riskLabel = risk['label'] as String;

    final statusColor = _statusColor(d.status);
    final statusIcon = _statusIcon(d.status);

    // Swipe right to delete
    return Dismissible(
      key: Key(d.id),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text("Delete Alert?", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            content: Text("Swipe to permanently delete this alert. This cannot be undone.", style: GoogleFonts.inter()),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text("Cancel", style: GoogleFonts.inter(color: AppColors.textSecondary)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text("Delete", style: GoogleFonts.inter(color: AppColors.danger, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        _deleteDetection(d.id);
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 28),
            const SizedBox(width: 8),
            Text("Delete", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: () {
          _showImageDialog(imageUrl, animalUpper, riskColor);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Detection Image with overlay ──
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: Image.network(
                      imageUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      headers: {"device-id": widget.deviceId},
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported_rounded,
                              size: 48,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Gradient overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                          stops: const [0.4, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Risk badge top-right
                  Positioned(
                    top: 14,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: riskColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: riskColor.withOpacity(0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        riskLabel,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  // Swipe hint badge top-left
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.swipe_right_rounded, color: Colors.white60, size: 12),
                          const SizedBox(width: 4),
                          Text("Swipe to delete", style: GoogleFonts.inter(color: Colors.white60, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),

                  // Animal name overlay
                  Positioned(
                    bottom: 14,
                    left: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          animalUpper,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          "Confidence: $confidencePercent%",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // ── Officer Response Section ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timestamp row
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 13, color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Text(
                          _formatTime(d.timestamp),
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textTertiary),
                        ),
                        const Spacer(),
                        // Camera info (location only, no device ID or ML chip)
                        Text(
                          "Camera: Crop Field",
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textTertiary),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Officer Response Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(statusIcon, size: 15, color: statusColor),
                              const SizedBox(width: 6),
                              Text(
                                "Officer Response",
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  d.status,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (d.officerNote != null && d.officerNote!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              d.officerNote!,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 6),
                            Text(
                              d.status.toLowerCase() == 'pending'
                                  ? "Awaiting officer review..."
                                  : "No additional notes.",
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(delay: (index * 100).ms, duration: 400.ms)
            .slideY(
              begin: 0.08,
              end: 0,
              delay: (index * 100).ms,
              duration: 400.ms,
              curve: Curves.easeOut,
            ),
      ),
    );
  }

  void _showImageDialog(String imageUrl, String animal, Color riskColor) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                headers: {"device-id": widget.deviceId},
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        color: Colors.white70,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.image_not_supported_rounded,
                          size: 52,
                          color: Colors.white38,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Image Unavailable",
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: riskColor,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                "$animal DETECTED",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 16),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      final day = dt.day;
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final mon = months[dt.month - 1];
      return "$day $mon · $h:$m";
    } catch (_) {
      return timestamp;
    }
  }
}