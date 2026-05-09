import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app_theme.dart';
import '../models/detection_model.dart';
import '../services/officer_service.dart';
import '../config/api_config.dart';
import 'officer_alert_details_screen.dart';

class OfficerAlertsScreen extends StatefulWidget {
  final String? initialRiskLevel;
  const OfficerAlertsScreen({super.key, this.initialRiskLevel});

  @override
  State<OfficerAlertsScreen> createState() => _OfficerAlertsScreenState();
}

class _OfficerAlertsScreenState extends State<OfficerAlertsScreen> {
  bool isLoading = true;
  List<Detection> alerts = [];
  String? selectedRiskLevel;

  @override
  void initState() {
    super.initState();
    selectedRiskLevel = widget.initialRiskLevel;
    _fetchAlerts();
  }

  Future<void> _fetchAlerts() async {
    setState(() => isLoading = true);
    final data = await OfficerService.getAlerts(riskLevel: selectedRiskLevel);
    if (mounted) {
      setState(() {
        alerts = data;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter Chips Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip("All", null),
                const SizedBox(width: 8),
                _filterChip("High Risk 🔴", "high"),
                const SizedBox(width: 8),
                _filterChip("Medium 🟡", "medium"),
                const SizedBox(width: 8),
                _filterChip("Low 🟢", "low"),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.file_download_outlined,
                      color: Colors.blue),
                  tooltip: 'Export Report',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Exporting report as CSV...')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // Alerts List
        Expanded(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : alerts.isEmpty
                  ? Center(
                      child: Text(
                        "No alerts found.",
                        style: GoogleFonts.inter(color: Colors.grey),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchAlerts,
                      child: ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: alerts.length,
                        itemBuilder: (context, index) {
                          final alert = alerts[index];
                          return _buildAlertCard(alert)
                              .animate()
                              .fadeIn(
                                  delay:
                                      Duration(milliseconds: 50 * index))
                              .slideY(begin: 0.05);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String? riskLevel) {
    final isSelected = selectedRiskLevel == riskLevel;
    return GestureDetector(
      onTap: () {
        setState(() => selectedRiskLevel = riskLevel);
        _fetchAlerts();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? Colors.white
                : AppColors.getTextPrimary(
                    Theme.of(context).brightness),
          ),
        ),
      ),
    );
  }

  Widget _buildAlertCard(Detection alert) {
    // Classify risk by animal name matching new tiers
    final animalLower = alert.animal.toLowerCase();
    Color riskColor;
    String riskLabel;
    if (['elephant', 'tiger', 'leopard'].contains(animalLower)) {
      riskColor = const Color(0xFFFF5757);
      riskLabel = 'High Risk';
    } else if (['bear', 'boar', 'monkey', 'wild boar'].contains(animalLower)) {
      riskColor = const Color(0xFFFFB347);
      riskLabel = 'Medium Risk';
    } else {
      riskColor = const Color(0xFF4ADE80);
      riskLabel = 'Low Risk';
    }

    Color statusColor = Colors.grey;
    if (alert.status == 'Pending') statusColor = const Color(0xFFFFB347);
    if (alert.status == 'Investigating') statusColor = const Color(0xFF60A5FA);
    if (alert.status == 'Resolved') statusColor = const Color(0xFF4ADE80);

    String formatTimestamp(String ts) {
      try {
        final date = DateTime.parse(ts).toLocal();
        return "${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
      } catch (_) {
        return ts;
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1A1D24) : Colors.white;

    // Build proper image URL
    final rawUrl = alert.imageUrl;
    final String imageUrl;
    if (rawUrl.isEmpty) {
      imageUrl = "";
    } else if (rawUrl.startsWith('http')) {
      imageUrl = rawUrl;
    } else {
      imageUrl = "${ApiConfig.baseUrl}/api/images/${rawUrl.split('/').last}";
    }

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OfficerAlertDetailsScreen(alert: alert),
          ),
        );
        _fetchAlerts();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: riskColor.withOpacity(0.25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: riskColor.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Full-width detection image ──
            SizedBox(
              width: double.infinity,
              height: 180,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl.isNotEmpty)
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      headers: {"device-id": alert.deviceId},
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: const Color(0xFF0D1117),
                          child: const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white38, strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (ctx, err, st) => Container(
                        color: const Color(0xFF0D1117),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image_rounded,
                                color: Colors.white24, size: 44),
                            const SizedBox(height: 8),
                            Text('No image',
                                style: GoogleFonts.inter(
                                    color: Colors.white24, fontSize: 12)),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      color: const Color(0xFF0D1117),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: riskColor.withOpacity(0.4), size: 48),
                          const SizedBox(height: 8),
                          Text('No image captured',
                              style: GoogleFonts.inter(
                                  color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                    ),

                  // Gradient overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Risk badge — top left
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: riskColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        riskLabel,
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
                      ),
                    ),
                  ),


                  // Status badge — top right
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: statusColor.withOpacity(0.5)),
                      ),
                      child: Text(
                        alert.status,
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: statusColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Card body ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          alert.animal.toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: riskColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: riskColor.withOpacity(0.4),
                                blurRadius: 6,
                                spreadRadius: 1),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.router_rounded,
                          size: 13,
                          color: isDark
                              ? Colors.white38
                              : Colors.grey.shade500),
                      const SizedBox(width: 5),
                      Text(
                        alert.deviceId,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white38
                                : Colors.grey.shade500),
                      ),
                      const Spacer(),
                      Icon(Icons.access_time_rounded,
                          size: 13,
                          color: isDark
                              ? Colors.white38
                              : Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        formatTimestamp(alert.timestamp),
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white38
                                : Colors.grey.shade500),
                      ),
                    ],
                  ),
                  if (alert.officerNote != null &&
                      alert.officerNote!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.sticky_note_2_rounded,
                              size: 14, color: Colors.blue),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              alert.officerNote!,
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.blue.shade700),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: Duration(milliseconds: 30 * alerts.indexOf(alert))).slideY(begin: 0.04),
    );
  }

  Widget _actionBtn(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }

  Widget _investigateBtn(
      Detection alert, bool canInvestigate, bool isAlreadyInProgress) {
    return const SizedBox.shrink(); // Removed
  }
}
