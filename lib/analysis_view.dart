import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'core/theme/app_theme.dart';
import 'history_view.dart';
import 'database_view.dart';
import 'login_view.dart';
import 'models/scan_record.dart';

class AnalysisView extends StatefulWidget {
  const AnalysisView({super.key});

  @override
  State<AnalysisView> createState() => _AnalysisViewState();
}

class _AnalysisViewState extends State<AnalysisView> {
  int _selectedIndex = 0;

  // Shared scan history — passed to HistoryView
  final List<ScanRecord> _scanHistory = [];

  // Current scan state
  bool _isScanning = false;
  String? _fileName;
  String? _filePath;
  bool _isPdf = false;
  String _ocrText = '';
  int _blockCount = 0;
  String _errorMessage = '';
  bool _ocrComplete = false;

  static const String _ocrServerUrlEnv = String.fromEnvironment(
    'OCR_SERVER_URL',
    defaultValue: '',
  );

  static String get _backendUrl {
    final base = _ocrServerUrlEnv.isNotEmpty
        ? _ocrServerUrlEnv
        : (kDebugMode ? 'http://localhost:3001' : '');
    return base.isEmpty ? '/api/upload' : '$base/api/upload';
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      // PDF now included alongside images
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    setState(() {
      _fileName = file.name;
      _filePath = file.path;
      _isPdf = file.extension?.toLowerCase() == 'pdf';
      _ocrText = '';
      _blockCount = 0;
      _errorMessage = '';
      _ocrComplete = false;
    });
  }

