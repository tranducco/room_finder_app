import 'package:flutter/material.dart';

import '../../../data/admin_service.dart';
import '../../widgets/app_button_style.dart';

class AdminAiMonitorTab extends StatefulWidget {
  const AdminAiMonitorTab({super.key});

  @override
  State<AdminAiMonitorTab> createState() => _AdminAiMonitorTabState();
}

class _AdminAiMonitorTabState extends State<AdminAiMonitorTab> {
  final AdminService _adminService = AdminService();

  final _botNameController = TextEditingController();
  final _modelController = TextEditingController();
  final _systemPromptController = TextEditingController();
  final _apiKeyController = TextEditingController();

  double _temperature = 0.5;
  List<Map<String, dynamic>> _faqs = [];

  bool _isLoading = true;
  bool _isSaving = false;
  int _totalSessions = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _botNameController.dispose();
    _modelController.dispose();
    _systemPromptController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _adminService.getAiKnowledge();
      final stats = await _adminService.getDashboardStats();
      if (mounted) {
        setState(() {
          _botNameController.text = data['botName'] as String? ?? 'Trợ lý ảo TroTot AI';
          _modelController.text = data['modelName'] as String? ?? 'gemini-1.5-flash';
          _systemPromptController.text = data['systemPrompt'] as String? ?? '';
          _apiKeyController.text = data['apiKey'] as String? ?? '';
          _temperature = (data['temperature'] as num?)?.toDouble() ?? 0.5;
          _faqs = List<Map<String, dynamic>>.from(
            (data['faqs'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
          );
          _totalSessions = stats.totalAiSessions;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveData() async {
    setState(() => _isSaving = true);
    try {
      await _adminService.saveAiKnowledge({
        'botName': _botNameController.text.trim(),
        'modelName': _modelController.text.trim(),
        'systemPrompt': _systemPromptController.text.trim(),
        'apiKey': _apiKeyController.text.trim(),
        'temperature': _temperature,
        'faqs': _faqs,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 Đã lưu cấu hình tri thức Chatbot AI thành công!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi lưu cấu hình: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addFaqDialog() {
    final qController = TextEditingController();
    final aController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm câu hỏi & trả lời mẫu (FAQ)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qController,
              decoration: const InputDecoration(
                labelText: 'Câu hỏi của người thuê',
                hintText: 'Ví dụ: Giá điện nước thông thường là bao nhiêu?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: aController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Câu trả lời chuẩn của AI',
                hintText: 'Nhập câu trả lời chi tiết và chính xác...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              final q = qController.text.trim();
              final a = aController.text.trim();
              if (q.isNotEmpty && a.isNotEmpty) {
                setState(() {
                  _faqs.add({'question': q, 'answer': a});
                });
                Navigator.pop(ctx);
              }
            },
            style: AppButtonStyle.primary(),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00897B)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trợ lý AI Chatbot & Quản trị Tri thức',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cấu hình System Prompt, mô hình LLM và kho kiến thức tư vấn phòng trọ (RAG Framework)',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveData,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 16),
                  label: Text(_isSaving ? 'Đang lưu...' : 'Lưu cấu hình'),
                  style: AppButtonStyle.primary(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // AI Status Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF004D40), Color(0xFF00897B)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00897B).withAlpha(50),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.psychology_rounded, size: 36, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mô hình AI: Google Gemini 1.5 Flash (Tổng cộng $_totalSessions phiên tư vấn)',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Đã kích hoạt RAG Framework: AI tự động phân tích dữ liệu phòng trọ thực tế từ Firestore để tư vấn và đính kèm thẻ phòng trực tiếp cho người thuê.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withAlpha(210),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // System Prompt Configuration
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(6),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cấu hình Nhân cách & System Prompt',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _botNameController,
                          decoration: const InputDecoration(
                            labelText: 'Tên hiển thị của Chatbot',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _modelController,
                          decoration: const InputDecoration(
                            labelText: 'Model Identifier',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Temperature Slider
                  Row(
                    children: [
                      Text(
                        'Độ sáng tạo (Temperature): ${_temperature.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Expanded(
                        child: Slider(
                          value: _temperature,
                          min: 0.0,
                          max: 1.0,
                          divisions: 10,
                          activeColor: const Color(0xFF00897B),
                          onChanged: (val) => setState(() => _temperature = val),
                        ),
                      ),
                      Text(
                        _temperature < 0.4
                            ? 'Chính xác/Kỷ luật'
                            : _temperature > 0.7
                                ? 'Tự do sáng tạo'
                                : 'Cân bằng (Khuyến nghị)',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // System Prompt textarea
                  TextField(
                    controller: _systemPromptController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'System Prompt chính',
                      hintText: 'Nhập hướng dẫn chuyên môn và quy tắc ứng xử của Chatbot...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Gemini API Key (Optional)
                  TextField(
                    controller: _apiKeyController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Google Gemini API Key (Tùy chọn)',
                      hintText: 'Nhập AIzaSy... (nếu để trống hệ thống dùng API Key mặc định / Offline RAG)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.key_rounded, color: Color(0xFF00897B)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // FAQ & Knowledge Base
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Kho Tri thức & Câu hỏi thường gặp (FAQ)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _addFaqDialog,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Thêm câu hỏi mẫu'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B).withAlpha(15),
                    foregroundColor: const Color(0xFF00897B),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            if (_faqs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Center(
                  child: Text(
                    'Chưa có câu hỏi mẫu nào. Bấm "Thêm câu hỏi mẫu" để bổ sung tri thức cho AI.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _faqs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (ctx, index) {
                  final faq = _faqs[index];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00897B).withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.question_answer_outlined,
                            color: Color(0xFF00897B),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                faq['question'] as String? ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF1A1A2E),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                faq['answer'] as String? ?? '',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
                          onPressed: () {
                            setState(() {
                              _faqs.removeAt(index);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

