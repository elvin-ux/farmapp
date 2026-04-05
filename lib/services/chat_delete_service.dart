import 'package:shared_preferences/shared_preferences.dart';

/// Local-only "Delete for me" storage.
/// All data is stored in SharedPreferences which persists permanently
/// across app restarts and logins on the same device.
class ChatDeleteService {
  // ─── Keys ─────────────────────────────────────────────────────────────────
  static const String _farmerDeletedChatsKey = 'farmer_deleted_chats';
  static const String _officerDeletedChatsKey = 'officer_deleted_chats';
  static const String _farmerDeletedMsgsKey = 'farmer_deleted_msg_ids';
  static const String _officerDeletedMsgsKey = 'officer_deleted_msg_ids';

  // ═══════════════════════════════════════════════════════════════════════════
  // FARMER — Individual Message Deletion
  // ═══════════════════════════════════════════════════════════════════════════

  /// Permanently store a message ID as deleted for the farmer.
  static Future<void> deleteFarmerMessage(String msgId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_farmerDeletedMsgsKey) ?? [];
    if (!list.contains(msgId)) {
      list.add(msgId);
      await prefs.setStringList(_farmerDeletedMsgsKey, list);
    }
  }

  /// Get all message IDs the farmer has permanently deleted.
  static Future<Set<String>> getFarmerDeletedMessageIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_farmerDeletedMsgsKey) ?? []).toSet();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FARMER — Clear Entire Chat (timestamp-based)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Permanently record a "clear chat" timestamp for this device ID.
  /// All messages created before this timestamp are hidden for the farmer.
  static Future<void> clearFarmerChatMessages(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'farmer_chat_cleared_$deviceId',
      DateTime.now().toIso8601String(),
    );
  }

  /// Returns the timestamp of the last "Clear Chat" for this device, or null.
  static Future<DateTime?> getFarmerChatClearedAt(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('farmer_chat_cleared_$deviceId');
    return raw == null ? null : DateTime.tryParse(raw);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FARMER — Conversation-level deletion (for officer's list view)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> deleteFarmerChat(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_farmerDeletedChatsKey) ?? [];
    if (!list.contains(deviceId)) {
      list.add(deviceId);
      await prefs.setStringList(_farmerDeletedChatsKey, list);
    }
  }

  static Future<void> restoreFarmerChat(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_farmerDeletedChatsKey) ?? [];
    list.remove(deviceId);
    await prefs.setStringList(_farmerDeletedChatsKey, list);
  }

  static Future<bool> isFarmerChatDeleted(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_farmerDeletedChatsKey) ?? [])
        .contains(deviceId);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // OFFICER — Individual Message Deletion
  // ═══════════════════════════════════════════════════════════════════════════

  /// Permanently store a message ID as deleted for the officer.
  static Future<void> deleteOfficerMessage(String msgId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_officerDeletedMsgsKey) ?? [];
    if (!list.contains(msgId)) {
      list.add(msgId);
      await prefs.setStringList(_officerDeletedMsgsKey, list);
    }
  }

  /// Get all message IDs the officer has permanently deleted.
  static Future<Set<String>> getOfficerDeletedMessageIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_officerDeletedMsgsKey) ?? []).toSet();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // OFFICER — Clear Entire Chat (timestamp-based)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> clearOfficerChatMessages(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'officer_chat_cleared_$deviceId',
      DateTime.now().toIso8601String(),
    );
  }

  static Future<DateTime?> getOfficerChatClearedAt(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('officer_chat_cleared_$deviceId');
    return raw == null ? null : DateTime.tryParse(raw);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // OFFICER — Conversation-level deletion (hides chat from officer list)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> deleteOfficerChat(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_officerDeletedChatsKey) ?? [];
    if (!list.contains(deviceId)) {
      list.add(deviceId);
      await prefs.setStringList(_officerDeletedChatsKey, list);
    }
  }

  static Future<void> restoreOfficerChat(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_officerDeletedChatsKey) ?? [];
    list.remove(deviceId);
    await prefs.setStringList(_officerDeletedChatsKey, list);
  }

  static Future<bool> isOfficerChatDeleted(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_officerDeletedChatsKey) ?? [])
        .contains(deviceId);
  }

  static Future<Set<String>> getOfficerDeletedChats() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_officerDeletedChatsKey) ?? []).toSet();
  }
}
