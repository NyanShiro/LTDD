import 'dart:async';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'exam_docx_importer.dart';
import 'exam_api_client.dart';
import 'exam_workflow.dart';

void main() => runApp(MyApp(apiClient: ExamApiClient()));

const _navy = Color(0xFF0C1E35);
const _blue = Color(0xFF2160F5);
const _canvas = Color(0xFFF4F7FC);
const _muted = Color(0xFF8FA1BC);

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.apiClient});

  final ExamApiClient? apiClient;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniTest | Assessment Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _canvas,
        colorScheme: ColorScheme.fromSeed(seedColor: _blue),
        fontFamily: 'Manrope',
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111B31),
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111B31),
          ),
          bodyMedium: TextStyle(color: Color(0xFF62748F)),
        ),
      ),
      home: ExamDashboard(apiClient: apiClient),
    );
  }
}

class Exam {
  const Exam({
    required this.id,
    required this.subject,
    required this.title,
    required this.code,
    required this.duration,
    required this.questionCount,
    required this.questions,
    required this.date,
    required this.status,
    required this.accent,
    required this.tint,
  });

  final String subject;
  final String title;
  final String code;
  final int duration;
  final int questionCount;
  final List<ExamQuestionPreview> questions;
  final String date;
  final String status;
  final Color accent;
  final Color tint;

  final int id;
}

class ExamDashboard extends StatefulWidget {
  const ExamDashboard({super.key, this.apiClient});

  final ExamApiClient? apiClient;

  @override
  State<ExamDashboard> createState() => _ExamDashboardState();
}

class _ExamDashboardState extends State<ExamDashboard> {
  final _searchController = TextEditingController();
  final _titleController = TextEditingController();
  final _subjectController = TextEditingController();
  final _codeController = TextEditingController();
  final _durationController = TextEditingController(text: '60');
  final List<Exam> _exams = [];
  final List<ExamAttempt> _attempts = [];
  PlatformFile? _selectedFile;
  ExamDocxImportResult? _previewResult;
  String _filter = 'Tất cả';
  String _section = 'Quản lý đề thi';

  @override
  void initState() {
    super.initState();
    if (widget.apiClient != null) unawaited(_loadExams());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _subjectController.dispose();
    _codeController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _chooseExamFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['docx'],
    );
    if (files.isEmpty || !mounted) return;

