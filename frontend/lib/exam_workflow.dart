import 'dart:async';

import 'package:flutter/material.dart';

import 'exam_docx_importer.dart';

class ExamAttempt {
  ExamAttempt({
    required this.examId,
    required this.examTitle,
    required this.examCode,
    required List<ExamQuestionPreview> questions,
    required Map<int, String> selectedAnswers,
    required this.startedAt,
    required this.submittedAt,
  }) : questions = List.unmodifiable(questions),
       selectedAnswers = Map.unmodifiable(selectedAnswers);

  final int examId;
  final String examTitle;
  final String examCode;
  final List<ExamQuestionPreview> questions;
  final Map<int, String> selectedAnswers;
  final DateTime startedAt;
  final DateTime submittedAt;

  int get correctAnswers => questions
      .where(
        (question) =>
            selectedAnswers[question.number] == question.correctOption,
      )
      .length;

  int get answeredQuestions => selectedAnswers.length;

  int get scorePercent =>
      questions.isEmpty ? 0 : (correctAnswers * 100 / questions.length).round();

  Duration get elapsed => submittedAt.difference(startedAt);
}

class ExamTakingPage extends StatefulWidget {
  const ExamTakingPage({
    super.key,
    required this.examId,
    required this.title,
    required this.code,
    required this.durationMinutes,
    required this.questions,
  });

  final int examId;
  final String title;
  final String code;
  final int durationMinutes;
  final List<ExamQuestionPreview> questions;

  @override
  State<ExamTakingPage> createState() => _ExamTakingPageState();
}

class _ExamTakingPageState extends State<ExamTakingPage> {
  late final DateTime _startedAt;
  late int _remainingSeconds;
  final Map<int, String> _selectedAnswers = {};
  Timer? _timer;
  int _currentIndex = 0;

