import 'category_matcher.dart';
import 'column_mapper.dart';
import 'date_format_detector.dart';

/// Which columns encode the amount/sign of a row. Chosen by the user in
/// step_account_and_strategy.dart, defaulted from which columns got mapped.
enum AmountStrategy { signedAmount, debitCredit, amountPlusType }

const Map<String, String> _typeValueAliases = {
  'debit': 'expense',
  'withdrawal': 'expense',
  'expense': 'expense',
  'out': 'expense',
  'payment': 'expense',
  'purchase': 'expense',
  '-': 'expense',
  'credit': 'income',
  'deposit': 'income',
  'income': 'income',
  'in': 'income',
  'receipt': 'income',
  '+': 'income',
  'transfer': 'transfer',
};

/// How a single distinct raw CSV category value should be resolved, chosen
/// by the user in step_category_resolution.dart.
class CategoryResolution {
  const CategoryResolution.useExisting(this.categoryId)
      : createNewName = null,
        skip = false;
  const CategoryResolution.createNew(this.createNewName)
      : categoryId = null,
        skip = false;
  const CategoryResolution.skip()
      : categoryId = null,
        createNewName = null,
        skip = true;

  final String? categoryId;
  final String? createNewName;
  final bool skip;
}

class PendingCategory {
  const PendingCategory({required this.kind, required this.name});
  final String kind;
  final String name;
}

/// A distinct (kind, raw category text) pairing found while scanning the
/// file — one entry per value the category-resolution step needs a decision
/// for.
class CategoryUsage {
  const CategoryUsage({required this.rawText, required this.kind});
  final String rawText;
  final String kind;
}

/// A successfully-parsed row, still referencing [pendingCategoryKey] instead
/// of a real category id when its category is a not-yet-created "create new"
/// choice — resolved to a real id at commit time once those are created.
class ParsedImportRow {
  const ParsedImportRow({
    required this.rowIndex,
    required this.type,
    required this.amount,
    required this.occurredAt,
    required this.accountId,
    this.categoryId,
    this.pendingCategoryKey,
    this.note,
  });

  final int rowIndex;
  final String type;
  final double amount;
  final DateTime occurredAt;
  final String accountId;
  final String? categoryId;
  final String? pendingCategoryKey;
  final String? note;
}

class ImportRowError {
  const ImportRowError({required this.rowIndex, required this.reason});
  final int rowIndex;
  final String reason;
}

class ImportParseResult {
  const ImportParseResult({
    required this.rows,
    required this.errors,
    required this.pendingCategories,
  });

  final List<ParsedImportRow> rows;
  final List<ImportRowError> errors;

  /// Keyed by "kind|normalizedName" — every distinct "create new" category
  /// choice referenced by [rows], to be created once before drafts commit.
  final Map<String, PendingCategory> pendingCategories;
}

String _cellFor(List<String> row, Map<ImportField, int> fieldColumns, ImportField field) {
  final index = fieldColumns[field];
  if (index == null || index >= row.length) return '';
  return row[index].trim();
}

