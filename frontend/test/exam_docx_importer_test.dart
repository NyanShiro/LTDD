import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/exam_docx_importer.dart';

void main() {
  test('creates a downloadable DOCX template accepted by the importer', () {
    final result = ExamDocxImporter.parse(ExamDocxImporter.createTemplate());

    expect(result.questionCount, 6);
    expect(result.questions.first.number, 101);
    expect(result.questions.first.correctOption, 'B');
    expect(result.questions.first.options['B'], 'Lựa chọn B');
    expect(result.questions[2].number, 103);
    expect(
      result.questions[2].prompt,
      contains('Sparkle Pro Enterprises Opens American Factory'),
    );
    expect(result.questions.last.number, 106);
  });

  test('parses ch, ctrl, and da tags from the Word format', () {
    final result = parseExamText('''
<ch> 101. Ms. Tillinghast has received several awards ------ her innovative ideas. (A) away (B) for (C) often (D) across </ch>
<ctrl> A. away; B. for; C. often; D. across </ctrl>
<da> B </da>
<ch> 102. Using proper techniques to------ items drastically reduces the risk of back injury. (A) select (B) lift (C) damage (D) attract </ch>
<ctrl> A. select; B. lift; C. damage; D. attract </ctrl>
<da> B </da>
''');

    expect(result.isValid, isTrue);
    expect(result.questionCount, 2);
    expect(
      result.questions.first.prompt,
      'Ms. Tillinghast has received several awards ------ her innovative ideas.',
    );
    expect(result.questions.first.options['A'], 'away');
    expect(result.questions.first.options['B'], 'for');
    expect(result.questions.first.correctOption, 'B');
    expect(result.questions.last.correctOption, 'B');
  });

  test('parses the question format shown in the import specification', () {
    final result = parseExamText('''
[Q] 101
Ms. Tillinghast has received several awards ------ her innovative ideas.
[A] away
[B] for
[C] often
[D] across
[ANS] B
[Q] 102
Using proper techniques to ------ items drastically reduces the risk of back injury.
[A] select
[B] lift
[C] damage
[D] attract
[ANS] B
''');

    expect(result.questionCount, 2);
    expect(result.questions.first.number, 101);
    expect(
      result.questions.first.prompt,
      'Ms. Tillinghast has received several awards ------ her innovative ideas.',
    );
    expect(result.questions.first.options['B'], 'for');
    expect(result.questions.first.correctOption, 'B');
    expect(result.questions.last.number, 102);
    expect(result.questions.last.correctOption, 'B');
  });

  test('parses inline question and answer tags inside a group', () {
    final result = parseExamText('''
[GROUP]
[Q:127] Although space in the bathroom was limited, the contractor managed to fit in two sinks and a shower.
[A] Both
[B] So that
[C] Whether
[D] Even though
[ANS:D]
[Q:128] The staff must ------ as much market-research data as possible before planning the advertising campaign.
[A] equip
[B] compile
[C] endorse
[D] compose
[ANS:B]
[/GROUP]
''');

    expect(result.isValid, isTrue);
    expect(result.questionCount, 2);
    expect(result.questions.first.number, 127);
    expect(result.questions.first.prompt, startsWith('Although space'));
    expect(result.questions.first.correctOption, 'D');
    expect(result.questions.last.number, 128);
    expect(result.questions.last.options['B'], 'compile');
    expect(result.questions.last.correctOption, 'B');
  });

  test('uses a group passage as the prompt for each question in the group', () {
    const passage =
        'Sparkle Pro Enterprises Opens American Factory\nWorldwide News';
    final result = parseExamText('''
[GROUP]
[PASSAGE]
Sparkle Pro Enterprises Opens American Factory
Worldwide News
[/PASSAGE]
[Q:143] What does Sparkle Pro manufacture?
[A] Cleaning products
[B] Food
[C] Furniture
[D] Clothing
[ANS:A]
[Q:144] Where is the new plant?
[A] Belgium
[B] Indianapolis
[C] Manchester
[D] Europe
[ANS:B]
[/GROUP]
''');

    expect(result.isValid, isTrue);
    expect(result.questionCount, 2);
    expect(result.questions.first.prompt, startsWith(passage));
    expect(result.questions.first.prompt, contains('What does Sparkle Pro'));
    expect(result.questions.last.prompt, startsWith(passage));
    expect(result.questions.last.prompt, contains('Where is the new plant?'));
    expect(result.questions.first.correctOption, 'A');
    expect(result.questions.last.correctOption, 'B');
  });

  test('parses passage tags inline with Word paragraph content', () {
    final result = parseExamText('''
    [PASSAGE]Shared passage[/PASSAGE]
[Q:101] First question
[A] One
[B] Two
[C] Three
[D] Four
[ANS:A][/GROUP]
''');

    expect(result.isValid, isTrue);
    expect(result.questions.single.prompt, 'Shared passage\n\nFirst question');
    expect(result.questions.single.correctOption, 'A');
  });

  test(
    'rejects a question with neither its own prompt nor a group passage',
    () {
      expect(
        () => parseExamText('''
[Q:101]
[A] One
[B] Two
[C] Three
[D] Four
[ANS:A]
'''),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('Câu 101 phải có nội dung câu hỏi hoặc passage.'),
          ),
        ),
      );
    },
  );

  test(
    'preview retains readable questions and answers when options are missing',
    () {
      final result = parseExamText('''
[Q] 101
The student recieved several awards for the project.
[A] away
[B] for
[C] often
[ANS] B
''', allowInvalid: true);

      expect(result.isValid, isFalse);
      expect(result.questions.single.prompt, contains('recieved'));
      expect(result.questions.single.options['B'], 'for');
      expect(result.questions.single.correctOption, 'B');
      expect(
        result.validationErrors,
        contains('Câu 101 phải có đủ 4 lựa chọn A, B, C, D.'),
      );
      expect(
        () => parseExamText('''
[Q] 101
The student recieved several awards for the project.
[A] away
[B] for
[C] often
[ANS] B
'''),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('edited question text, options, and answer are revalidated', () {
    final source = parseExamText('''
[Q] 101
Original prompt
[A] First
[B] Second
[C] Third
[ANS] B
''', allowInvalid: true);
    final original = source.questions.single;
    final edited = revalidateExamEdits(source, [
      original.copyWith(
        prompt: 'Corrected prompt',
        options: const {
          'A': 'First',
          'B': 'Second',
          'C': 'Third',
          'D': 'Fourth',
        },
        correctOption: 'D',
      ),
    ]);

    expect(edited.isValid, isTrue);
    expect(edited.questions.single.prompt, 'Corrected prompt');
    expect(edited.questions.single.options['D'], 'Fourth');
    expect(edited.questions.single.correctOption, 'D');
  });

  test('accepts a non-one starting number but rejects gaps', () {
    expect(
      () => parseExamText('''
[Q] 101
Prompt one
[A] One
[B] Two
[C] Three
[D] Four
[ANS] A
[Q] 103
Prompt two
[A] One
[B] Two
[C] Three
[D] Four
[ANS] B
'''),
      throwsA(isA<FormatException>()),
    );
  });

  test('reads question paragraphs from a DOCX document.xml archive', () {
    final archive = Archive()
      ..add(
        ArchiveFile.string('word/document.xml', '''
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p><w:r><w:t>1. What is 2 + 2?</w:t></w:r></w:p>
    <w:p><w:r><w:t>A. 3</w:t></w:r></w:p>
    <w:p><w:r><w:t>B. 4 {ANSWER}</w:t></w:r></w:p>
    <w:p><w:r><w:t>C. 5</w:t></w:r></w:p>
    <w:p><w:r><w:t>D. 6</w:t></w:r></w:p>
  </w:body>
</w:document>
'''),
      );
    final bytes = ZipEncoder().encodeBytes(archive);

    final result = ExamDocxImporter.parse(bytes);

    expect(result.questionCount, 1);
    expect(result.questions.single.prompt, 'What is 2 + 2?');
    expect(result.questions.single.correctOption, 'B');
  });

  test('counts questions with four options and one marked answer', () {
    final result = parseExamText('''
1. What is 2 + 2?
A. 3
B. 4 {ANSWER}
C. 5
D. 6
2) Select the color
A) Red {ANSWER}
B) Blue
C) Green
D) Yellow
''');

    expect(result.questionCount, 2);
  });

  test('rejects questions without exactly one marked answer', () {
    expect(
      () => parseExamText('''
1. What is 2 + 2?
A. 3
B. 4
C. 5
D. 6
'''),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects missing options', () {
    expect(
      () => parseExamText('''
1. What is 2 + 2?
A. 3 {ANSWER}
B. 4
C. 5
'''),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects images outside PNG/JPG formats', () {
    final archive = Archive()
      ..add(
        ArchiveFile.string(
          'word/document.xml',
          '<w:document xmlns:w="urn:test"><w:body/></w:document>',
        ),
      )
      ..add(ArchiveFile.bytes('word/media/image.gif', [1, 2, 3]));

    expect(
      () => ExamDocxImporter.parse(ZipEncoder().encodeBytes(archive)),
      throwsA(isA<FormatException>()),
    );
  });
}
