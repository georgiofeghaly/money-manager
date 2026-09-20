import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Opens the native file picker restricted to .csv, reads the picked file
/// as text, and returns null if the user cancelled.
Future<(String fileName, String contents)?> pickCsvFile() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: ['csv'],
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  return (file.name, utf8.decode(bytes, allowMalformed: true));
}

/// Writes [csvContents] to a temp file and opens the OS share sheet for it.
Future<void> shareCsvExport(String csvContents) async {
  final dir = await getTemporaryDirectory();
  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final file = File('${dir.path}/money_manager_export_$timestamp.csv');
  await file.writeAsString(csvContents);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path)],
      subject: 'Money Manager export',
    ),
  );
}
