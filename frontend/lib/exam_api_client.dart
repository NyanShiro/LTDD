import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'exam_docx_importer.dart';

class ExamApiException implements Exception {
  const ExamApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class StoredExam {
  const StoredExam({
    required this.id,
    required this.title,
    required this.subject,
    required this.code,
    required this.durationMinutes,
    required this.creationTime,
    required this.questions,
  });

  final int id;
  final String title;
  final String subject;
  final String code;
  final int durationMinutes;
  final DateTime creationTime;
  final List<ExamQuestionPreview> questions;

  factory StoredExam.fromJson(Map<String, dynamic> json) {
    final questions = (json['questions'] as List<dynamic>? ?? const [])
        .map((item) {
          final question = item as Map<String, dynamic>;
          return ExamQuestionPreview(
            number: question['number'] as int,
            prompt: question['prompt'] as String? ?? '',
            options: {
              'A': question['optionA'] as String? ?? '',
              'B': question['optionB'] as String? ?? '',
              'C': question['optionC'] as String? ?? '',
              'D': question['optionD'] as String? ?? '',
            },
            correctOption: question['correctOption'] as String?,
          );
        })
        .toList(growable: false);
    final creationTime = DateTime.tryParse(
      json['creationTime'] as String? ?? '',
    );

    return StoredExam(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      code: json['code'] as String? ?? '',
      durationMinutes: json['durationMinutes'] as int? ?? 60,
      creationTime: creationTime ?? DateTime.now(),
      questions: questions,
    );
  }
}

class ExamApiClient {
  ExamApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = (baseUrl ?? _defaultBaseUrl).replaceFirst(RegExp(r'/$'), '');

  static const _defaultBaseUrl = String.fromEnvironment(
    'TOEIC_API_BASE_URL',
    defaultValue: 'https://localhost:44311',
  );

  final http.Client _client;
  final String _baseUrl;

  Future<List<StoredExam>> loadExams() async {
    final response = await _client.get(Uri.parse('$_baseUrl/api/exams'));
    if (response.statusCode != 200) {
      throw ExamApiException(_readError(response));
    }

    final payload = _unwrapResult(response) as List<dynamic>;
    return payload
        .map((item) => StoredExam.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<int> importExam({
    required String title,
    required String subject,
    required String code,
    required int durationMinutes,
    required String originalFileName,
    required Uint8List fileBytes,
    required List<ExamQuestionPreview> questions,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/exams/import'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'subject': subject,
        'code': code,
        'durationMinutes': durationMinutes,
        'originalFileName': originalFileName,
        'fileBase64': base64Encode(fileBytes),
        'questions': questions
            .map(
              (question) => {
                'number': question.number,
                'prompt': question.prompt,
                'optionA': question.options['A'] ?? '',
                'optionB': question.options['B'] ?? '',
                'optionC': question.options['C'] ?? '',
                'optionD': question.options['D'] ?? '',
                'correctOption': question.correctOption,
              },
            )
            .toList(growable: false),
      }),
    );
    if (response.statusCode != 200) {
      throw ExamApiException(_readError(response));
    }

    final payload = _unwrapResult(response) as Map<String, dynamic>;
    return payload['id'] as int;
  }

  dynamic _unwrapResult(http.Response response) {
    final payload = jsonDecode(response.body);
    if (payload is Map<String, dynamic> && payload.containsKey('result')) {
      if (payload['success'] == false) {
        throw ExamApiException(_readError(response));
      }
      return payload['result'];
    }
    return payload;
  }

  String _readError(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return 'API đề thi trả về HTTP ${response.statusCode}.';
      }
      final payload = decoded;
      final error = payload['error'];
      final result = payload['result'];
      final problem = result is Map<String, dynamic> ? result : payload;
      final validationErrors = problem['errors'];
      if (validationErrors is Map<String, dynamic>) {
        final messages = validationErrors.entries
            .map((entry) {
              final value = entry.value;
              final detail = value is List<dynamic>
                  ? value.join(' ')
                  : value.toString();
              return '${entry.key}: $detail';
            })
            .join(' ');
        if (messages.isNotEmpty) return messages;
      }
      final message =
          payload['message'] ??
          (error is Map<String, dynamic> ? error['message'] : error) ??
          problem['message'] ??
          problem['detail'] ??
          problem['title'];
      if (message is String && message.isNotEmpty) return message;
    } catch (_) {
      // Keep the status as a useful fallback for non-JSON proxy errors.
    }
    return 'API đề thi trả về HTTP ${response.statusCode}.';
  }
}
