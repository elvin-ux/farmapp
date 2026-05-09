import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app_theme.dart';
import '../models/detection_model.dart';
import '../services/officer_service.dart';
import '../config/api_config.dart';

class OfficerAlertDetailsScreen extends StatefulWidget {
  final Detection alert;

  const OfficerAlertDetailsScreen({super.key, required this.alert});

  @override
  State<OfficerAlertDetailsScreen> createState() => _OfficerAlertDetailsScreenState();
}

class _OfficerAlertDetailsScreenState extends State<OfficerAlertDetailsScreen> {
  late String currentStatus;
  final TextEditingController officerNoteController = TextEditingController();
  bool isSavingStatus = false;
  bool isSendingNote = false;

  @override
  void initState() {
    super.initState();
    currentStatus = widget.alert.status.isEmpty ? 'Pending' : widget.alert.status;
    officerNoteController.text = widget.alert.officerNote ?? '';
  }

  // Update STATUS only
  Future<void> _updateStatus() async {
    setState(() => isSavingStatus = true);
    bool success = await OfficerService.updateAlertStatus(
      id: widget.alert.id,
      status: currentStatus,
    );
    setState(() => isSavingStatus = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? "Status updated to $currentStatus" : "Failed to update status",
              style: const TextStyle(color: Colors.white)),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      if (success) Navigator.pop(context);
    }
  }

  // Send NOTE only (notifies farmer)
  Future<void> _sendNote() async {
    final note = officerNoteController.text.trim();
    if (note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a note before sending')),
      );
      return;
    }
    setState(() => isSendingNote = true);
    bool success = await OfficerService.updateAlertStatus(
      id: widget.alert.id,
      status: currentStatus,
      officerNote: note,
    );
    setState(() => isSendingNote = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '✅ Note sent to farmer' : '❌ Failed to send note',
              style: const TextStyle(color: Colors.white)),
          backgroundColor: success ? Colors.teal : Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    officerNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color riskColor = Colors.grey;
    if (widget.alert.riskLevel == 'high') riskColor = Colors.red;
    if (widget.alert.riskLevel == 'medium') riskColor = Colors.orange;
    if (widget.alert.riskLevel == 'low') riskColor = Colors.green;

    final String displayImageUrl;
    if (widget.alert.imageUrl.isEmpty) {
      displayImageUrl = "";
    } else if (widget.alert.imageUrl.startsWith('http')) {
      displayImageUrl = widget.alert.imageUrl;
    } else {
      displayImageUrl = "${ApiConfig.baseUrl}/api/images/${widget.alert.imageUrl.split('/').last}";
    }

    String formatTimestamp(String timestamp) {
      try {
        final date = DateTime.parse(timestamp).toLocal();
        return "${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
      } catch (e) {
        return timestamp;
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Alert Details",
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.getTextPrimary(Theme.of(context).brightness),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            Hero(
              tag: "alert_image_${widget.alert.id}",
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: widget.alert.imageUrl.isNotEmpty
                    ? InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 4.0,
                        child: Image.network(
                          displayImageUrl,
                          headers: {"device-id": widget.alert.deviceId},
                          width: double.infinity,
                          height: 250,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _fallbackImage(),
                        ),
                      )
                    : _fallbackImage(),
              ),
            ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),
            
            const SizedBox(height: 24),

            // Header Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.alert.animal.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.getTextPrimary(Theme.of(context).brightness),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: riskColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: riskColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "${widget.alert.riskLevel.toUpperCase()} RISK",
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: riskColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),

            const SizedBox(height: 16),
            
            _infoRow(Icons.access_time_filled, "Detected", formatTimestamp(widget.alert.timestamp)),
            const SizedBox(height: 8),
            _infoRow(Icons.location_on, "Farm Location", "Device: ${widget.alert.deviceId}"),
            const SizedBox(height: 8),
            _infoRow(Icons.track_changes_sharp, "Confidence", "${(widget.alert.confidence * 100).toStringAsFixed(1)}%"),
            
            const SizedBox(height: 24),
            
            const SizedBox(height: 32),
            Divider(color: Colors.grey.withOpacity(0.2)),
            const SizedBox(height: 24),

            // Response System
            Text(
              "Action & Response",
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.getTextPrimary(Theme.of(context).brightness),
              ),
            ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1),
            const SizedBox(height: 16),

            // Status Segmented Button with one-way transition enforcement
            Text(
              "Status",
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: SegmentedButton<String>(
                segments: [
                  const ButtonSegment<String>(value: 'Pending', label: Text('Pending')),
                  ButtonSegment<String>(
                    value: 'Investigating',
                    label: const Text('Investigating'),
                    enabled: currentStatus == 'Pending' || currentStatus == 'Investigating',
                  ),
                  ButtonSegment<String>(
                    value: 'Resolved',
                    label: const Text('Resolved'),
                    enabled: currentStatus == 'Investigating' || currentStatus == 'Resolved',
                  ),
                ],
                selected: {currentStatus},
                onSelectionChanged: (Set<String> newSelection) {
                  final next = newSelection.first;
                  // Enforce forward-only transitions
                  final order = ['Pending', 'Investigating', 'Resolved'];
                  if (order.indexOf(next) > order.indexOf(currentStatus)) {
                    setState(() => currentStatus = next);
                  }
                },
                style: SegmentedButton.styleFrom(
                  textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                  selectedBackgroundColor: AppColors.primary.withOpacity(0.1),
                  selectedForegroundColor: AppColors.primary,
                ),
              ),
            ).animate().fadeIn(delay: 300.ms),
            
            const SizedBox(height: 16),

            // ── Status Update Button ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: isSavingStatus ? null : _updateStatus,
                icon: isSavingStatus
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_rounded, size: 20),
                label: Text(
                  isSavingStatus ? 'Saving...' : 'Save Status',
                  style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
              ),
            ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),
            
            const SizedBox(height: 32),
            
            // Dynamic Incident Timeline
            Text(
              "Incident Timeline",
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.getTextPrimary(Theme.of(context).brightness),
              ),
            ).animate().fadeIn(delay: 600.ms),
            const SizedBox(height: 16),

            // Step 1: Always active
            _timelineItem(
              Icons.warning_amber_rounded,
              "Alert Created",
              formatTimestamp(widget.alert.timestamp),
              isFirst: true,
              isActive: true,
            ),
            // Step 2: Active once any officer action taken
            _timelineItem(
              Icons.policy_rounded,
              "Officer Assigned",
              currentStatus != 'Pending' ? "Officer responding" : "Awaiting assignment",
              isActive: currentStatus != 'Pending',
            ),
            // Step 3: Investigating
            _timelineItem(
              Icons.search_rounded,
              "Investigating",
              currentStatus == 'Investigating' || currentStatus == 'Resolved'
                  ? "Investigation in progress"
                  : "Not yet started",
              isActive: currentStatus == 'Investigating' || currentStatus == 'Resolved',
            ),
            // Step 4: Resolved
            _timelineItem(
              Icons.task_alt_rounded,
              "Resolved",
              currentStatus == 'Resolved' ? "Case closed successfully" : "Pending resolution",
              isLast: true,
              isActive: currentStatus == 'Resolved',
            ),

            const SizedBox(height: 24),

            // ── Officer Note ── (sends notification to farmer)
            Text(
              "Note to Farmer",
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.getTextPrimary(Theme.of(context).brightness),
              ),
            ).animate().fadeIn(delay: 650.ms),
            const SizedBox(height: 6),
            Text(
              "This note will be sent as a push notification to the farmer.",
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic),
            ).animate().fadeIn(delay: 660.ms),
            const SizedBox(height: 12),

            // Note field + Send button
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: officerNoteController,
                    maxLines: 3,
                    style: GoogleFonts.inter(
                        color: AppColors.getTextPrimary(
                            Theme.of(context).brightness)),
                    decoration: InputDecoration(
                      hintText:
                          "e.g. Elephant spotted near river bank, team dispatched...",
                      hintStyle:
                          GoogleFonts.inter(color: Colors.grey, fontSize: 13),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 88,
                  child: ElevatedButton(
                    onPressed: isSendingNote ? null : _sendNote,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: isSendingNote
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.send_rounded, size: 22),
                              const SizedBox(height: 4),
                              Text('Send',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 700.ms),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextPrimary(Theme.of(context).brightness),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _fallbackImage() {
    return Container(
      width: double.infinity,
      height: 200,
      color: Colors.grey.shade200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            "No Image Available",
            style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _circularActionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _timelineItem(IconData icon, String title, String subtitle, {bool isFirst = false, bool isLast = false, bool isActive = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 2,
                height: 20,
                color: isFirst ? Colors.transparent : (isActive ? AppColors.primary : Colors.grey.shade300),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : Colors.grey.shade300,
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).cardColor, width: 2),
                ),
                child: Icon(icon, size: 14, color: Colors.white),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  color: isLast ? Colors.transparent : (isActive ? AppColors.primary : Colors.grey.shade300),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24, top: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: isActive ? AppColors.getTextPrimary(Theme.of(context).brightness) : Colors.grey)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
