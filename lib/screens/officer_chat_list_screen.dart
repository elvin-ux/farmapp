import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app_theme.dart';
import '../services/officer_service.dart';
import '../services/chat_delete_service.dart';
import 'officer_chat_detail_screen.dart';

class OfficerChatListScreen extends StatefulWidget {
  const OfficerChatListScreen({super.key});

  @override
  State<OfficerChatListScreen> createState() => _OfficerChatListScreenState();
}

class _OfficerChatListScreenState extends State<OfficerChatListScreen> {
  bool isLoading = true;
  List<dynamic> farms = [];
  Set<String> _deletedChats = {};

  @override
  void initState() {
    super.initState();
    _fetchFarms();
  }

  Future<void> _fetchFarms() async {
    setState(() => isLoading = true);
    final data = await OfficerService.getFarms();
    final deleted = await ChatDeleteService.getOfficerDeletedChats();
    if (mounted) {
      setState(() {
        farms = data;
        _deletedChats = deleted;
        isLoading = false;
      });
    }
  }

  List<dynamic> get _visibleFarms =>
      farms.where((f) => !_deletedChats.contains(f['deviceId'] ?? '')).toList();

  // ── WhatsApp-style long-press bottom sheet ────────────────────────────────

  void _showChatOptions(String deviceId, String farmerName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Text(
                    farmerName,
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const Divider(),

                // Delete for Me
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.delete_outline_rounded,
                        color: Colors.red.shade500),
                  ),
                  title: Text(
                    "Delete for Me",
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade500),
                  ),
                  subtitle: Text(
                    "Remove this chat only from your device",
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDeleteForMe(deviceId);
                  },
                ),

                const Divider(height: 1, indent: 16, endIndent: 16),

                // Clear Chat
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.cleaning_services_rounded,
                        color: Colors.orange.shade600),
                  ),
                  title: Text(
                    "Clear Chat",
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade600),
                  ),
                  subtitle: Text(
                    "Clear all messages from your view",
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmClearChat(deviceId);
                  },
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteForMe(String deviceId) async {
    final ok = await _showConfirmDialog(
      icon: Icons.delete_sweep_rounded,
      iconColor: Colors.red.shade400,
      title: "Delete for Me",
      message:
          "This chat will be removed only from your device. The farmer will still see all messages.",
      confirmText: "Delete",
      confirmColor: Colors.red.shade400,
    );
    if (ok && mounted) {
      await ChatDeleteService.deleteOfficerChat(deviceId);
      final updated = await ChatDeleteService.getOfficerDeletedChats();
      setState(() => _deletedChats = updated);
      _showSnack("Chat deleted for you", Colors.red.shade400);
    }
  }

  Future<void> _confirmClearChat(String deviceId) async {
    final ok = await _showConfirmDialog(
      icon: Icons.cleaning_services_rounded,
      iconColor: Colors.orange.shade600,
      title: "Clear Chat",
      message:
          "All messages will be cleared from your view only. The farmer will not be affected.",
      confirmText: "Clear",
      confirmColor: Colors.orange.shade600,
    );
    if (ok && mounted) {
      await ChatDeleteService.clearOfficerChatMessages(deviceId);
      _showSnack("Chat cleared for you", Colors.orange.shade600);
    }
  }

  Future<bool> _showConfirmDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 8),
            Text(title,
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message,
            style:
                GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade700)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                Text("Cancel", style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (farms.isEmpty) {
      return Center(
        child: Text("No active farms to chat with.",
            style: GoogleFonts.inter(color: Colors.grey)),
      );
    }

    final visible = _visibleFarms;

    if (visible.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 52, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text(
              "No chats to show.\nLong-press a chat to restore it.",
              textAlign: TextAlign.center,
              style:
                  GoogleFonts.inter(color: Colors.grey.shade500, height: 1.6),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchFarms,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final farm = visible[index];
          final deviceId = farm['deviceId'] ?? 'Unknown';
          final name = farm['name']?.isNotEmpty == true
              ? farm['name']
              : 'Farmer - $deviceId';
          final phone = farm['phone'] ?? '';

          return GestureDetector(
            // Long press → WhatsApp-style bottom sheet
            onLongPress: () => _showChatOptions(deviceId, name),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: const Icon(Icons.person, color: AppColors.primary),
                ),
                title: Text(
                  name,
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Text(
                  "Farm ID: $deviceId",
                  style:
                      GoogleFonts.inter(color: Colors.grey, fontSize: 13),
                ),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Colors.grey),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OfficerChatDetailScreen(
                        deviceId: deviceId,
                        farmerName: name,
                        farmerPhone: phone,
                      ),
                    ),
                  );
                  // Refresh deleted state when returning
                  final updated =
                      await ChatDeleteService.getOfficerDeletedChats();
                  if (mounted) setState(() => _deletedChats = updated);
                },
              ),
            ),
          ).animate().fadeIn(delay: Duration(milliseconds: 50 * index)).slideX(begin: 0.05);
        },
      ),
    );
  }
}