    final file = files.first;
    final fileSize = await file.length() ?? 0;
    if (!mounted) return;
    if (fileSize > 20 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kích thước file tối đa là 20 MB')),
      );
      return;
    }
    setState(() {
      _selectedFile = file;
      _previewResult = null;
      _titleController.text = file.name.replaceFirst(
        RegExp(r'\.docx$', caseSensitive: false),
        '',
      );
      _subjectController.text = 'Chưa phân loại';
      _codeController.text = 'EX-${DateTime.now().millisecondsSinceEpoch}';
    });
  }

  void _discardSelectedFile() {
    setState(() {
      _selectedFile = null;
      _previewResult = null;
      _titleController.clear();
      _subjectController.clear();
      _codeController.clear();
      _durationController.text = '60';
    });
  }

  Future<void> _loadExams() async {
    try {
      final records = await widget.apiClient!.loadExams();
      if (!mounted) return;
      setState(() {
        _exams
          ..clear()
          ..addAll(records.map(_mapStoredExam));
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tải được đề thi từ database: $error')),
      );
    }
  }

  Exam _mapStoredExam(StoredExam record) => Exam(
    id: record.id,
    subject: record.subject,
    title: record.title,
    code: record.code,
    duration: record.durationMinutes,
    questionCount: record.questions.length,
    questions: record.questions,
    date: record.creationTime.toString().split(' ').first,
    status: 'Đang mở',
    accent: _blue,
    tint: const Color(0xFFEAF1F9),
  );

  Future<void> _previewExamFile() async {
    final file = _selectedFile;
    if (file == null) return;
    final result = await _parseSelectedFile(file, allowInvalid: true);
    if (result == null || !mounted) return;
    final fileSize = await file.length() ?? 0;
    if (!mounted) return;
    final editedResult = await showDialog<ExamDocxImportResult>(
      context: context,
      builder: (context) => _ExamPreviewDialog(
        fileName: file.name,
        fileSize: fileSize,
        initialResult: result,
      ),
    );
    if (editedResult == null || !mounted) return;
    setState(() => _previewResult = editedResult);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          editedResult.isValid
              ? 'Đã lưu chỉnh sửa. Có thể import đề thi.'
              : 'Đã lưu bản sửa nhưng còn ${editedResult.validationErrors.length} lỗi cần xử lý.',
        ),
      ),
    );
  }

  Future<void> _downloadExamTemplate() async {
    try {
      final location = await FilePicker.saveFile(
        fileName: 'Mau_de_thi_chuan.docx',
        bytes: ExamDocxImporter.createTemplate(),
        mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        type: FileType.custom,
        allowedExtensions: const ['docx'],
      );
      if (!mounted || location == null) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã tải file mẫu đề thi.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể tạo file mẫu lúc này.')),
      );
    }
  }

  Future<ExamDocxImportResult?> _parseSelectedFile(
    PlatformFile file, {
    bool allowInvalid = false,
  }) async {
    try {
      final bytes = await file.xFile.readAsBytes();
      return ExamDocxImporter.parse(bytes, allowInvalid: allowInvalid);
    } on FormatException catch (error) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File DOCX không hợp lệ hoặc bị lỗi.')),
      );
    }
    return null;
  }

  Future<void> _importExamFile() async {
    final file = _selectedFile;
    final title = _titleController.text.trim();
    final subject = _subjectController.text.trim();
    final code = _codeController.text.trim();
    final duration = int.tryParse(_durationController.text.trim());
    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn file .docx trước')),
      );
      return;
    }
    if (title.isEmpty ||
        subject.isEmpty ||
        code.isEmpty ||
        duration == null ||
        duration < 1 ||
        duration > 600) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng nhập đủ thông tin và thời lượng từ 1 đến 600 phút.',
          ),
        ),
      );
      return;
    }

    final result = _previewResult ?? await _parseSelectedFile(file);
    if (result == null || !mounted) return;
    if (!result.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chưa thể import: ${result.validationErrors.first}'),
        ),
      );
      return;
    }
    final apiClient = widget.apiClient;
    if (apiClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể import vì chưa kết nối database.'),
        ),
      );
      return;
    }

    late final int examId;
    try {
      examId = await apiClient.importExam(
        title: title,
        subject: subject,
        code: code,
        durationMinutes: duration,
        originalFileName: file.name,
        fileBytes: await file.xFile.readAsBytes(),
        questions: result.questions,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không lưu được đề vào database: $error')),
      );
      return;
    }
    if (!mounted) return;

    setState(() {
      _exams.insert(
        0,
        Exam(
          id: examId,
          subject: subject,
          title: title,
          code: code,
          duration: duration,
          questionCount: result.questionCount,
          questions: result.questions,
          date: DateTime.now().toString().split(' ').first,
          status: 'Đang mở',
          accent: _blue,
          tint: const Color(0xFFEAF1F9),
        ),
      );
      _selectedFile = null;
      _previewResult = null;
      _section = 'Quản lý đề thi';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đã import "$title" với ${result.questionCount} câu hỏi.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1000;
        return Scaffold(
          drawer: isWide
              ? null
              : Drawer(
                  width: 280,
                  backgroundColor: _navy,
                  child: _Sidebar(
                    selected: _section,
                    onSelected: _selectSection,
                  ),
                ),
          body: Row(
            children: [
              if (isWide)
                SizedBox(
                  width: 248,
                  child: _Sidebar(
                    selected: _section,
                    onSelected: _selectSection,
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    _TopBar(isWide: isWide, section: _section),
                    Expanded(
                      child: _section == 'Danh sách đề thi'
                          ? _buildExamList(isWide)
                          : _section == 'Lịch sử làm bài'
                          ? _buildHistorySection()
                          : _section == 'Import đề thi'
                          ? _buildImportSection()
                          : _section == 'Quản lý đề thi'
                          ? _buildManageExamsSection(isWide)
                          : _buildEmptySection(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _selectSection(String section) {
    setState(() => _section = section);
    Navigator.of(context).maybePop();
  }

  Widget _buildExamList(bool isWide) {
    final query = _searchController.text.trim().toLowerCase();
    final visibleExams = _exams.where((exam) {
      final matchesFilter =
          _filter == 'Tất cả' ||
          (_filter == 'Đang mở'
              ? exam.status == 'Đang mở'
              : exam.status == 'Đã hoàn thành');
      final matchesQuery =
          query.isEmpty ||
          exam.title.toLowerCase().contains(query) ||
          exam.code.toLowerCase().contains(query) ||
          exam.subject.toLowerCase().contains(query);
      return matchesFilter && matchesQuery;
    }).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 40 : 20,
        vertical: isWide ? 38 : 26,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PageHeading(
                isWide: isWide,
                title: 'Danh sách đề thi',
                subtitle: 'Theo dõi lịch thi và bắt đầu bài làm của bạn.',
              ),
              const SizedBox(height: 34),
              _SearchAndFilters(
                controller: _searchController,
                filter: _filter,
                onFilterChanged: (value) => setState(() => _filter = value),
                onSearchChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),
              if (visibleExams.isEmpty)
                const _EmptyExams()
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1100
                        ? 3
                        : constraints.maxWidth >= 680
                        ? 2
                        : 1;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: visibleExams.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisExtent: 354,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                      ),
                      itemBuilder: (context, index) => _ExamCard(
                        exam: visibleExams[index],
                        onPressed: () => _openExam(visibleExams[index]),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImportSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(40, 32, 40, 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1380),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DÀNH CHO GIẢNG VIÊN',
                style: TextStyle(
                  color: _blue,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Import đề thi từ Word',
                style: TextStyle(
                  color: Color(0xFF101C36),
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Đọc và kiểm tra câu hỏi trong file .docx, sau đó thêm đề vào danh sách quản lý.',
                style: TextStyle(color: Color(0xFF6A7C95), fontSize: 17),
              ),
              const SizedBox(height: 36),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      height: 420,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F7FB),
                        border: Border.all(
                          color: const Color(0xFF9DC7F7),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF1F9),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: const Icon(
                                Icons.upload_file_outlined,
                                size: 52,
                                color: Color(0xFF2F69EF),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Chọn file từ máy tính',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF212F46),
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Chỉ hỗ trợ: docx • Tối đa 20 MB',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF7A8CA4),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 26),
                            SizedBox(
                              width: 220,
                              child: ElevatedButton.icon(
                                onPressed: _chooseExamFile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2160F5),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 17,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.file_open_outlined),
                                label: Text(
                                  _selectedFile == null
                                      ? 'Chọn file'
                                      : 'Chọn file khác',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            if (_selectedFile != null) ...[
                              const SizedBox(height: 14),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 340,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _selectedFile!.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Color(0xFF34435B),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Bỏ file đã chọn',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: _discardSelectedFile,
                                      icon: const Icon(Icons.close),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 30),
                  SizedBox(
                    width: 360,
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(26, 24, 26, 22),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0C1E35),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A2E48),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.info_outline,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'Quy chuẩn file',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 18),
                              const _UploadChecklistItem(
                                text: 'Câu hỏi đặt trong tag <ch>...</ch>',
                              ),
                              const _UploadChecklistItem(
                                text: 'Lựa chọn đặt trong tag <ctrl>...</ctrl>',
                              ),
                              const _UploadChecklistItem(
                                text: 'Đáp án đặt trong tag <da>...</da>',
                              ),
                              const _UploadChecklistItem(
                                text: 'Hình ảnh ở định dạng PNG/JPG',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: _downloadExamTemplate,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 18,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFFD7DFEC),
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.download_outlined,
                                    color: Color(0xFF2160F5),
                                    size: 30,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          'Tải file mẫu',
                                          style: TextStyle(
                                            color: Color(0xFF1A2E48),
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          'Mẫu đề thi chuẩn.docx',
                                          style: TextStyle(
                                            color: Color(0xFF6B7F9B),
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 14,
                children: [
                  _ImportField(
                    label: 'Tên đề thi',
                    controller: _titleController,
                    width: 300,
                  ),
                  _ImportField(
                    label: 'Môn học',
                    controller: _subjectController,
                    width: 240,
                  ),
                  _ImportField(
                    label: 'Mã đề',
                    controller: _codeController,
                    width: 220,
                  ),
                  _ImportField(
                    label: 'Thời lượng (phút)',
                    controller: _durationController,
                    width: 200,
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  SizedBox(
                    width: 220,
                    child: OutlinedButton.icon(
                      onPressed: _selectedFile == null
                          ? null
                          : _previewExamFile,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF52657F),
                        backgroundColor: const Color(0xFFF2F5F9),
                        side: const BorderSide(color: Color(0xFFD8E0EB)),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text(
                        'Xem trước',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  SizedBox(
                    width: 220,
                    child: ElevatedButton.icon(
                      onPressed: _selectedFile == null ? null : _importExamFile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2160F5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.check),
                      label: const Text(
                        'Import đề thi',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManageExamsSection(bool isWide) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(40, 32, 40, 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1380),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DÀNH CHO GIẢNG VIÊN',
                style: TextStyle(
                  color: _blue,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Quản lý đề thi',
                style: TextStyle(
                  color: Color(0xFF101C36),
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Quản lý các đề thi đã import trong phiên hiện tại.',
                style: TextStyle(color: Color(0xFF6A7C95), fontSize: 17),
              ),
              const SizedBox(height: 30),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 200,
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _section = 'Import đề thi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2160F5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 22),
                    label: const Text(
                      'Import đề thi',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_exams.isEmpty)
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 320),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7FB),
                    border: Border.all(color: const Color(0xFFD3DDEB)),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.description_outlined,
                          size: 56,
                          color: Color(0xFF8FA5BE),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'Chưa có đề thi đã import',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF1E2C3D),
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Danh sách chưa có dữ liệu cục bộ.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF73839A),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () =>
                              setState(() => _section = 'Import đề thi'),
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('Import đề thi đầu tiên'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isWide ? 20 : 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFD3DDEB)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      for (var index = 0; index < _exams.length; index++) ...[
                        if (index > 0) const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: _exams[index].tint,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.description_outlined,
                                  color: _exams[index].accent,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _exams[index].title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E2C3D),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_exams[index].subject} · ${_exams[index].code}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: _muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isWide) ...[
                                const SizedBox(width: 20),
                                Text(
                                  '${_exams[index].questionCount} câu · ${_exams[index].duration} phút',
                                  style: const TextStyle(
                                    color: Color(0xFF52657F),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                              const SizedBox(width: 16),
                              Icon(
                                Icons.circle,
                                size: 9,
                                color: _exams[index].status == 'Đang mở'
                                    ? const Color(0xFF00A66A)
                                    : const Color(0xFFED8B00),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _exams[index].status,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
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
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(40, 32, 40, 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PageHeading(
                title: 'Lịch sử làm bài',
                subtitle: 'Các bài thi đã nộp trong phiên hiện tại.',
              ),
              const SizedBox(height: 24),
              if (_attempts.isEmpty)
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 320),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7FB),
                    border: Border.all(color: const Color(0xFFD3DDEB)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.menu_book_outlined,
                          size: 56,
                          color: Color(0xFF8FA5BE),
                        ),
                        SizedBox(height: 24),
                        Text(
                          'Chưa có bài làm',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF1E2C3D),
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Bài thi đã nộp sẽ xuất hiện tại đây.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFD3DDEB)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < _attempts.length;
                        index++
                      ) ...[
                        if (index > 0) const Divider(height: 1),
                        _AttemptHistoryRow(
                          attempt: _attempts[index],
                          onReview: () => _reviewAttempt(_attempts[index]),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySection() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_stories_outlined, size: 42, color: _muted),
            const SizedBox(height: 16),
            Text(_section, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Nội dung sẽ được hiển thị tại đây.'),
          ],
        ),
      ),
    );
  }

  Future<void> _openExam(Exam exam) async {
    if (exam.status != 'Đang mở') return;
    final attempt = await Navigator.of(context).push<ExamAttempt>(
      MaterialPageRoute(
        builder: (context) => ExamTakingPage(
          examId: exam.id,
          title: exam.title,
          code: exam.code,
          durationMinutes: exam.duration,
          questions: exam.questions,
        ),
      ),
    );
    if (attempt == null || !mounted) return;
    setState(() => _attempts.insert(0, attempt));
    await _showAttemptResult(attempt);
  }

  Future<void> _showAttemptResult(ExamAttempt attempt) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đã nộp bài'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${attempt.scorePercent}/100 điểm',
              style: const TextStyle(
                color: Color(0xFF2160F5),
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${attempt.correctAnswers}/${attempt.questions.length} câu đúng · ${attempt.answeredQuestions} câu đã trả lời',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Đóng'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _reviewAttempt(attempt);
            },
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Xem lại bài'),
          ),
        ],
      ),
    );
  }

  void _reviewAttempt(ExamAttempt attempt) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => ExamReviewPage(attempt: attempt),
      ),
    );
  }
}

class _AttemptHistoryRow extends StatelessWidget {
  const _AttemptHistoryRow({required this.attempt, required this.onReview});

  final ExamAttempt attempt;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final submittedAt = attempt.submittedAt;
    final dateLabel =
        '${submittedAt.day.toString().padLeft(2, '0')}/${submittedAt.month.toString().padLeft(2, '0')}/${submittedAt.year} ${submittedAt.hour.toString().padLeft(2, '0')}:${submittedAt.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.assignment_turned_in_outlined,
              color: _blue,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attempt.examTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1E2C3D),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$dateLabel · ${attempt.correctAnswers}/${attempt.questions.length} câu đúng',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${attempt.scorePercent}/100',
            style: const TextStyle(
              color: Color(0xFF2160F5),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Xem lại bài làm',
            onPressed: onReview,
            icon: const Icon(Icons.visibility_outlined),
          ),
        ],
      ),
    );
  }
}

