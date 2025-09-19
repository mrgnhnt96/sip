import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/src/dart/ast/ast.dart';
import 'package:lint_kit/lint_kit.dart';
import 'package:sip_lint_kit/src/lints/utils/linter.dart';

class BadObject implements Linter {
  const BadObject();

  static const code = 'bad_object';
  static const message = 'Do not use this object';

  @override
  Future<Iterable<Lint>> lint(AnalyzedFile file) async {
    if (file.path.contains('test')) {
      return [];
    }
    final resolved = await file.resolved();

    final visitor = ClazzVisitor();
    resolved.unit.accept(visitor);

    final lints = <Lint>[];
    for (final clazz in visitor.classes) {
      if (clazz.classKeyword.next case final Token name) {
        lints.add(Lint(
          code: code,
          message: message,
          path: file.path,
          range: name.range(file),
        ));
      }
    }

    return lints;
  }
}

class ClazzVisitor extends RecursiveAstVisitor {
  ClazzVisitor();

  final List<ClassDeclaration> classes = [];
  @override
  visitClassDeclaration(ClassDeclaration node) {
    classes.add(node);
    super.visitClassDeclaration(node);
  }
}

extension LinterX on SyntacticEntity {
  DetailedRange range(AnalyzedFile file) {
    final before = file.content.substring(0, offset);
    final beforeLines = before.split('\n');
    final after = file.content.substring(0, end);
    final afterLines = after.split('\n');

    final beforeLength = before.length;
    final afterLength = after.length;

    if (beforeLines.length == afterLines.length) {
      final lineIndex = beforeLines.length - 1;
      final beforeToken = beforeLines.last;
      final line = afterLines.last;
      final offset = beforeToken.length;

      return DetailedRange(
        start: DetailedPosition(
          line: lineIndex,
          character: offset,
          lineContent: line,
        ),
        end: DetailedPosition(
          line: lineIndex,
          character: offset + this.length,
          lineContent: line,
        ),
        content: switch (this) {
          final Token token => token.lexeme,
          _ => '__UNKNOWN__',
        },
      );
    }

    final startOffset = offset - beforeLength;
    final endOffset = end - afterLength;

    return DetailedRange(
      start: DetailedPosition(
        line: beforeLines.length - 1,
        character: startOffset,
        lineContent: beforeLines.last,
      ),
      end: DetailedPosition(
        line: afterLines.length,
        character: endOffset,
        lineContent: afterLines.last,
      ),
      content: switch (this) {
        final Token token => token.lexeme,
        _ => '__UNKNOWN__',
      },
    );
  }
}

class DetailedRange extends Range {
  DetailedRange({
    required this.start,
    required this.end,
    required this.content,
  }) : super(start: start, end: end);

  @override
  final DetailedPosition start;
  @override
  final DetailedPosition end;

  final String content;
}

class DetailedPosition extends Position {
  DetailedPosition({
    required super.line,
    required super.character,
    required this.lineContent,
  });

  final String lineContent;
}
