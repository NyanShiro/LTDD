import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/exam_api_client.dart';
import 'package:frontend/exam_docx_importer.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('loads saved exams and questions from the API', () async {
    final client = ExamApiClient(
      baseUrl: 'http://example.test',
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/exams');
        return http.Response(
          jsonEncode([
            {
              'id': 8,
              'title': 'Midterm',
              'subject': 'English',
              'code': 'ENG-8',
              'durationMinutes': 45,
              'creationTime': '2026-10-12T10:00:00Z',
              'questions': [
                {
                  'number': 101,
                  'prompt': 'Choose the answer.',
                  'optionA': 'One',
                  'optionB': 'Two',
                  'optionC': 'Three',
                  'optionD': 'Four',
                  'correctOption': 'B',
                },
              ],
            },
          ]),
          200,
        );
      }),
    );

    final exams = await client.loadExams();

    expect(exams.single.id, 8);
    expect(exams.single.questions.single.number, 101);
    expect(exams.single.questions.single.correctOption, 'B');
  });

  test(
    'sends DOCX bytes and edited questions to the import endpoint',
    () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final question = const ExamQuestionPreview(
        number: 101,
        prompt: 'Edited prompt',
        options: {'A': 'One', 'B': 'Two', 'C': 'Three', 'D': 'Four'},
        correctOption: 'D',
      );
      final client = ExamApiClient(
        baseUrl: 'http://example.test',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/exams/import');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['title'], 'Edited exam');
          expect(body['fileBase64'], base64Encode(bytes));
          expect(body['questions'][0]['prompt'], 'Edited prompt');
          expect(body['questions'][0]['correctOption'], 'D');
          return http.Response(jsonEncode({'id': 41}), 200);
        }),
      );

      final id = await client.importExam(
        title: 'Edited exam',
        subject: 'English',
        code: 'ENG-41',
        durationMinutes: 45,
        originalFileName: 'exam.docx',
        fileBytes: bytes,
        questions: [question],
      );

      expect(id, 41);
    },
  );

  test('exposes validation details from wrapped API error responses', () async {
    final client = ExamApiClient(
      baseUrl: 'http://example.test',
      client: MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'result': {
                'title': 'One or more validation errors occurred.',
                'errors': {
                  'Questions': ['Câu hỏi cần đủ nội dung A-D.'],
                },
              },
              'success': false,
              'error': null,
            }),
          ),
          400,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await expectLater(
      client.importExam(
        title: 'Exam',
        subject: 'English',
        code: 'ENG-1',
        durationMinutes: 60,
        originalFileName: 'exam.docx',
        fileBytes: Uint8List.fromList([1]),
        questions: const [
          ExamQuestionPreview(
            number: 1,
            prompt: 'Prompt',
            options: {'A': 'One', 'B': 'Two', 'C': 'Three', 'D': 'Four'},
            correctOption: 'A',
          ),
        ],
      ),
      throwsA(
        isA<ExamApiException>().having(
          (error) => error.message,
          'message',
          contains('Questions: Câu hỏi cần đủ nội dung A-D.'),
        ),
      ),
    );
  });
}
