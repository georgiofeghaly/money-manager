import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/backup_providers.dart';
import '../data/backup_file_io.dart';

/// Builds a full-database JSON backup and opens the OS share sheet for it.
Future<void> backupAllData(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final payload = await ref.read(backupRepositoryProvider).exportAll();
    await shareBackupExport(jsonEncode(payload.toJson()));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Backup failed: $e')));
  }
}
