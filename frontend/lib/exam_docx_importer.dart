import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class ExamQuestionPreview {
  const ExamQuestionPreview({
    required this.number,
    required this.prompt,
    required this.options,
    required this.correctOption,
    this.validationErrors = const [],
  });

  final int number;
  final String prompt;
  final Map<String, String> options;
  final String? correctOption;
  final List<String> validationErrors;

  ExamQuestionPreview copyWith({
    int? number,
    String? prompt,
    Map<String, String>? options,
    String? correctOption,
  }) => ExamQuestionPreview(
    number: number ?? this.number,
    prompt: prompt ?? this.prompt,
    options: options ?? this.options,
    correctOption: correctOption ?? this.correctOption,
    validationErrors: validationErrors,
  );
}

class ExamDocxImportResult {
  const ExamDocxImportResult({
    required this.questions,
    required this.imageCount,
    required this.validationErrors,
    this.rawText = '',
    this.documentErrors = const [],
  });

  final List<ExamQuestionPreview> questions;
  final int imageCount;
  final List<String> validationErrors;
  final String rawText;
  final List<String> documentErrors;

  int get questionCount => questions.length;
  bool get isValid => validationErrors.isEmpty;
}

class ExamDocxImporter {
  static ExamDocxImportResult parse(
    List<int> bytes, {
    bool allowInvalid = false,
  }) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final document = archive.find('word/document.xml');
    if (document == null) {
      throw const FormatException('Không tìm thấy nội dung đề thi trong file.');
    }

    final images = archive.files
        .where((file) => file.isFile && file.name.startsWith('word/media/'))
        .toList();
    final imageErrors = <String>[];
    for (final image in images) {
      final extension = image.name.split('.').last.toLowerCase();
      if (extension != 'png' && extension != 'jpg' && extension != 'jpeg') {
        imageErrors.add(
          'Ảnh "${image.name.split('/').last}" không đúng định dạng PNG/JPG.',
        );
      }
    }

    final xml = XmlDocument.parse(utf8.decode(document.content));
    final paragraphs = xml
        .findAllElements('p', namespaceUri: '*')
        .map(
          (paragraph) => paragraph
              .findAllElements('t', namespaceUri: '*')
              .map((text) => text.innerText)
              .join(),
        )
        .where((text) => text.trim().isNotEmpty);

    final result = parseExamText(
      paragraphs.join('\n'),
      imageCount: images.length,
      allowInvalid: true,
      documentErrors: imageErrors,
    );
    if (!allowInvalid && !result.isValid) {
      throw FormatException(result.validationErrors.first);
    }
    return result;
  }

  static Uint8List createTemplate() {
    final paragraphs = [
      'MẪU ĐỀ THI UNITEST',
      '[GROUP]',
      '[Q:101] Chọn đáp án đúng cho câu hỏi mẫu.',
      '[A] Lựa chọn A',
      '[B] Lựa chọn B',
      '[C] Lựa chọn C',
      '[D] Lựa chọn D',
      '[ANS:B]',
      '[Q:102] Chọn từ phù hợp để hoàn thành câu.',
      '[A] although',
      '[B] because',
      '[C] therefore',
      '[D] unless',
      '[ANS:B]',
      'Paragraph:',
      '[GROUP]',
      '[PASSAGE]',
      'Sparkle Pro Enterprises Opens American Factory',
      'Worldwide News',
      'MANCHESTER (10 April)—Sparkle Pro Enterprises, a leading Belgium-based ------- (103) ------- of cleaning products, is expanding its territory. The company has just opened its first plant in the United States, in Indianapolis. For more than forty years, Sparkle Pro has been making and distributing household and industrial cleaners to a wide range of vendors, including retail outlets and hotel chains, throughout Europe. ------- (104) -------.',
      'The Indianapolis facility will require the company to hire 300 additional employees ------- (105) ------- the end of this year in order for it to achieve full capacity. According to Egon Bretz, the new director of North American operations, Sparkle Pro is confident that it will be able to train a large number of personnel quickly. Mr. Bretz expects no significant ------- (106) ------- in meeting these needs.',
      '[/PASSAGE]',
      '[Q:103]',
      '[A] Lựa chọn A',
      '[B] Lựa chọn B',
      '[C] Lựa chọn C',
      '[D] Lựa chọn D',
      '[ANS:A]',
      '[Q:104]',
      '[A] Lựa chọn A',
      '[B] Lựa chọn B',
      '[C] Lựa chọn C',
      '[D] Lựa chọn D',
      '[ANS:A]',
      '[Q:105]',
      '[A] Lựa chọn A',
      '[B] Lựa chọn B',
      '[C] Lựa chọn C',
      '[D] Lựa chọn D',
      '[ANS:A]',
      '[Q:106]',
      '[A] Lựa chọn A',
      '[B] Lựa chọn B',
      '[C] Lựa chọn C',
      '[D] Lựa chọn D',
      '[ANS:A]',
      '[/GROUP]',
    ].map(_paragraphXml).join();
    final documentXml =
        '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>$paragraphs<w:sectPr/></w:body>
</w:document>
''';
    final archive = Archive()
      ..add(
        ArchiveFile.string(
          '[Content_Types].xml',
          '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''',
        ),
      )
      ..add(
        ArchiveFile.string(
          '_rels/.rels',
          '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''',
        ),
      )
      ..add(ArchiveFile.string('word/document.xml', documentXml));

    return ZipEncoder().encodeBytes(archive);
  }
}

