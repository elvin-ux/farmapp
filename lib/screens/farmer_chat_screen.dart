import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app_theme.dart';
import '../services/socket_service.dart';
import '../services/chat_delete_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class FarmerChatScreen extends StatefulWidget {
  final String deviceId;

  const FarmerChatScreen({super.key, required this.deviceId});

  @override
  State<FarmerChatScreen> createState() => _FarmerChatScreenState();
}

class _FarmerChatScreenState extends State<FarmerChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool isLoading = true;

  List<dynamic> messages = [];

  /// IDs of messages the farmer has permanently deleted (persists in prefs)
  Set<String> _deletedMsgIds = {};

  final SocketService _socketService = SocketService();

  @override
  void initState() {
    super.initState();
    _loadAndFetch();
    _setupSockets();
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> _loadAndFetch() async {
    _deletedMsgIds = await ChatDeleteService.getFarmerDeletedMessageIds();
    await _fetchMessages();
  }

  void _setupSockets() {
    _socketService.connect();
    _socketService.listen('new_message', (data) {
      if (!mounted) return;
      if (data['deviceId'] != widget.deviceId) return;
      if (data['senderRole'] == 'farmer') return; // skip own echo
      final msgId = data['_id'] ?? '';
      if (_deletedMsgIds.contains(msgId)) return; // skip already-deleted
      setState(() => messages.add(data));
      _scrollToBottom();
      _markAsRead();
    });
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _fetchMessages() async {
    if (mounted) setState(() => isLoading = true);
    try {
      final response = await http
          .get(Uri.parse(
              '${ApiConfig.baseUrl}/api/messages/${widget.deviceId}'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> all = decoded['data'] ?? [];

        // 1. Filter messages cleared via "Clear Chat" (timestamp)
        final clearedAt =
            await ChatDeleteService.getFarmerChatClearedAt(widget.deviceId);

        // 2. Filter individually deleted messages (by ID)
        _deletedMsgIds =
            await ChatDeleteService.getFarmerDeletedMessageIds();

        final filtered = all.where((m) {
          final msgId = m['_id'] ?? '';
          if (_deletedMsgIds.contains(msgId)) return false;
          if (clearedAt != null) {
            final created = DateTime.tryParse(m['createdAt'] ?? '');
            if (created == null || !created.isAfter(clearedAt)) return false;
          }
          return true;
        }).toList();

        if (mounted) {
          setState(() {
            messages = filtered;
            isLoading = false;
          });
          _scrollToBottom();
          _markAsRead();
        }
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _markAsRead() async {
    try {
      await http.put(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/messages/${widget.deviceId}/read'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'role': 'farmer'}),
      );
    } catch (_) {}
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    final content = text.trim();
    _msgController.clear();

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/messages/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'deviceId': widget.deviceId,
          'senderId': widget.deviceId,
          'senderRole': 'farmer',
          'content': content,
        }),
      );
      if (response.statusCode == 201) {
        final newMsg = jsonDecode(response.body)['data'];
        if (mounted) {
          setState(() => messages.add(newMsg));
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')),
        );
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Long-press individual message → "Delete for Me" ───────────────────────

  void _onMessageLongPress(dynamic msg, int index) {
    final msgId = msg['_id']?.toString();
    // Haptic feedback like WhatsApp
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final preview = (msg['content'] ?? '').toString();
        final displayPreview =
            preview.length > 40 ? '${preview.substring(0, 40)}…' : preview;

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
                // Message preview
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.format_quote_rounded,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          displayPreview,
                          style: GoogleFonts.inter(
                              fontSize: 13, color: Colors.grey.shade700),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // Delete for Me option
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
                    'Delete for Me',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade500),
                  ),
                  subtitle: Text(
                    'This message will be permanently deleted only for you',
                    style:
                        GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (msgId != null && msgId.isNotEmpty) {
                      _deleteMessageForMe(msgId, index);
                    } else {
                      // No ID yet (optimistic) — just remove from local list
                      setState(() => messages.removeAt(index));
                    }
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

  /// Permanently delete a single message for the farmer.
  Future<void> _deleteMessageForMe(String msgId, int index) async {
    // 1. Persist the deletion in SharedPreferences
    await ChatDeleteService.deleteFarmerMessage(msgId);
    // 2. Update the in-memory set
    _deletedMsgIds.add(msgId);
    // 3. Remove from the visible list
    if (mounted) {
      setState(() => messages.removeAt(index));
      _showSnack('Message deleted for you', Colors.red.shade400);
    }
  }

  // ── 3-dot menu → Clear Chat ───────────────────────────────────────────────

  Future<void> _confirmClearChat() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.cleaning_services_rounded,
                color: Colors.orange.shade600),
            const SizedBox(width: 8),
            Text('Clear Chat',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'All messages will be permanently cleared from your view. The officer will not be affected.',
          style:
              GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Clear Chat',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      // Permanently store the clear timestamp
      await ChatDeleteService.clearFarmerChatMessages(widget.deviceId);
      setState(() => messages = []);
      _showSnack('Chat cleared permanently', Colors.orange.shade600);
    }
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
    return Column(
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05), blurRadius: 10)
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    shape: BoxShape.circle),
                child:
                    const Icon(Icons.security_rounded, color: Colors.green),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Forest Officer',
                      style: GoogleFonts.outfit(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Assigned to ${widget.deviceId}',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              // ── 3-dot menu ──────────────────────────────────────────────
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                onSelected: (value) {
                  if (value == 'clear') _confirmClearChat();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        Icon(Icons.cleaning_services_rounded,
                            color: Colors.orange.shade600, size: 20),
                        const SizedBox(width: 12),
                        Text('Clear Chat',
                            style: GoogleFonts.inter(
                                color: Colors.orange.shade600,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Chat Area ─────────────────────────────────────────────────────
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: 52, color: Colors.grey.shade400),
                          const SizedBox(height: 14),
                          Text(
                            'No messages yet.\nSend a message to contact your assigned officer.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                                color: Colors.grey.shade500, height: 1.6),
                          ),
                        ],
                      ).animate().fadeIn(),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(20),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMe = msg['senderRole'] == 'farmer';

                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: GestureDetector(
                            // Long-press on the bubble → "Delete for Me"
                            onLongPress: () =>
                                _onMessageLongPress(msg, index),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75,
                              ),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? AppColors.primary
                                    : Theme.of(context).cardColor,
                                borderRadius:
                                    BorderRadius.circular(20).copyWith(
                                  bottomRight: isMe
                                      ? const Radius.circular(0)
                                      : const Radius.circular(20),
                                  bottomLeft: isMe
                                      ? const Radius.circular(20)
                                      : const Radius.circular(0),
                                ),
                                border: isMe
                                    ? null
                                    : Border.all(
                                        color: Colors.grey.withOpacity(0.2)),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                      offset: Offset(0, 2))
                                ],
                              ),
                              child: Text(
                                msg['content'] ?? '',
                                style: GoogleFonts.inter(
                                  color: isMe
                                      ? Colors.white
                                      : AppColors.getTextPrimary(
                                          Theme.of(context).brightness),
                                ),
                              ),
                            ).animate().fadeIn().slideY(begin: 0.1),
                          ),
                        );
                      },
                    ),
        ),

        // ── Quick Replies ─────────────────────────────────────────────────
        Container(
          height: 50,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _quickReplyBtn('🚨 Emergency / हेल्प', Colors.red),
              _quickReplyBtn('All fine here', Colors.green),
              _quickReplyBtn('Wild animal sighted', Colors.orange),
              _quickReplyBtn('Fence damaged', Colors.brown),
            ],
          ),
        ),

        // ── Input ─────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, -2))
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _msgController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle:
                            GoogleFonts.inter(color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _sendMessage(_msgController.text),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _quickReplyBtn(String text, Color color) {
    return GestureDetector(
      onTap: () => _sendMessage(text),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
              fontWeight: FontWeight.w600, color: color, fontSize: 13),
        ),
      ),
    );
  }
}