  Future<void> _startScan() async {
    if (_filePath == null) return;

    setState(() {
      _isScanning = true;
      _errorMessage = '';
      _ocrText = '';
      _ocrComplete = false;
    });

    try {
      final request = http.MultipartRequest('POST', Uri.parse(_backendUrl));
      request.files.add(await http.MultipartFile.fromPath('document', _filePath!));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final extractedText = data['full_text'] ?? '';
        final blockCount = data['block_count'] ?? 0;

        // Format date nicely
        final now = DateTime.now();
        final dateStr =
            '${now.day} ${_monthName(now.month)} ${now.year}  ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

        // Save to history
        final record = ScanRecord(
          fileName: _fileName!,
          scannedDate: dateStr,
          extractedText: extractedText,
          blockCount: blockCount,
          isPdf: _isPdf,
        );

        setState(() {
          _isScanning = false;
          _ocrText = extractedText;
          _blockCount = blockCount;
          _ocrComplete = true;
          _scanHistory.add(record); // ← adds to shared history list
        });
      } else {
        setState(() {
          _isScanning = false;
          _errorMessage = 'Server error: ${response.statusCode}';
        });
      }
    } on TimeoutException {
      setState(() {
        _isScanning = false;
        _errorMessage = 'Request timed out while contacting OCR server.';
      });
    } on http.ClientException {
      setState(() {
        _isScanning = false;
        _errorMessage = 'Network error while contacting OCR server.';
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  String _monthName(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month];
  }

  void _deleteHistoryItem(int index) {
    setState(() => _scanHistory.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBrand,
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 260,
            color: const Color(0xFF090C10),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shield_rounded, color: AppColors.accentNeon, size: 28),
                    SizedBox(width: 12),
                    Text("FAIRSCAN AI",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 48),
                _sidebarItem(Icons.analytics_rounded, "Analyze Document", 0),
                _sidebarItem(Icons.history_rounded, "Scan History", 1),
                _sidebarItem(Icons.gavel_rounded, "Legal Database", 2),
                const Spacer(),
                const Divider(color: Colors.white10, height: 40),
                _sidebarItem(Icons.account_circle_outlined, "Prarthana Upadhyaya", 3),
                _sidebarItem(Icons.logout_rounded, "Sign Out", 4),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildAnalyzeView();
      case 1:
        // Pass real history + delete callback
        return HistoryView(
          scanHistory: _scanHistory,
          onDelete: _deleteHistoryItem,
        );
      case 2:
        return const DatabaseView();
      default:
        return _buildAnalyzeView();
    }
  }

  Widget _buildAnalyzeView() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Expanded(
                  flex: _ocrComplete ? 1 : 3,
                  child: _buildUploadBox(),
                ),
                if (_ocrComplete) ...[
                  const SizedBox(height: 16),
                  Expanded(flex: 2, child: _buildOcrResultBox()),
                ],
              ],
            ),
          ),
          const SizedBox(width: 32),
          Container(
            width: 400,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: _buildAnalysisPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadBox() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            if (_fileName == null)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_upload_outlined,
                        size: 80,
                        color: AppColors.secondaryBrand.withValues(alpha: 0.2)),
                    const SizedBox(height: 16),
                    const Text("Drop contract or PDF here",
                        style: TextStyle(fontSize: 18, color: AppColors.secondaryBrand)),
                    const SizedBox(height: 8),
                    // Updated to mention PDF
                    const Text("Supports JPG · PNG · WEBP · PDF",
                        style: TextStyle(fontSize: 13, color: AppColors.secondaryBrand)),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _pickFile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentNeon,
                        foregroundColor: AppColors.primaryBrand,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                      ),
                      child: const Text("BROWSE FILES",
                          style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isPdf ? Icons.picture_as_pdf : Icons.description_rounded,
                      size: 80,
                      color: Colors.white24,
                    ),
                    const SizedBox(height: 12),
                    Text(_fileName!,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white)),
                    const SizedBox(height: 6),
                    Text(
                      _isScanning
                          ? _isPdf
                              ? "Converting PDF pages and extracting text..."
                              : "Extracting text..."
                          : _ocrComplete
                              ? "✅ Text extracted — $_blockCount blocks"
                              : "Ready to scan",
                      style: TextStyle(
                          color: _isScanning || _ocrComplete
                              ? AppColors.accentNeon
                              : AppColors.secondaryBrand),
                    ),
                    if (_errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(_errorMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppColors.danger, fontSize: 12)),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _isScanning ? null : _pickFile,
                      child: const Text("Choose different file",
                          style: TextStyle(
                              color: AppColors.secondaryBrand, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            if (_isScanning)
              Positioned.fill(
                child: Container(
                  color: AppColors.primaryBrand.withValues(alpha: 0.6),
                  child: Lottie.asset('assets/animations/scan_effect.json',
                      fit: BoxFit.contain),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOcrResultBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentNeon.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.text_snippet_outlined,
                  color: AppColors.accentNeon, size: 16),
              const SizedBox(width: 8),
              const Text("Extracted Text",
                  style: TextStyle(
                      color: AppColors.accentNeon,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accentNeon.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$_blockCount blocks',
                    style: const TextStyle(
                        color: AppColors.accentNeon,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                _ocrText,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  height: 1.7,
                  fontFamily: 'Courier New',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.accentNeon.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon,
            color: isSelected ? AppColors.accentNeon : AppColors.secondaryBrand,
            size: 22),
        title: Text(label,
            style: TextStyle(
                color: isSelected ? Colors.white : AppColors.secondaryBrand,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
        onTap: () {
          if (label == "Sign Out") {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginView()),
              (route) => false,
            );
          } else {
            setState(() => _selectedIndex = index);
          }
        },
      ),
    );
  }

  Widget _buildAnalysisPanel() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Audit Results",
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
                const Text("CCPA 2023 Compliance Check",
                    style: TextStyle(
                        color: AppColors.secondaryBrand, fontSize: 14)),
                const SizedBox(height: 32),
                _violationCard(
                    "Basket Sneaking",
                    "Clause 4.2",
                    "The AI detected that an item was automatically added to the user's cart without explicit consent. This violates the 'Transparency in E-commerce' guidelines under Section 4.",
                    AppColors.danger),
                const SizedBox(height: 16),
                _violationCard(
                    "Forced Continuity",
                    "Clause 7.1",
                    "The subscription terms fail to provide a clear 'opt-out' path after the trial period ends. AI suggests adding a prominent 'Cancel Anytime' button in the UI.",
                    AppColors.warning),
              ],
            ),
          ),
        ),
        _actionButton(),
      ],
    );
  }

  Widget _actionButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: ElevatedButton(
        onPressed: (_fileName != null && !_isScanning) ? _startScan : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentNeon,
          foregroundColor: AppColors.primaryBrand,
          disabledBackgroundColor: AppColors.border,
          minimumSize: const Size.fromHeight(64),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _isScanning
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                    color: AppColors.primaryBrand, strokeWidth: 2))
            : const Text("INITIALIZE SCAN",
                style: TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }

  Widget _violationCard(
      String title, String subtitle, String explanation, Color color) {
    return ExpansionTile(
      backgroundColor: color.withValues(alpha: 0.05),
      collapsedBackgroundColor: color.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withValues(alpha: 0.1))),
      collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withValues(alpha: 0.1))),
      iconColor: color,
      collapsedIconColor: color,
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8))),
      leading: Icon(Icons.warning_amber_rounded, color: color),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(explanation,
              style: const TextStyle(
                  color: AppColors.secondaryBrand, fontSize: 13, height: 1.5)),
        ),
      ],
    );
  }
}