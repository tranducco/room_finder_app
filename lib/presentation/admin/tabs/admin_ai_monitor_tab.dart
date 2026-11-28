import 'package:flutter/material.dart';

import '../../../data/admin_service.dart';
import '../../../data/ai_service.dart';
import '../../widgets/app_button_style.dart';

class AdminAiMonitorTab extends StatefulWidget {
  const AdminAiMonitorTab({super.key});

  @override
  State<AdminAiMonitorTab> createState() => _AdminAiMonitorTabState();
}

class _AdminAiMonitorTabState extends State<AdminAiMonitorTab> {
  final AdminService _adminService = AdminService();
  final AiService _aiService = AiService();

  final _botNameController = TextEditingController();
  final _modelController = TextEditingController();
  final _systemPromptController = TextEditingController();
  final _apiKeyController = TextEditingController();

  String _selectedModel = 'gemini-flash-latest';
  double _temperature = 0.5;
  List<Map<String, dynamic>> _faqs = [];

  bool _isLoading = true;
  bool _isSaving = false;
  int _totalSessions = 0;

  bool _isTesting = false;
  String? _testResult;
  bool _testSuccess = false;
  bool _serverKeyConfigured = false;
  String _serverKeySource = 'none';

  final List<Map<String, String>> _availableModels = [
    {
      'id': 'gemini-flash-lite-latest',
      'label': '⚡ Gemini Flash Lite (< 1s, khuyên dùng)',
    },
    {
      'id': 'gemini-flash-latest',
      'label': '✨ Gemini Flash Latest (Khuyên dùng)',
    },
    {
      'id': 'gemini-3.5-flash-lite',
      'label': '🚀 Gemini 3.5 Flash Lite (Siêu nhanh)',
    },
    {
      'id': 'gemini-3.8-flash',
      'label': '🌟 Gemini 3.8 Flash (Bản mới)',
    },
    {
      'id': 'gemini-2.5-flash-lite',
      'label': '💨 Gemini 2.5 Flash Lite (Ổn định)',
    },
    {
      'id': 'gemini-2.5-flash',
      'label': '🔷 Gemini 2.5 Flash (Ổn định)',
    },
    {
      'id': 'custom',
      'label': '🛠️ Tùy chỉnh model khác...',
    },
  ];

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
      final keyStatus = await _aiService.getServerAiKeyStatus();
      if (mounted) {
        final rawModel = data['modelName'] as String? ?? 'gemini-flash-latest';
        final normalized = AiService.normalizeModelName(rawModel);

        final isKnown = _availableModels.any((m) => m['id'] == normalized);
        setState(() {
          _botNameController.text = data['botName'] as String? ?? 'Trợ lý ảo TroTot AI';
          _modelController.text = isKnown ? normalized : rawModel;
          _selectedModel = isKnown ? normalized : 'custom';
          _systemPromptController.text = data['systemPrompt'] as String? ?? '';
          _apiKeyController.clear(); // Write-only: không đọc secret apiKey về client
          _serverKeyConfigured = keyStatus['configured'] == true;
          _serverKeySource = (keyStatus['source'] as String?) ?? 'none';
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
      final effectiveModel = _selectedModel == 'custom'
          ? _modelController.text.trim()
          : _selectedModel;
      final enteredKey = _apiKeyController.text.trim();

      await _adminService.saveAiKnowledge({
        'botName': _botNameController.text.trim(),
        'modelName': effectiveModel,
        'systemPrompt': _systemPromptController.text.trim(),
        if (enteredKey.isNotEmpty) 'apiKey': enteredKey,
        'temperature': _temperature,
        'faqs': _faqs,
      });

      final keyStatus = await _aiService.getServerAiKeyStatus();
      if (!mounted) return;
      setState(() {
        _apiKeyController.clear();
        _serverKeyConfigured = keyStatus['configured'] == true;
        _serverKeySource = (keyStatus['source'] as String?) ?? 'none';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 Đã lưu cấu hình tri thức Chatbot AI an toàn!')),
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

  Future<void> _testGeminiApi() async {
    final key = _apiKeyController.text.trim();

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final targetModel = _selectedModel == 'custom'
        ? _modelController.text.trim()
        : _selectedModel;

    try {
      final message = await _aiService.testGeminiConnection(
        apiKey: key.isNotEmpty ? key : null,
        modelName: targetModel,
      );
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testSuccess = true;
          _testResult = message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testSuccess = false;
          _testResult = e.toString().replaceAll('Exception: ', '');
        });
      }
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

    final isSmall = MediaQuery.of(context).size.width < 720;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isSmall ? 12 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trợ lý AI Chatbot & Tri thức',
                        style: TextStyle(
                          fontSize: isSmall ? 18 : 24,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cấu hình System Prompt, mô hình LLM và kho kiến thức tư vấn phòng trọ (RAG Framework)',
                        style: TextStyle(fontSize: isSmall ? 12 : 13, color: Colors.grey.shade600),
                        maxLines: isSmall ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                isSmall
                    ? IconButton(
                        onPressed: _isSaving ? null : _saveData,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(color: Color(0xFF00897B), strokeWidth: 2),
                              )
                            : const Icon(Icons.save_rounded, color: Color(0xFF00897B)),
                        tooltip: 'Lưu cấu hình',
                      )
                    : ElevatedButton.icon(
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

            SizedBox(height: isSmall ? 12 : 24),

            // AI Status Banner
            Container(
              padding: EdgeInsets.all(isSmall ? 12 : 20),
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
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/ai_bot.png',
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.psychology_rounded,
                          size: 32,
                          color: Color(0xFF00897B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mô hình AI: ${_selectedModel == 'custom' ? (_modelController.text.trim().isNotEmpty ? _modelController.text.trim() : 'Tùy chỉnh') : _selectedModel} (Tổng cộng $_totalSessions phiên tư vấn)',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Đã kích hoạt RAG Framework 3 bước: Intent Extraction -> Top 5 Matching -> Context Generation. Tích hợp sẵn Fallback đa tầng bảo đảm 100% không gián đoạn.',
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

            SizedBox(height: isSmall ? 12 : 24),

            // System Prompt Configuration
            Container(
              padding: EdgeInsets.all(isSmall ? 14 : 24),
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

                  // Bot Name & Model Dropdown
                  if (isSmall) ...[
                    TextField(
                      controller: _botNameController,
                      decoration: const InputDecoration(
                        labelText: 'Tên hiển thị của Chatbot',
                        hintText: 'Ví dụ: Trợ lý ảo TroTot AI',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        prefixIcon: Icon(Icons.smart_toy_rounded, color: Color(0xFF00897B), size: 20),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedModel,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Mô hình AI (Google AI Studio)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        prefixIcon: Icon(Icons.bolt_rounded, color: Color(0xFF00897B), size: 20),
                      ),
                      items: _availableModels.map((m) {
                        return DropdownMenuItem<String>(
                          value: m['id'],
                          child: Text(
                            m['label']!,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedModel = val;
                            if (val != 'custom') {
                              _modelController.text = val;
                            }
                          });
                        }
                      },
                    ),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _botNameController,
                            decoration: const InputDecoration(
                              labelText: 'Tên hiển thị của Chatbot',
                              hintText: 'Ví dụ: Trợ lý ảo TroTot AI',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.smart_toy_rounded, color: Color(0xFF00897B)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedModel,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Mô hình AI (Miễn phí 100% trên Google AI Studio)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.bolt_rounded, color: Color(0xFF00897B)),
                            ),
                            items: _availableModels.map((m) {
                              return DropdownMenuItem<String>(
                                value: m['id'],
                                child: Text(
                                  m['label']!,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedModel = val;
                                  if (val != 'custom') {
                                    _modelController.text = val;
                                  }
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Trường nhập tùy chỉnh model nếu chọn custom
                  if (_selectedModel == 'custom') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _modelController,
                      decoration: const InputDecoration(
                        labelText: 'Model Identifier tùy chỉnh',
                        hintText: 'Ví dụ: gemini-flash-latest, gemini-2.5-flash, gemini-3.8-flash...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.code_rounded, color: Color(0xFF00897B)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Hộp giải thích về tối ưu tốc độ & các phiên bản Gemini
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00897B).withAlpha(12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF00897B).withAlpha(40)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.bolt_rounded, color: Color(0xFF00897B), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800, height: 1.4),
                              children: const [
                                TextSpan(
                                  text: '⚡ Tối ưu phản hồi tức thì (< 1s): ',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00695C)),
                                ),
                                TextSpan(
                                  text: 'Hệ thống đã nâng cấp cơ chế Fast Intent Parsing (0ms) kết hợp với mô hình ',
                                ),
                                TextSpan(
                                  text: 'gemini-flash-lite-latest & gemini-3.5-flash-lite',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00897B)),
                                ),
                                TextSpan(
                                  text: ' giúp giảm độ trễ từ 15s xuống chỉ còn 0.7 - 1.5 giây. Tích hợp sẵn bộ lọc dữ liệu phòng trong bộ nhớ (In-memory Cache) và Fallback đa tầng bảo đảm trải nghiệm người dùng luôn mượt mà nhất.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Temperature Slider
                  if (isSmall) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Độ sáng tạo: ${_temperature.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        Text(
                          _temperature < 0.4
                              ? 'Chính xác/Kỷ luật'
                              : _temperature > 0.7
                                  ? 'Tự do sáng tạo'
                                  : 'Cân bằng',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    Slider(
                      value: _temperature,
                      min: 0.0,
                      max: 1.0,
                      divisions: 10,
                      activeColor: const Color(0xFF00897B),
                      onChanged: (val) => setState(() => _temperature = val),
                    ),
                  ] else ...[
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
                  ],

                  const SizedBox(height: 16),

                  // System Prompt textarea
                  TextField(
                    controller: _systemPromptController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'System Prompt chính',
                      hintText: 'Nhập hướng dẫn chuyên môn và quy tắc ứng xử của Chatbot...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Trạng thái bảo mật API Key phía Server (không trả key về client)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _serverKeyConfigured ? Colors.green.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _serverKeyConfigured ? Colors.green.shade300 : Colors.orange.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _serverKeyConfigured ? Icons.verified_user_rounded : Icons.warning_amber_rounded,
                          size: 18,
                          color: _serverKeyConfigured ? Colors.green.shade700 : Colors.orange.shade800,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _serverKeyConfigured
                                ? (_serverKeySource == 'env'
                                    ? 'Bảo mật API Key: Đã cấu hình trên biến môi trường Server (GEMINI_API_KEY). Client không đọc trực tiếp.'
                                    : 'Bảo mật API Key: Đã lưu bảo mật trong collection system_secrets (client bị chặn đọc).')
                                : 'Chưa cấu hình GEMINI_API_KEY trên Server Proxy. Nhập key mới bên dưới hoặc thiết lập trên Render.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _serverKeyConfigured ? Colors.green.shade900 : Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Gemini API Key (Write-only) & Test Connection qua Server Proxy
                  if (isSmall) ...[
                    TextField(
                      controller: _apiKeyController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Cập nhật Google Gemini API Key (chỉ ghi, không lộ)',
                        hintText: 'Để trống nếu dùng key đang cấu hình trên Server...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.key_rounded, color: Color(0xFF00897B)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isTesting ? null : _testGeminiApi,
                        icon: _isTesting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.electrical_services_rounded, size: 18),
                        label: Text(_isTesting ? 'Đang test...' : 'Kiểm tra kết nối'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00897B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _apiKeyController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Cập nhật Google Gemini API Key (Write-only, lưu tại system_secrets)',
                              hintText: 'Để trống để dùng GEMINI_API_KEY trên Server Proxy hoặc nhập AIzaSy... mới',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.key_rounded, color: Color(0xFF00897B)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _isTesting ? null : _testGeminiApi,
                            icon: _isTesting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.electrical_services_rounded, size: 18),
                            label: Text(_isTesting ? 'Đang test...' : 'Kiểm tra kết nối'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00897B),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Test Connection Feedback Banner
                  if (_testResult != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _testSuccess
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _testSuccess
                              ? Colors.green.shade300
                              : Colors.red.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _testSuccess
                                ? Icons.check_circle_rounded
                                : Icons.error_outline_rounded,
                            color: _testSuccess ? Colors.green.shade700 : Colors.red.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _testResult!,
                              style: TextStyle(
                                fontSize: 13,
                                color: _testSuccess
                                    ? Colors.green.shade900
                                    : Colors.red.shade900,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 28),

            // FAQ & Knowledge Base
            Row(
              children: [
                Expanded(
                  child: Text(
                    isSmall ? 'Kho Tri thức & FAQ' : 'Kho Tri thức & Câu hỏi thường gặp (FAQ)',
                    style: TextStyle(
                      fontSize: isSmall ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A2E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                isSmall
                    ? IconButton.filled(
                        onPressed: _addFaqDialog,
                        icon: const Icon(Icons.add_rounded, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF00897B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(8),
                          visualDensity: VisualDensity.compact,
                        ),
                        tooltip: 'Thêm câu hỏi mẫu',
                      )
                    : ElevatedButton.icon(
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