  ExamQuestionPreview get _currentQuestion => widget.questions[_currentIndex];

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _remainingSeconds = widget.durationMinutes * 60;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds <= 1) {
        setState(() => _remainingSeconds = 0);
        unawaited(_submit(timeExpired: true));
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  Future<void> _confirmExit() async {
    _timer?.cancel();
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thoát bài thi?'),
        content: const Text('Các câu trả lời hiện tại sẽ không được lưu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tiếp tục làm bài'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Thoát'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (shouldExit == true) {
      Navigator.pop(context);
    } else if (_remainingSeconds > 0) {
      _startTimer();
    }
  }

  Future<void> _submit({bool timeExpired = false}) async {
    if (!timeExpired) {
      _timer?.cancel();
      final unanswered = widget.questions.length - _selectedAnswers.length;
      final shouldSubmit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Nộp bài thi?'),
          content: Text(
            unanswered == 0
                ? 'Bạn đã trả lời tất cả câu hỏi. Xác nhận nộp bài?'
                : 'Còn $unanswered câu chưa trả lời. Bạn vẫn muốn nộp bài?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Làm tiếp'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Nộp bài'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (shouldSubmit != true) {
        if (_remainingSeconds > 0) _startTimer();
        return;
      }
    }

    _timer?.cancel();
    Navigator.of(context).pop(
      ExamAttempt(
        examId: widget.examId,
        examTitle: widget.title,
        examCode: widget.code,
        questions: widget.questions,
        selectedAnswers: _selectedAnswers,
        startedAt: _startedAt,
        submittedAt: DateTime.now(),
      ),
    );
  }

  String get _timeLabel {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final question = _currentQuestion;
    final selected = _selectedAnswers[question.number];
    final progress = (_currentIndex + 1) / widget.questions.length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Thoát bài thi',
          onPressed: _confirmExit,
          icon: const Icon(Icons.close),
        ),
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _remainingSeconds < 60
                  ? const Color(0xFFFFE9E8)
                  : const Color(0xFFEAF1F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _timeLabel,
              style: TextStyle(
                color: _remainingSeconds < 60
                    ? const Color(0xFFC63D36)
                    : const Color(0xFF1A2E48),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: progress, minHeight: 3),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      '${widget.code}  ·  Câu ${_currentIndex + 1}/${widget.questions.length}',
                      style: const TextStyle(
                        color: Color(0xFF71829A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (
                          var index = 0;
                          index < widget.questions.length;
                          index++
                        )
                          _QuestionNumberButton(
                            number: index + 1,
                            isCurrent: index == _currentIndex,
                            isAnswered: _selectedAnswers.containsKey(
                              widget.questions[index].number,
                            ),
                            onPressed: () =>
                                setState(() => _currentIndex = index),
                          ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Câu ${question.number}',
                      style: const TextStyle(
                        color: Color(0xFF2160F5),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      question.prompt,
                      style: const TextStyle(
                        color: Color(0xFF172033),
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (final option in question.options.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AnswerOption(
                          label: option.key,
                          text: option.value,
                          selected: selected == option.key,
                          onTap: () => setState(
                            () =>
                                _selectedAnswers[question.number] = option.key,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _currentIndex == 0
                            ? null
                            : () => setState(() => _currentIndex--),
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('Câu trước'),
                      ),
                      const Spacer(),
                      Text(
                        '${_selectedAnswers.length}/${widget.questions.length} đã chọn',
                        style: const TextStyle(color: Color(0xFF71829A)),
                      ),
                      const Spacer(),
                      if (_currentIndex < widget.questions.length - 1)
                        FilledButton.icon(
                          onPressed: () => setState(() => _currentIndex++),
                          icon: const Icon(Icons.chevron_right),
                          label: const Text('Câu tiếp'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Nộp bài'),
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

class ExamReviewPage extends StatelessWidget {
  const ExamReviewPage({super.key, required this.attempt});

  final ExamAttempt attempt;

  @override
  Widget build(BuildContext context) {
    final elapsedMinutes = attempt.elapsed.inMinutes;
    final elapsedSeconds = attempt.elapsed.inSeconds % 60;

    return Scaffold(
      appBar: AppBar(title: const Text('Xem lại bài làm')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            attempt.examTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${attempt.correctAnswers}/${attempt.questions.length} câu đúng  ·  $elapsedMinutes phút $elapsedSeconds giây',
                            style: const TextStyle(color: Color(0xFF71829A)),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${attempt.scorePercent}/100',
                      style: const TextStyle(
                        color: Color(0xFF2160F5),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: attempt.questions.length,
                  separatorBuilder: (_, _) => const Divider(height: 32),
                  itemBuilder: (context, index) {
                    final question = attempt.questions[index];
                    final selected = attempt.selectedAnswers[question.number];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Câu ${question.number}: ${question.prompt}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final option in question.options.entries)
                          _ReviewOption(
                            label: option.key,
                            text: option.value,
                            isCorrect: option.key == question.correctOption,
                            isSelected: option.key == selected,
                          ),
                        const SizedBox(height: 8),
                        Text(
                          selected == null
                              ? 'Bạn chưa trả lời câu này.'
                              : selected == question.correctOption
                              ? 'Bạn đã chọn đúng.'
                              : 'Bạn chọn $selected · Đáp án đúng ${question.correctOption}.',
                          style: TextStyle(
                            color: selected == null
                                ? const Color(0xFF71829A)
                                : selected == question.correctOption
                                ? const Color(0xFF00875A)
                                : const Color(0xFFC63D36),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionNumberButton extends StatelessWidget {
  const _QuestionNumberButton({
    required this.number,
    required this.isCurrent,
    required this.isAnswered,
    required this.onPressed,
  });

  final int number;
  final bool isCurrent;
  final bool isAnswered;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: isCurrent
              ? const Color(0xFF2160F5)
              : isAnswered
              ? const Color(0xFFE9FAF3)
              : Colors.white,
          foregroundColor: isCurrent
              ? Colors.white
              : isAnswered
              ? const Color(0xFF00875A)
              : const Color(0xFF52657F),
          side: BorderSide(
            color: isCurrent
                ? const Color(0xFF2160F5)
                : isAnswered
                ? const Color(0xFF9BD8BC)
                : const Color(0xFFD7DFEC),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text('$number'),
      ),
    );
  }
}

class _AnswerOption extends StatelessWidget {
  const _AnswerOption({
    required this.label,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFEAF1F9) : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? const Color(0xFF2160F5)
                  : const Color(0xFFD7DFEC),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.circle_outlined,
                color: selected
                    ? const Color(0xFF2160F5)
                    : const Color(0xFF8FA1BC),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                '$label.',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewOption extends StatelessWidget {
  const _ReviewOption({
    required this.label,
    required this.text,
    required this.isCorrect,
    required this.isSelected,
  });

  final String label;
  final String text;
  final bool isCorrect;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final color = isCorrect
        ? const Color(0xFF00875A)
        : isSelected
        ? const Color(0xFFC63D36)
        : const Color(0xFF52657F);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCorrect
                ? Icons.check_circle
                : isSelected
                ? Icons.cancel
                : Icons.circle_outlined,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text('$label. $text', style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}
