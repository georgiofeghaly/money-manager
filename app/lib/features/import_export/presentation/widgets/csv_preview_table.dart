import 'package:flutter/material.dart';

/// A horizontally-scrollable readonly preview of raw or parsed CSV rows,
/// reused by step_pick_file.dart (raw preview) and step_preview_confirm.dart
/// (parsed preview).
class CsvPreviewTable extends StatelessWidget {
  const CsvPreviewTable({super.key, required this.headers, required this.rows});

  final List<String> headers;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [for (final h in headers) DataColumn(label: Text(h))],
          rows: [
            for (final row in rows)
              DataRow(
                cells: [
                  for (var i = 0; i < headers.length; i++)
                    DataCell(Text(i < row.length ? row[i] : '')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
