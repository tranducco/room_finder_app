import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../data/admin_service.dart';
import '../../../data/ai_rate_limit_service.dart';
import '../../../data/ai_service.dart';
import '../../../data/room_service.dart';
import '../../../domain/models/chat_message.dart';
import '../../../domain/models/chat_session.dart';
import '../../../domain/models/room.dart';
import '../../widgets/app_button_style.dart';
import '../../widgets/app_image.dart';

class AiChatSheet extends StatefulWidget {
  const AiChatSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const AiChatSheet(),
    );
  }

  @override
  State<AiChatSheet> createState() => _AiChatSheetState();
}

class _AiChatSheetState extends State<AiChatSheet> {
  final AiService _aiService = AiService();
  final RoomService _roomService = RoomService();
  final AdminService _adminService = AdminService();

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _currentSessionId;
  String _botName = 'Trợ lý ảo TroTot AI';
  List<Map<String, dynamic>> _faqs = [];

  bool _isSending = false;
  bool _showSessionHistory = false;
  final Map<String, Room?> _roomCache = {};

  @override
  void initState() {
    super.initState();
    _loadBotConfig();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadBotConfig() async {
    try {
      final config = await _adminService.getAiKnowledge();
      if (mounted) {
        setState(() {
          _botName = config['botName'] as String? ?? 'Trợ lý ảo TroTot AI';
          _faqs = List<Map<String, dynamic>>.from(
            (config['faqs'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
          );
        });
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty || _isSending) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để sử dụng Chatbot AI!')),
      );
      return;
    }

    _textController.clear();
    setState(() => _isSending = true);
    _scrollToBottom();

    try {
      // 1. Tạo session mới nếu chưa có
      String sessionId = _currentSessionId ?? '';
      if (sessionId.isEmpty) {
        sessionId = await _aiService.createSession(user.uid, cleanText);
        if (mounted) {
          setState(() => _currentSessionId = sessionId);
        }
      }

      // 2. Gửi tin nhắn và chờ bot xử lý
      await _aiService.sendMessage(
        sessionId: sessionId,
        userId: user.uid,
        userMessage: cleanText,
      );

      _scrollToBottom();
    } on RateLimitExceededException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFD97706),
            content: Row(
              children: [
                const Icon(Icons.speed_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text(e.message)),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể gửi tin nhắn: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  Future<Room?> _getRoomCached(String roomId) async {
    if (_roomCache.containsKey(roomId)) {
      return _roomCache[roomId];
    }
    final room = await _roomService.getRoomById(roomId);
    _roomCache[roomId] = room;
    return room;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final user = FirebaseAuth.instance.currentUser;

    return Container(
      height: mediaQuery.size.height * 0.88,
      margin: EdgeInsets.only(
        top: mediaQuery.padding.top + 20,
        bottom: mediaQuery.viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              // 1. Header
              _buildHeader(user),

              // 2. Body (Sessions History OR Active Chat Messages)
              Expanded(
                child: _showSessionHistory
                    ? _buildSessionHistoryList(user)
                    : _buildChatBody(user),
              ),

              // 3. Typing indicator
              if (_isSending)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF00897B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_botName đang suy nghĩ và tìm kiếm...',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),

              // 4. Input Bar
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(User? user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF00897B).withAlpha(40), width: 1.5),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: ClipOval(
              child: Image.asset(
                'assets/images/ai_bot.png',
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.smart_toy_rounded,
                  color: Color(0xFF00897B),
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _botName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00897B).withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt, size: 12, color: Color(0xFF00897B)),
                          Text(
                            'Gemini AI',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF00897B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Text(
                  _showSessionHistory
                      ? 'Lịch sử các phiên hội thoại'
                      : 'Tư vấn tìm trọ, giá cả & thủ tục hợp đồng',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          if (user != null)
            IconButton(
              icon: Icon(
                _showSessionHistory ? Icons.chat_bubble_outline : Icons.history_rounded,
                color: const Color(0xFF00897B),
              ),
              tooltip: _showSessionHistory ? 'Vào đoạn chat' : 'Lịch sử trò chuyện',
              onPressed: () {
                setState(() => _showSessionHistory = !_showSessionHistory);
              },
            ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined, color: Color(0xFF00897B)),
            tooltip: 'Hội thoại mới',
            onPressed: () {
              setState(() {
                _currentSessionId = null;
                _showSessionHistory = false;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBody(User? user) {
    if (user == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: Color(0xFF00897B)),
              const SizedBox(height: 12),
              const Text(
                'Vui lòng đăng nhập để trò chuyện cùng AI',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/login');
                },
                style: AppButtonStyle.primary(),
                child: const Text('Đăng nhập ngay'),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentSessionId == null) {
      return _buildWelcomeAndPrompts();
    }

    return StreamBuilder<List<ChatMessage>>(
      stream: _aiService.getMessagesStream(_currentSessionId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00897B)),
          );
        }

        final messages = snapshot.data ?? [];
        if (messages.isEmpty) {
          return _buildWelcomeAndPrompts();
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[index];
            return _buildMessageItem(msg);
          },
        );
      },
    );
  }

  Widget _buildWelcomeAndPrompts() {
    final quickPrompts = [
      '🔍 Tìm phòng Cầu Giấy dưới 3.5 triệu',
      '❄️ Tìm phòng có điều hòa, khép kín',
      '📝 Lưu ý cọc phòng và ký hợp đồng thuê',
      '📅 Làm sao để đặt lịch xem phòng trên app?',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF00897B).withAlpha(15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00897B).withAlpha(40)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF00897B).withAlpha(40), width: 1.5),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/ai_bot.png',
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.smart_toy_rounded,
                        color: Color(0xFF00897B),
                        size: 26,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Xin chào! Tôi là $_botName 👋',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF004D40),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tôi có thể giúp bạn tìm phòng trọ ưng ý theo quận huyện, mức giá, tiện ích hoặc giải đáp các thắc mắc về hợp đồng, cọc trọ.',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Gợi ý câu hỏi phổ biến:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: quickPrompts.map((prompt) {
              return ActionChip(
                backgroundColor: Colors.white,
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                label: Text(
                  prompt,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
                ),
                onPressed: () => _sendMessage(prompt),
              );
            }).toList(),
          ),
          if (_faqs.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Câu hỏi thường gặp từ Quản trị viên:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 12),
            ..._faqs.take(3).map((f) {
              final q = f['question'] as String? ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => _sendMessage(q),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.help_outline, size: 16, color: Color(0xFF00897B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            q,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage msg) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF00897B),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            msg.text,
            style: const TextStyle(fontSize: 14, color: Colors.white, height: 1.4),
          ),
        ),
      );
    }

