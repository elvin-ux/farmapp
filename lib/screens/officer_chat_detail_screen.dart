import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import '../services/message_service.dart';
import '../services/chat_delete_service.dart';
import '../services/socket_service.dart';

class OfficerChatDetailScreen extends StatefulWidget {
  final String deviceId;
  final String farmerName;
  final String farmerPhone;

  const OfficerChatDetailScreen({
    super.key,
    required this.deviceId,
    required this.farmerName,
    required this.farmerPhone,
  });

  @override
  State<OfficerChatDetailScreen> createState() =>
      _OfficerChatDetailScreenState();
}

class _OfficerChatDetailScreenState extends State<OfficerChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SocketService _socketService = SocketService();

  bool isLoading = true;
  List<dynamic> messages = [];

  /// Message IDs permanently deleted by this officer
  Set<String> _deletedMsgIds = {};

  final List<String> quickReplies = [
    'Stay inside',
    'Help is on the way',
    'False alert?',
    'Area clear',
  ];

  @override
  void initState() {
    super.initState();
    _loadAndFetch();
    _setupSocket();
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> _loadAndFetch() async {
    _deletedMsgIds = await ChatDeleteService.getOfficerDeletedMessageIds();
    await _fetchMessages();
  }

  void _setupSocket() {
    _socketService.connect();
    _socketService.listen('new_message', (data) {
      if (!mounted) return;
      if (data['deviceId'] != widget.deviceId) return;
      if (data['senderRole'] == 'officer') return; // skip own echo
      final msgId = data['_id'] ?? '';
      if (_deletedMsgIds.contains(msgId)) return;
      setState(() => messages.add(data));
      _scrollToBottom();
      MessageService.markAsRead(deviceId: widget.deviceId, role: 'officer');
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _socketService.off('new_message');
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _fetchMessages() async {
    if (mounted) setState(() => isLoading = true);

    final clearedAt =
        await ChatDeleteService.getOfficerChatClearedAt(widget.deviceId);
    _deletedMsgIds = await ChatDeleteService.getOfficerDeletedMessageIds();

    final data = await MessageService.getMessages(widget.deviceId);

    final filtered = data.where((m) {
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
      MessageService.markAsRead(deviceId: widget.deviceId, role: 'officer');
      _scrollToBottom();
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final optimistic = {
      'content': text,
      'senderRole': 'officer',
      'createdAt': DateTime.now().toIso8601String(),
    };

    setState(() {
      messages.add(optimistic);
      _messageController.clear();
    });
    _scrollToBottom();

    final success = await MessageService.sendMessage(
      deviceId: widget.deviceId,
      senderId: 'SYSTEM_OFFICER',
      senderRole: 'officer',
      content: text,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
      _fetchMessages();
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
                    final msgId = msg['_id']?.toString();
                    if (msgId != null && msgId.isNotEmpty) {
                      _deleteMessageForMe(msgId, index);
                    } else {
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

  Future<void> _deleteMessageForMe(String msgId, int index) async {
    await ChatDeleteService.deleteOfficerMessage(msgId);
    _deletedMsgIds.add(msgId);
    if (mounted) {
      setState(() => messages.removeAt(index));
      _showSnack('Message deleted for you', Colors.red.shade400);
    }
  }

  // ── 3-dot → Clear Chat ────────────────────────────────────────────────────

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
          'All messages will be permanently cleared from your view. The farmer will not be affected.',
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
      await ChatDeleteService.clearOfficerChatMessages(widget.deviceId);
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
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.farmerName,
              style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600, fontSize: 18),
            ),
            Text(
              'Farm: ${widget.deviceId}',
              style: GoogleFonts.inter(
                  fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          // ── 3-dot → Clear Chat ──────────────────────────────────────────
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
      body: Column(
        children: [
          // ── Messages ────────────────────────────────────────────────────
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
                              'No messages yet.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                  color: Colors.grey.shade500, height: 1.6),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isMe = msg['senderRole'] == 'officer';

                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: GestureDetector(
                              // Long-press → "Delete for Me"
                              onLongPress: () =>
                                  _onMessageLongPress(msg, index),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? AppColors.primary
                                      : Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(20).copyWith(
                                    bottomRight: isMe
                                        ? const Radius.circular(0)
                                        : const Radius.circular(20),
                                    bottomLeft: !isMe
                                        ? const Radius.circular(0)
                                        : const Radius.circular(20),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  msg['content'] ?? '',
                                  style: GoogleFonts.inter(
                                    color: isMe
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // ── Quick Replies ────────────────────────────────────────────────
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: quickReplies.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding:
                      const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                  child: ActionChip(
                    label: Text(quickReplies[index]),
                    onPressed: () => _sendMessage(quickReplies[index]),
                    backgroundColor: Colors.white,
                    labelStyle: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.primary),
                    side: BorderSide(
                        color: AppColors.primary.withOpacity(0.5)),
                  ),
                );
              },
            ),
          ),

          // ── Input ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, -2))
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: GoogleFonts.inter(color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle:
                            GoogleFonts.inter(color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _sendMessage(_messageController.text),
                    child: Container(
                      padding: const EdgeInsets.all(12),
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
      ),
    );
  }
}
