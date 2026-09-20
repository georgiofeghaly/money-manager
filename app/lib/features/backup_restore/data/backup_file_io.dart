import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Opens the native file picker restricted to .json, reads the picked file
/// as text, and returns null if the user cancelled.
Future<(String fileName, String contents)?> pickBackupFile() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: ['json'],
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  return (file.name, utf8.decode(bytes, allowMalformed: true));
}

/// Writes [jsonContents] to a temp file and opens the OS share sheet for it.
Future<void> shareBackupExport(String jsonContents) async {
  final dir = await getTemporaryDirectory();
  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final file = File('${dir.path}/money_manager_backup_$timestamp.json');
  await file.writeAsString(jsonContents);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path)],
      subject: 'Money Manager backup',
    ),
  );
}
