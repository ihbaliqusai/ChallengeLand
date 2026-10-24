import 'dart:convert';
import 'dart:io';

void main() {
  print('=== Merging One Piece Questions into questions.json ===');

  final mainFile = File('assets/questions.json');
  if (!mainFile.existsSync()) {
    throw Exception('assets/questions.json not found!');
  }

  final backupFile = File('assets/questions.backup_before_one_piece.json');
  final mainContent = mainFile.readAsStringSync(encoding: utf8);
  backupFile.writeAsStringSync(mainContent, encoding: utf8);
  print('Backup created at ${backupFile.path} (${backupFile.lengthSync()} bytes)');

  final List existingQuestions = jsonDecode(mainContent);
  print('Existing questions count: ${existingQuestions.length}');

  final newFile = File('assets/questions_one_piece_300.json');
  final List newQuestions = jsonDecode(newFile.readAsStringSync(encoding: utf8));
  print('New questions to merge: ${newQuestions.length}');

  final merged = [...existingQuestions, ...newQuestions];
  print('Merged questions total count: ${merged.length}');

  mainFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(merged), encoding: utf8);
  print('Successfully wrote merged questions to assets/questions.json');
}
