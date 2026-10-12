import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/exam_docx_importer.dart';
import 'package:frontend/exam_workflow.dart';

void main() {
  testWidgets('answers questions, submits, and returns a scored attempt', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    Future<ExamAttempt?>? submission;
    final questions = [
      _question(101, 'First'),
      _question(102, 'Second', correctOption: 'C'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  submission = Navigator.of(context).push<ExamAttempt>(
                    MaterialPageRoute(
                      builder: (context) => ExamTakingPage(
                        examId: 5,
                        title: 'Practice',
                        code: 'EX-5',
                        durationMinutes: 15,
                        questions: questions,
                      ),
                    ),
                  );
                },
                child: const Text('Bắt đầu'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Bắt đầu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Two'));
    await tester.tap(find.text('Câu tiếp'));
    await tester.pump();
    await tester.tap(find.text('Four'));
    await tester.tap(find.text('Nộp bài'));
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Nộp bài'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final attempt = await submission;
    expect(attempt, isNotNull);
    expect(attempt!.correctAnswers, 1);
    expect(attempt.scorePercent, 50);
  });

  testWidgets('can submit before answering every question', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    Future<ExamAttempt?>? submission;

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  submission = Navigator.of(context).push<ExamAttempt>(
                    MaterialPageRoute(
                      builder: (context) => ExamTakingPage(
                        examId: 5,
                        title: 'Practice',
                        code: 'EX-5',
                        durationMinutes: 15,
                        questions: [
                          _question(101, 'First'),
                          _question(102, 'Second'),
                        ],
                      ),
                    ),
                  );
                },
                child: const Text('Bắt đầu'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Bắt đầu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Nộp bài'));
    await tester.pump();

    expect(
      find.text('Còn 2 câu chưa trả lời. Bạn vẫn muốn nộp bài?'),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Nộp bài'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final attempt = await submission;
    expect(attempt, isNotNull);
    expect(attempt!.answeredQuestions, 0);
    expect(attempt.scorePercent, 0);
  });

  testWidgets('review shows the selected answer and correct answer', (
    tester,
  ) async {
    final attempt = ExamAttempt(
      examId: 1,
      examTitle: 'Practice',
      examCode: 'EX-1',
      questions: [_question(101, 'First')],
      selectedAnswers: const {101: 'D'},
      startedAt: DateTime(2026),
      submittedAt: DateTime(2026, 1, 1, 0, 1),
    );

    await tester.pumpWidget(
      MaterialApp(home: ExamReviewPage(attempt: attempt)),
    );

    expect(find.text('0/100'), findsOneWidget);
    expect(find.text('Bạn chọn D · Đáp án đúng B.'), findsOneWidget);
  });

  test(
    'scores correct, incorrect, and unanswered questions as a percentage',
    () {
      final questions = [
        const ExamQuestionPreview(
          number: 101,
          prompt: 'First',
          options: {'A': 'one', 'B': 'two', 'C': 'three', 'D': 'four'},
          correctOption: 'B',
        ),
        const ExamQuestionPreview(
          number: 102,
          prompt: 'Second',
          options: {'A': 'one', 'B': 'two', 'C': 'three', 'D': 'four'},
          correctOption: 'C',
        ),
        const ExamQuestionPreview(
          number: 103,
          prompt: 'Third',
          options: {'A': 'one', 'B': 'two', 'C': 'three', 'D': 'four'},
          correctOption: 'A',
        ),
      ];
      final attempt = ExamAttempt(
        examId: 1,
        examTitle: 'Practice',
        examCode: 'EX-1',
        questions: questions,
        selectedAnswers: const {101: 'B', 102: 'D'},
        startedAt: DateTime(2026),
        submittedAt: DateTime(2026, 1, 1, 0, 2),
      );

      expect(attempt.correctAnswers, 1);
      expect(attempt.answeredQuestions, 2);
      expect(attempt.scorePercent, 33);
      expect(attempt.elapsed, const Duration(minutes: 2));
    },
  );
}

ExamQuestionPreview _question(
  int number,
  String prompt, {
  String correctOption = 'B',
}) => ExamQuestionPreview(
  number: number,
  prompt: prompt,
  options: const {'A': 'One', 'B': 'Two', 'C': 'Three', 'D': 'Four'},
  correctOption: correctOption,
);