/// Parses every row of [dataRows] (headers already stripped) into either a
/// [ParsedImportRow] or an [ImportRowError], using the finalized column
/// mapping/strategy/date format/category resolutions from the wizard.
ImportParseResult parseImportRows({
  required List<List<String>> dataRows,
  required Map<ImportField, int> fieldColumns,
  required AmountStrategy strategy,
  required String dateFormatPattern,
  required String accountId,
  required Map<String, CategoryResolution> categoryResolutions,
}) {
  final rows = <ParsedImportRow>[];
  final errors = <ImportRowError>[];
  final pendingCategories = <String, PendingCategory>{};

  for (var i = 0; i < dataRows.length; i++) {
    final row = dataRows[i];

    final dateText = _cellFor(row, fieldColumns, ImportField.date);
    final occurredAt = tryParseDate(dateFormatPattern, dateText);
    if (occurredAt == null) {
      errors.add(
        ImportRowError(rowIndex: i, reason: 'Invalid or missing date: "$dateText"'),
      );
      continue;
    }

    final amountAndType = _resolveAmountAndType(strategy, row, fieldColumns, i, errors);
    if (amountAndType == null) continue;
    final (type, amount) = amountAndType;

    final rawCategory = _cellFor(row, fieldColumns, ImportField.category);
    String? categoryId;
    String? pendingCategoryKey;
    if (rawCategory.isNotEmpty) {
      final resolution = categoryResolutions[rawCategory];
      if (resolution == null || resolution.skip) {
        errors.add(
          ImportRowError(
            rowIndex: i,
            reason: resolution == null
                ? 'Category "$rawCategory" was not resolved'
                : 'Skipped: category "$rawCategory"',
          ),
        );
        continue;
      }
      if (resolution.categoryId != null) {
        categoryId = resolution.categoryId;
      } else {
        final name = resolution.createNewName!;
        pendingCategoryKey = '$type|${normalizeCategoryText(name)}';
        pendingCategories[pendingCategoryKey] =
            PendingCategory(kind: type, name: name);
      }
    }

    final note = _cellFor(row, fieldColumns, ImportField.note);

    rows.add(
      ParsedImportRow(
        rowIndex: i,
        type: type,
        amount: amount,
        occurredAt: occurredAt,
        accountId: accountId,
        categoryId: categoryId,
        pendingCategoryKey: pendingCategoryKey,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  return ImportParseResult(rows: rows, errors: errors, pendingCategories: pendingCategories);
}

/// Scans every row to find each distinct (kind, raw category text) that
/// step_category_resolution.dart needs the user to resolve. Rows whose
/// amount/type can't be determined are skipped (they'll surface as row
/// errors in the final parse and don't need a category decision).
List<CategoryUsage> collectCategoryUsages({
  required List<List<String>> dataRows,
  required Map<ImportField, int> fieldColumns,
  required AmountStrategy strategy,
}) {
  final seenKeys = <String>{};
  final usages = <CategoryUsage>[];
  final scratchErrors = <ImportRowError>[];

  for (var i = 0; i < dataRows.length; i++) {
    final row = dataRows[i];
    final rawCategory = _cellFor(row, fieldColumns, ImportField.category);
    if (rawCategory.isEmpty) continue;

    final resolved = _resolveAmountAndType(strategy, row, fieldColumns, i, scratchErrors);
    if (resolved == null) continue;
    final (kind, _) = resolved;

    final key = '$kind|${normalizeCategoryText(rawCategory)}';
    if (seenKeys.add(key)) {
      usages.add(CategoryUsage(rawText: rawCategory, kind: kind));
    }
  }
  return usages;
}

double? _parseAmount(String raw) =>
    double.tryParse(raw.replaceAll(',', '').replaceAll(' ', ''));

/// Returns (type, positive magnitude) or null after recording an
/// [ImportRowError] on parse failure.
(String, double)? _resolveAmountAndType(
  AmountStrategy strategy,
  List<String> row,
  Map<ImportField, int> fieldColumns,
  int rowIndex,
  List<ImportRowError> errors,
) {
  switch (strategy) {
    case AmountStrategy.signedAmount:
      final raw = _cellFor(row, fieldColumns, ImportField.amount);
      final parsed = _parseAmount(raw);
      if (parsed == null) {
        errors.add(ImportRowError(rowIndex: rowIndex, reason: 'Invalid amount: "$raw"'));
        return null;
      }
      if (parsed == 0) {
        errors.add(ImportRowError(rowIndex: rowIndex, reason: 'Zero amount'));
        return null;
      }
      return (parsed < 0 ? 'expense' : 'income', parsed.abs());

    case AmountStrategy.debitCredit:
      final debitRaw = _cellFor(row, fieldColumns, ImportField.debit);
      final creditRaw = _cellFor(row, fieldColumns, ImportField.credit);
      final debit = _parseAmount(debitRaw) ?? 0;
      final credit = _parseAmount(creditRaw) ?? 0;
      if (debit > 0 && credit > 0) {
        errors.add(ImportRowError(rowIndex: rowIndex, reason: 'Both debit and credit are set'));
        return null;
      }
      if (debit <= 0 && credit <= 0) {
        errors.add(ImportRowError(rowIndex: rowIndex, reason: 'Missing debit/credit amount'));
        return null;
      }
      return debit > 0 ? ('expense', debit) : ('income', credit);

    case AmountStrategy.amountPlusType:
      final amountRaw = _cellFor(row, fieldColumns, ImportField.amount);
      final parsedAmount = _parseAmount(amountRaw);
      if (parsedAmount == null || parsedAmount == 0) {
        errors.add(
          ImportRowError(rowIndex: rowIndex, reason: 'Invalid or zero amount: "$amountRaw"'),
        );
        return null;
      }
      final typeRaw = _cellFor(row, fieldColumns, ImportField.type).toLowerCase();
      final mappedType = _typeValueAliases[typeRaw];
      if (mappedType == null) {
        errors.add(ImportRowError(rowIndex: rowIndex, reason: 'Unrecognized type: "$typeRaw"'));
        return null;
      }
      if (mappedType == 'transfer') {
        errors.add(
          ImportRowError(
            rowIndex: rowIndex,
            reason: 'Transfers are not supported by CSV import',
          ),
        );
        return null;
      }
      return (mappedType, parsedAmount.abs());
  }
}