class _ExamPreviewDialog extends StatefulWidget {
  const _ExamPreviewDialog({
    required this.fileName,
    required this.fileSize,
    required this.initialResult,
  });

  final String fileName;
  final int fileSize;
  final ExamDocxImportResult initialResult;

  @override
  State<_ExamPreviewDialog> createState() => _ExamPreviewDialogState();
}

class _ExamPreviewDialogState extends State<_ExamPreviewDialog> {
  late List<ExamQuestionPreview> _questions;
  late ExamDocxImportResult _draftResult;
  late final TextEditingController _rawTextController;

  @override
  void initState() {
    super.initState();
    _questions = List.of(widget.initialResult.questions);
    _draftResult = widget.initialResult;
    _rawTextController = TextEditingController(
      text: widget.initialResult.rawText,
    );
  }

  @override
  void dispose() {
    _rawTextController.dispose();
    super.dispose();
  }

  void _updateQuestion(int index, ExamQuestionPreview question) {
    setState(() {
      _questions[index] = question;
      _draftResult = revalidateExamEdits(widget.initialResult, _questions);
    });
  }

  void _updateRawText(String text) {
    setState(() {
      _draftResult = revalidateExamEdits(
        widget.initialResult,
        const [],
        rawText: text,
      );
      if (_draftResult.questions.isNotEmpty) {
        _questions = List.of(_draftResult.questions);
      }
    });
  }