    // Model / Bot bubble
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF00897B).withAlpha(30), width: 1.2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/ai_bot.png',
                      width: 34,
                      height: 34,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.smart_toy_rounded,
                        color: Color(0xFF00897B),
                        size: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      msg.text,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1A1A2E),
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Embedded Recommended Room Cards (RAG Interactive Cards)
            if (msg.suggestedRoomIds.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🏠 Phòng trọ được AI đề xuất cho bạn:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00897B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...msg.suggestedRoomIds.map((roomId) {
                      return FutureBuilder<Room?>(
                        future: _getRoomCached(roomId),
                        builder: (context, roomSnap) {
                          if (!roomSnap.hasData || roomSnap.data == null) {
                            return const SizedBox.shrink();
                          }
                          final room = roomSnap.data!;
                          return _buildEmbeddedRoomCard(room);
                        },
                      );
                    }),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmbeddedRoomCard(Room room) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00897B).withAlpha(50)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.pushNamed(context, '/room-detail', arguments: room);
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AppImage(
                    imageUrl: room.images.isNotEmpty ? room.images.first : '',
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              '${room.district} • ${room.area}m²',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${room.price} triệu/tháng',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00897B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00897B),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Xem chi tiết',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionHistoryList(User? user) {
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<List<ChatSession>>(
      stream: _aiService.getUserSessionsStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00897B)));
        }

        final sessions = snapshot.data ?? [];
        if (sessions.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  'Bạn chưa có cuộc trò chuyện nào trước đó.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: sessions.length,
          separatorBuilder: (ctx, i) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final session = sessions[index];
            final isSelected = session.id == _currentSessionId;

            return ListTile(
              selected: isSelected,
              selectedTileColor: const Color(0xFF00897B).withAlpha(15),
              leading: CircleAvatar(
                backgroundColor: isSelected
                    ? const Color(0xFF00897B)
                    : Colors.grey.shade200,
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 18,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
              title: Text(
                session.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                session.lastMessage.isNotEmpty ? session.lastMessage : 'Cuộc trò chuyện',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                tooltip: 'Xóa phiên này',
                onPressed: () async {
                  await _aiService.deleteSession(session.id);
                  if (_currentSessionId == session.id) {
                    setState(() => _currentSessionId = null);
                  }
                },
              ),
              onTap: () {
                setState(() {
                  _currentSessionId = session.id;
                  _showSessionHistory = false;
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              textInputAction: TextInputAction.send,
              onSubmitted: (val) => _sendMessage(val),
              decoration: InputDecoration(
                hintText: 'Hỏi $_botName về phòng, giá thuê, hợp đồng...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFF00897B), width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF00897B),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              onPressed: _isSending ? null : () => _sendMessage(_textController.text),
            ),
          ),
        ],
      ),
    );
  }
}