String _paragraphXml(String text) =>
    '<w:p><w:r><w:t xml:space="preserve">${_escapeXml(text)}</w:t></w:r></w:p>';

String _escapeXml(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

ExamDocxImportResult parseExamText(
  String text, {
  int imageCount = 0,
  bool allowInvalid = false,
  List<String> documentErrors = const [],
}) {
  if (RegExp(r'<ch\s*>', caseSensitive: false).hasMatch(text)) {
    final tagged = _normalizeTaggedExamText(text);
    return parseExamText(
      tagged.text,
      imageCount: imageCount,
      allowInvalid: allowInvalid,
      documentErrors: [...documentErrors, ...tagged.errors],
    );
  }

  text = text.replaceAllMapped(
    RegExp(r'\[/?(?:GROUP|PASSAGE)\]', caseSensitive: false),
    (match) => '\n${match[0]}\n',
  );

  final questionStart = RegExp(
    r'^\s*(?:\[Q(?::\s*(\d+))?\]\s*(?:(\d+)\s*)?|(?:câu\s*)?(\d+)\s*[.):])\s*(.*)$',
    caseSensitive: false,
  );
  final optionStart = RegExp(
    r'^\s*(?:\[([A-D])\]|([A-D])[.):])\s*(.*)$',
    caseSensitive: false,
  );
  final answerStart = RegExp(
    r'^\s*\[ANS(?::\s*([^\]]*)\]|]\s*(.*))\s*$',
    caseSensitive: false,
  );
  final questions = <_ImportedQuestion>[];
  final passageLines = <String>[];
  var insidePassage = false;
  var groupPassage = '';

  for (final line in const LineSplitter().convert(text)) {
    final trimmedLine = line.trim();
    if (RegExp(r'^\[GROUP\]$', caseSensitive: false).hasMatch(trimmedLine)) {
      groupPassage = '';
      continue;
    }
    if (RegExp(r'^\[/GROUP\]$', caseSensitive: false).hasMatch(trimmedLine)) {
      groupPassage = '';
      continue;
    }
    if (RegExp(r'^\[PASSAGE\]$', caseSensitive: false).hasMatch(trimmedLine)) {
      insidePassage = true;
      passageLines.clear();
      continue;
    }
    if (insidePassage) {
      if (RegExp(
        r'^\[/PASSAGE\]$',
        caseSensitive: false,
      ).hasMatch(trimmedLine)) {
        insidePassage = false;
        groupPassage = passageLines.join('\n').trim();
      } else {
        passageLines.add(trimmedLine);
      }
      continue;
    }

    final questionMatch = questionStart.firstMatch(line);
    if (questionMatch != null) {
      final questionPrompt = questionMatch[4]!.trim();
      questions.add(
        _ImportedQuestion(
          number: int.parse(
            questionMatch[1] ?? questionMatch[2] ?? questionMatch[3]!,
          ),
          prompt: groupPassage.isNotEmpty
              ? '$groupPassage\n\n$questionPrompt'.trim()
              : questionPrompt,
        ),
      );
      continue;
    }

    if (questions.isEmpty) continue;
    final answerMatch = answerStart.firstMatch(line);
    if (answerMatch != null) {
      final question = questions.last;
      final answer = (answerMatch[1] ?? answerMatch[2]!).trim().toUpperCase();
      question.answerCount++;
      if (const {'A', 'B', 'C', 'D'}.contains(answer) &&
          question.options.containsKey(answer)) {
        question.correctOption = answer;
      } else {
        question.hasInvalidAnswer = true;
      }
      continue;
    }

    final optionMatch = optionStart.firstMatch(line);
    if (optionMatch != null) {
      final option = (optionMatch[1] ?? optionMatch[2]!).toUpperCase();
      final optionText = optionMatch[3]!;
      final answerMarkers = RegExp(r'\{ANSWER\}').allMatches(optionText).length;
      questions.last.optionOrder.add(option);
      questions.last.options[option] = optionText
          .replaceAll('{ANSWER}', '')
          .trim();
      if (answerMarkers > 0) {
        questions.last.answerCount += answerMarkers;
        questions.last.correctOption = option;
      }
    } else if (questions.last.optionOrder.isEmpty && line.trim().isNotEmpty) {
      questions.last.prompt = '${questions.last.prompt} ${line.trim()}'.trim();
    }
  }

  if (questions.isEmpty) {
    const error = 'Không tìm thấy câu hỏi được đánh số trong file.';
    if (!allowInvalid) throw const FormatException(error);
    return ExamDocxImportResult(
      questions: const [],
      imageCount: imageCount,
      validationErrors: List.unmodifiable([...documentErrors, error]),
      rawText: text,
      documentErrors: List.unmodifiable(documentErrors),
    );
  }

  final previewQuestions = <ExamQuestionPreview>[];
  final validationErrors = [...documentErrors];
  for (var index = 0; index < questions.length; index++) {
    final question = questions[index];
    final questionErrors = <String>[];
    if (index > 0 && question.number != questions[index - 1].number + 1) {
      questionErrors.add(
        'Số câu hỏi phải liên tục (lỗi tại câu ${question.number}).',
      );
    }
    if (question.prompt.trim().isEmpty) {
      questionErrors.add(
        'Câu ${question.number} phải có nội dung câu hỏi hoặc passage.',
      );
    }
    if (question.optionOrder.length != 4 ||
        question.optionOrder.toSet().length != 4 ||
        !question.options.keys.toSet().containsAll(const {
          'A',
          'B',
          'C',
          'D',
        })) {
      questionErrors.add(
        'Câu ${question.number} phải có đủ 4 lựa chọn A, B, C, D.',
      );
    }
    if (question.hasInvalidAnswer ||
        question.answerCount != 1 ||
        question.correctOption == null) {
      questionErrors.add(
        'Câu ${question.number} phải có đúng một đáp án hợp lệ qua [ANS] A-D hoặc {ANSWER}.',
      );
    }
    if (question.options.values.any((option) => option.isEmpty)) {
      questionErrors.add(
        'Câu ${question.number} có lựa chọn chưa nhập nội dung.',
      );
    }
    validationErrors.addAll(questionErrors);
    previewQuestions.add(
      ExamQuestionPreview(
        number: question.number,
        prompt: question.prompt,
        options: Map.unmodifiable(question.options),
        correctOption: question.correctOption,
        validationErrors: List.unmodifiable(questionErrors),
      ),
    );
  }

  final result = ExamDocxImportResult(
    questions: List.unmodifiable(previewQuestions),
    imageCount: imageCount,
    validationErrors: List.unmodifiable(validationErrors),
    rawText: text,
    documentErrors: List.unmodifiable(documentErrors),
  );
  if (!allowInvalid && !result.isValid) {
    throw FormatException(result.validationErrors.first);
  }
  return result;
}

_TaggedExamText _normalizeTaggedExamText(String text) {
  final taggedBlocks = RegExp(
    r'<(ch|ctrl|da)\s*>([\s\S]*?)</\1\s*>',
    caseSensitive: false,
  );
  final questions = <_TaggedQuestion>[];
  final errors = <String>[];

  for (final block in taggedBlocks.allMatches(text)) {
    final tag = block[1]!.toLowerCase();
    final content = block[2]!.trim();
    if (tag == 'ch') {
      final heading = RegExp(
        r'^(\d+)\s*[.):]?\s*(.*)$',
        dotAll: true,
      ).firstMatch(content);
      if (heading == null) {
        errors.add('Tag <ch> phải bắt đầu bằng số câu hỏi.');
        continue;
      }
      final body = heading[2]!.trim();
      final question = _TaggedQuestion(
        number: int.parse(heading[1]!),
        prompt: body
            .replaceFirst(
              RegExp(r'\s*\(A\)\s*.*$', caseSensitive: false, dotAll: true),
              '',
            )
            .trim(),
      );
      question.inlineOptions.addAll(_parseTaggedOptions(body));
      questions.add(question);
      continue;
    }

    if (questions.isEmpty) {
      errors.add('Tag <$tag> phải nằm sau một tag <ch>.');
      continue;
    }
    final question = questions.last;
    if (tag == 'ctrl') {
      question.hasControlTag = true;
      question.options.addAll(_parseTaggedOptions(content));
    } else {
      question.correctOption = content
          .replaceFirst(RegExp(r'^\[ANS\]\s*', caseSensitive: false), '')
          .trim()
          .toUpperCase();
    }
  }

  if (questions.isEmpty) {
    return _TaggedExamText(text: '', errors: errors);
  }

  final normalized = StringBuffer();
  for (final question in questions) {
    normalized.writeln('[Q] ${question.number}');
    normalized.writeln(question.prompt);
    final options = question.hasControlTag
        ? question.options
        : question.inlineOptions;
    for (final option in const ['A', 'B', 'C', 'D']) {
      final value = options[option];
      if (value != null) normalized.writeln('[$option] $value');
    }
    if (question.correctOption != null) {
      normalized.writeln('[ANS] ${question.correctOption}');
    }
  }

  return _TaggedExamText(text: normalized.toString(), errors: errors);
}

Map<String, String> _parseTaggedOptions(String content) {
  final options = <String, String>{};
  for (final part in content.split(';')) {
    final match = RegExp(
      r'^\s*\(?([A-D])\)?[.):]\s*(.*?)\s*$',
      dotAll: true,
    ).firstMatch(part);
    if (match != null) {
      options[match[1]!.toUpperCase()] = match[2]!.trim();
    }
  }
  return options;
}

class _TaggedQuestion {
  _TaggedQuestion({required this.number, required this.prompt});

  final int number;
  final String prompt;
  final Map<String, String> options = {};
  final Map<String, String> inlineOptions = {};
  String? correctOption;
  bool hasControlTag = false;
}

class _TaggedExamText {
  const _TaggedExamText({required this.text, required this.errors});

  final String text;
  final List<String> errors;
}

ExamDocxImportResult revalidateExamEdits(
  ExamDocxImportResult source,
  List<ExamQuestionPreview> questions, {
  String? rawText,
}) {
  final text = questions.isEmpty
      ? rawText ?? source.rawText
      : questions
            .map(
              (question) => [
                '[Q] ${question.number}',
                question.prompt,
                for (final option in const ['A', 'B', 'C', 'D'])
                  '[$option] ${question.options[option] ?? ''}',
                if (question.correctOption != null)
                  '[ANS] ${question.correctOption}',
              ].join('\n'),
            )
            .join('\n');

  return parseExamText(
    text,
    imageCount: source.imageCount,
    allowInvalid: true,
    documentErrors: source.documentErrors,
  );
}

class _ImportedQuestion {
  _ImportedQuestion({required this.number, required this.prompt});

  final int number;
  String prompt;
  final List<String> optionOrder = [];
  final Map<String, String> options = {};
  int answerCount = 0;
  String? correctOption;
  bool hasInvalidAnswer = false;
}