  Widget _buildValidationSummary() {
    final errors = _draftResult.validationErrors;
    final color = errors.isEmpty
        ? const Color(0xFF00875A)
        : const Color(0xFF805B00);
    final background = errors.isEmpty
        ? const Color(0xFFE9FAF3)
        : const Color(0xFFFFF7E8);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            errors.isEmpty
                ? 'Đề hợp lệ'
                : '${errors.length} lỗi/cảnh báo cần kiểm tra',
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
          for (final error in errors.take(3))
            Text('• $error', style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildQuestionEditor(int index) {
    final question = _questions[index];
    final availableAnswer =
        const {'A', 'B', 'C', 'D'}.contains(question.correctOption)
        ? question.correctOption
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD7DFEC)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Câu ${question.number}',
            style: const TextStyle(
              color: Color(0xFF1E2C3D),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: ValueKey('prompt-${question.number}'),
            initialValue: question.prompt,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Nội dung câu hỏi',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            onChanged: (value) =>
                _updateQuestion(index, question.copyWith(prompt: value)),
          ),
          const SizedBox(height: 12),
          for (final option in const ['A', 'B', 'C', 'D']) ...[
            TextFormField(
              key: ValueKey('option-${question.number}-$option'),
              initialValue: question.options[option] ?? '',
              decoration: InputDecoration(
                labelText: 'Lựa chọn $option',
                border: const OutlineInputBorder(),
                prefixText: '$option.  ',
              ),
              onChanged: (value) {
                final options = Map<String, String>.of(question.options)
                  ..[option] = value;
                _updateQuestion(index, question.copyWith(options: options));
              },
            ),
            const SizedBox(height: 10),
          ],
          DropdownButtonFormField<String>(
            key: ValueKey('answer-${question.number}'),
            initialValue: availableAnswer,
            decoration: const InputDecoration(
              labelText: 'Đáp án đúng',
              border: OutlineInputBorder(),
            ),
            hint: const Text('Chọn đáp án'),
            items: const ['A', 'B', 'C', 'D']
                .map(
                  (option) => DropdownMenuItem(
                    value: option,
                    child: Text('Đáp án $option'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              _updateQuestion(index, question.copyWith(correctOption: value));
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width - 48)
        .clamp(320.0, 760.0)
        .toDouble();
    final height = (MediaQuery.sizeOf(context).height - 180)
        .clamp(360.0, 680.0)
        .toDouble();

    return AlertDialog(
      title: const Text('Chỉnh sửa đề thi'),
      content: SizedBox(
        width: width,
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.fileName} · ${_draftResult.questionCount} câu · ${(widget.fileSize / (1024 * 1024)).toStringAsFixed(2)} MB',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (_draftResult.imageCount > 0) ...[
              const SizedBox(height: 4),
              Text('${_draftResult.imageCount} ảnh trong file'),
            ],
            const SizedBox(height: 12),
            _buildValidationSummary(),
            const SizedBox(height: 12),
            Expanded(
              child: _questions.isEmpty
                  ? TextField(
                      controller: _rawTextController,
                      expands: true,
                      minLines: null,
                      maxLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        labelText: 'Nội dung đề thi',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: _updateRawText,
                    )
                  : ListView.separated(
                      itemCount: _questions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _buildQuestionEditor(index),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, _draftResult),
          icon: const Icon(Icons.save_outlined),
          label: const Text('Lưu chỉnh sửa'),
        ),
      ],
    );
  }
}

class _UploadChecklistItem extends StatelessWidget {
  const _UploadChecklistItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportField extends StatelessWidget {
  const _ImportField({
    required this.label,
    required this.controller,
    required this.width,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final double width;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _navy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 72,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.menu_book, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'UniTest',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'ASSESSMENT HUB',
                        style: TextStyle(
                          color: Color(0xFF8EC3FF),
                          fontSize: 10,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFF26384D)),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 34, 24, 12),
            child: Text('H Ọ C  T Ậ P', style: _sectionLabel),
          ),
          _NavItem(
            icon: Icons.grid_view_rounded,
            label: 'Danh sách đề thi',
            active: selected == 'Danh sách đề thi',
            onTap: () => onSelected('Danh sách đề thi'),
          ),
          _NavItem(
            icon: Icons.menu_book_outlined,
            label: 'Lịch sử làm bài',
            active: selected == 'Lịch sử làm bài',
            onTap: () => onSelected('Lịch sử làm bài'),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 32, 24, 12),
            child: Text('G I Ả N G  V I Ê N', style: _sectionLabel),
          ),
          _NavItem(
            icon: Icons.upload_file_outlined,
            label: 'Import đề thi',
            active: selected == 'Import đề thi',
            onTap: () => onSelected('Import đề thi'),
          ),
          _NavItem(
            icon: Icons.description_outlined,
            label: 'Quản lý đề thi',
            active: selected == 'Quản lý đề thi',
            onTap: () => onSelected('Quản lý đề thi'),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2D43),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2C4058)),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Học kỳ', style: TextStyle(color: _muted)),
                      Text(
                        'HK2 · 2024–25',
                        style: TextStyle(
                          color: Color(0xFF8EC3FF),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                    child: const LinearProgressIndicator(
                      value: .75,
                      minHeight: 6,
                      backgroundColor: Color(0xFF394B60),
                      color: Color(0xFF3284FF),
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

const _sectionLabel = TextStyle(
  color: Color(0xFF71829B),
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.2,
);

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: SizedBox(
        height: 48,
        child: Material(
          color: active ? _blue : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: active ? Colors.white : const Color(0xFF95A5BB),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      color: active ? Colors.white : const Color(0xFF95A5BB),
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.isWide, required this.section});

  final bool isWide;
  final String section;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: EdgeInsets.symmetric(horizontal: isWide ? 32 : 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE1E7F0))),
      ),
      child: Row(
        children: [
          if (!isWide)
            Builder(
              builder: (context) => IconButton(
                onPressed: Scaffold.of(context).openDrawer,
                icon: const Icon(Icons.menu),
                tooltip: 'Mở menu',
              ),
            ),
          if (isWide) ...[
            const Icon(Icons.home_outlined, color: _muted, size: 20),
            const SizedBox(width: 14),
            const Text('/', style: TextStyle(color: _muted, fontSize: 18)),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Text(
              isWide ? 'Không gian học tập' : section,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFF34435B),
                fontSize: isWide ? 15 : 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Thông tin',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('UniTest · Assessment Hub')),
            ),
            icon: const Icon(Icons.info_outline, color: _muted),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 30, color: const Color(0xFFE1E7F0)),
          const SizedBox(width: 16),
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF347EFF), Color(0xFF5147F5)],
              ),
            ),
            child: const Text(
              'NA',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (isWide) ...[
            const SizedBox(width: 12),
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nguyễn Minh Anh',
                  style: TextStyle(
                    color: Color(0xFF202C40),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Sinh viên',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(width: 10),
            const Icon(Icons.keyboard_arrow_down, color: _muted),
          ],
        ],
      ),
    );
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({
    this.isWide = true,
    this.title = 'Danh sách đề thi',
    this.subtitle = 'Theo dõi lịch thi và bắt đầu bài làm của bạn.',
  });

  final bool isWide;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 16,
      children: [
        SizedBox(
          width: isWide ? 700 : 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'KHÔNG GIAN HỌC TẬP',
                style: TextStyle(
                  color: _blue,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontSize: isWide ? 30 : 26),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 15, color: Color(0xFF6E809B)),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF5FF),
            border: Border.all(color: const Color(0xFFD6E6FF)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, color: Color(0xFF3284FF), size: 10),
              SizedBox(width: 10),
              Text(
                '0 bài thi đang mở',
                style: TextStyle(
                  color: _blue,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.controller,
    required this.filter,
    required this.onFilterChanged,
    required this.onSearchChanged,
  });

  final TextEditingController controller;
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDDE5F0)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          final search = TextField(
            controller: controller,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Tìm theo tên đề thi hoặc mã học phần...',
              hintStyle: const TextStyle(color: Color(0xFF96A0AF)),
              prefixIcon: const Icon(Icons.search, color: _muted),
              filled: true,
              fillColor: const Color(0xFFF6F8FB),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _blue),
              ),
            ),
          );
          final filters = Wrap(
            spacing: 3,
            children: ['Tất cả', 'Đang mở', 'Đã hoàn thành'].map((value) {
              final active = filter == value;
              return TextButton(
                onPressed: () => onFilterChanged(value),
                style: TextButton.styleFrom(
                  foregroundColor: active ? const Color(0xFF172033) : _muted,
                  backgroundColor: active ? Colors.white : Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [search, const SizedBox(height: 6), filters],
            );
          }
          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8FB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: filters,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.exam, required this.onPressed});

  final Exam exam;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final active = exam.status == 'Đang mở';
    final upcoming = exam.status == 'Sắp diễn ra';
    final statusColor = active
        ? const Color(0xFF00A66A)
        : upcoming
        ? const Color(0xFFED8B00)
        : const Color(0xFF72839D);
    final statusFill = active
        ? const Color(0xFFE9FAF3)
        : upcoming
        ? const Color(0xFFFFF7E8)
        : const Color(0xFFF0F3F7);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDCE4EF)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 6, color: exam.accent),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: exam.tint,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.description_outlined,
                          color: exam.accent,
                          size: 25,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: statusFill,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          exam.status,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    exam.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    exam.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF172033),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mã đề: ${exam.code}',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                  const Spacer(),
                  const Divider(height: 1, color: Color(0xFFE8EDF4)),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: _CardMeta(
                            icon: Icons.schedule,
                            text: '${exam.duration} phút',
                          ),
                        ),
                        Expanded(
                          child: _CardMeta(
                            icon: Icons.description_outlined,
                            text: '${exam.questionCount} câu',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE8EDF4)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ngày thi',
                              style: TextStyle(color: _muted, fontSize: 11),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              exam.date,
                              style: const TextStyle(
                                color: Color(0xFF34435B),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: active ? onPressed : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: active
                              ? _blue
                              : const Color(0xFFF0F3F7),
                          disabledBackgroundColor: const Color(0xFFF0F3F7),
                          foregroundColor: Colors.white,
                          disabledForegroundColor: _muted,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.chevron_right, size: 18),
                        label: Text(
                          active
                              ? 'Vào thi'
                              : exam.status == 'Đã hoàn thành'
                              ? 'Xem kết quả'
                              : 'Vào thi',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
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

class _CardMeta extends StatelessWidget {
  const _CardMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: _muted),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF34435B),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyExams extends StatelessWidget {
  const _EmptyExams();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 280),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFC9D6E6)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined, size: 42, color: _muted),
          SizedBox(height: 18),
          Text(
            'Chưa có đề thi',
            style: TextStyle(
              color: Color(0xFF202C40),
              fontWeight: FontWeight.w800,
              fontSize: 19,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Các đề thi được công bố sẽ hiển thị tại đây.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted),
          ),
        ],
      ),
    );
  }
}
