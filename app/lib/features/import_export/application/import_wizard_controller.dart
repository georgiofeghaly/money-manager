import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/category_style.dart';
import '../../accounts/application/account_providers.dart';
import '../../categories/application/category_providers.dart';
import '../../transactions/application/transaction_providers.dart';
import '../data/column_mapper.dart';
import '../data/date_format_detector.dart';
import '../data/import_parser.dart';
import '../data/transaction_draft.dart';

const _uuid = Uuid();

/// Either an existing account id, or a name for a new account to be created
/// on commit (deferred, like new categories, so cancelling the wizard at any
/// point before the final confirm never writes to the database).
class AccountSelection {
  const AccountSelection.existing(this.accountId) : newAccountName = null;
  const AccountSelection.createNew(this.newAccountName) : accountId = null;

  final String? accountId;
  final String? newAccountName;

  bool get isCreateNew => newAccountName != null;
}

class ImportCommitResult {
  const ImportCommitResult({
    required this.importedCount,
    required this.skippedCount,
    required this.importBatchId,
  });

  final int importedCount;
  final int skippedCount;
  final String importBatchId;
}

class ImportWizardState {
  const ImportWizardState({
    this.step = 0,
    this.fileName,
    this.headers = const [],
    this.dataRows = const [],
    this.accountSelection,
    this.amountStrategy = AmountStrategy.signedAmount,
    this.fieldMapping = const {},
    this.dateFormatPattern = 'yyyy-MM-dd',
    this.dateFormatAmbiguous = false,
    this.dateSampleParses = const [],
    this.categoryResolutions = const {},
    this.isCommitting = false,
  });

  final int step;
  final String? fileName;
  final List<String> headers;
  final List<List<String>> dataRows;
  final AccountSelection? accountSelection;
  final AmountStrategy amountStrategy;

  /// header column index -> field it represents.
  final Map<int, ImportField> fieldMapping;
  final String dateFormatPattern;
  final bool dateFormatAmbiguous;
  final List<DateTime> dateSampleParses;

  /// raw CSV category text -> how to resolve it.
  final Map<String, CategoryResolution> categoryResolutions;
  final bool isCommitting;

  bool get hasFile => headers.isNotEmpty;

  Map<ImportField, int> get fieldColumns => {
        for (final entry in fieldMapping.entries) entry.value: entry.key,
      };

  List<CategoryUsage> get categoryUsages => collectCategoryUsages(
        dataRows: dataRows,
        fieldColumns: fieldColumns,
        strategy: amountStrategy,
      );

  bool get isMappingComplete {
    final fields = fieldColumns.keys.toSet();
    if (!fields.contains(ImportField.date)) return false;
    switch (amountStrategy) {
      case AmountStrategy.signedAmount:
        return fields.contains(ImportField.amount);
      case AmountStrategy.debitCredit:
        return fields.contains(ImportField.debit) && fields.contains(ImportField.credit);
      case AmountStrategy.amountPlusType:
        return fields.contains(ImportField.amount) && fields.contains(ImportField.type);
    }
  }

  bool get isCategoryResolutionComplete =>
      categoryUsages.every((u) => categoryResolutions.containsKey(u.rawText));

  /// Parses the full file against a placeholder account id — used for the
  /// live preview before the real account exists (a not-yet-created "new
  /// account" only gets a real id at commit time).
  ImportParseResult preview() => parseImportRows(
        dataRows: dataRows,
        fieldColumns: fieldColumns,
        strategy: amountStrategy,
        dateFormatPattern: dateFormatPattern,
        accountId: accountSelection?.accountId ?? '(pending)',
        categoryResolutions: categoryResolutions,
      );

  ImportWizardState copyWith({
    int? step,
    String? fileName,
    List<String>? headers,
    List<List<String>>? dataRows,
    AccountSelection? accountSelection,
    bool clearAccountSelection = false,
    AmountStrategy? amountStrategy,
    Map<int, ImportField>? fieldMapping,
    String? dateFormatPattern,
    bool? dateFormatAmbiguous,
    List<DateTime>? dateSampleParses,
    Map<String, CategoryResolution>? categoryResolutions,
    bool? isCommitting,
  }) {
    return ImportWizardState(
      step: step ?? this.step,
      fileName: fileName ?? this.fileName,
      headers: headers ?? this.headers,
      dataRows: dataRows ?? this.dataRows,
      accountSelection:
          clearAccountSelection ? null : (accountSelection ?? this.accountSelection),
      amountStrategy: amountStrategy ?? this.amountStrategy,
      fieldMapping: fieldMapping ?? this.fieldMapping,
      dateFormatPattern: dateFormatPattern ?? this.dateFormatPattern,
      dateFormatAmbiguous: dateFormatAmbiguous ?? this.dateFormatAmbiguous,
      dateSampleParses: dateSampleParses ?? this.dateSampleParses,
      categoryResolutions: categoryResolutions ?? this.categoryResolutions,
      isCommitting: isCommitting ?? this.isCommitting,
    );
  }
}

class ImportWizardController extends StateNotifier<ImportWizardState> {
  ImportWizardController(this._ref) : super(const ImportWizardState());

  final Ref _ref;

  void loadFile(String fileName, List<List<String>> rows) {
    final headers = rows.first;
    final dataRows = rows.skip(1).toList();
    final mapping = guessColumnMapping(headers);
    final strategy = _defaultStrategyFor(mapping);
    final detection = _detectDateFormatFor(dataRows, mapping);

    state = ImportWizardState(
      fileName: fileName,
      headers: headers,
      dataRows: dataRows,
      fieldMapping: mapping,
      amountStrategy: strategy,
      dateFormatPattern: detection.pattern,
      dateFormatAmbiguous: detection.ambiguous,
      dateSampleParses: detection.sampleParses,
    );
  }

  void setAccountSelection(AccountSelection selection) {
    state = state.copyWith(accountSelection: selection);
  }

  void setAmountStrategy(AmountStrategy strategy) {
    state = state.copyWith(amountStrategy: strategy);
  }

  /// Maps [headerIndex] to [field] (or clears it if null), unassigning
  /// [field] from any other column first since each field can be used once.
  void setColumnField(int headerIndex, ImportField? field) {
    final mapping = {...state.fieldMapping};
    mapping.removeWhere((_, value) => field != null && value == field);
    if (field == null) {
      mapping.remove(headerIndex);
    } else {
      mapping[headerIndex] = field;
    }
    state = state.copyWith(fieldMapping: mapping);
    // Cheap to always recompute rather than track whether the date column
    // specifically changed.
    _refreshDateFormatDetection();
  }

  /// Manual override from the date-format dropdown; clears the ambiguity
  /// warning since the user has now made an explicit choice.
  void setDateFormatPattern(String pattern) {
    final samples = _dateSamples(state.dataRows, state.fieldColumns);
    state = state.copyWith(
      dateFormatPattern: pattern,
      dateFormatAmbiguous: false,
      dateSampleParses: _sampleParses(pattern, samples),
    );
  }

  void setCategoryResolution(String rawText, CategoryResolution resolution) {
    state = state.copyWith(
      categoryResolutions: {...state.categoryResolutions, rawText: resolution},
    );
  }

  void goToStep(int step) => state = state.copyWith(step: step);

  void reset() => state = const ImportWizardState();

  Future<ImportCommitResult> commit() async {
    state = state.copyWith(isCommitting: true);
    try {
      final accountRepo = _ref.read(accountWriterProvider);
      final categoryRepo = _ref.read(categoryWriterProvider);
      final transactionRepo = _ref.read(transactionWriterProvider);

      final selection = state.accountSelection!;
      final accountId = selection.isCreateNew
          ? await accountRepo.createAccount(name: selection.newAccountName!, type: 'custom')
          : selection.accountId!;

      final result = parseImportRows(
        dataRows: state.dataRows,
        fieldColumns: state.fieldColumns,
        strategy: state.amountStrategy,
        dateFormatPattern: state.dateFormatPattern,
        accountId: accountId,
        categoryResolutions: state.categoryResolutions,
      );

      final createdCategoryIds = <String, String>{};
      for (final entry in result.pendingCategories.entries) {
        final id = await categoryRepo.createCategory(
          name: entry.value.name,
          kind: entry.value.kind,
          iconKey: kDefaultCategoryIconKey,
          color: defaultColorForId(entry.value.name),
        );
        createdCategoryIds[entry.key] = id;
      }

      final drafts = [
        for (final row in result.rows)
          TransactionDraft(
            type: row.type,
            amount: row.amount,
            occurredAt: row.occurredAt,
            accountId: row.accountId,
            categoryId: row.categoryId ??
                (row.pendingCategoryKey != null
                    ? createdCategoryIds[row.pendingCategoryKey]
                    : null),
            note: row.note,
          ),
      ];

      final importBatchId = _uuid.v4();
      await transactionRepo.importTransactions(drafts, importBatchId: importBatchId);

      return ImportCommitResult(
        importedCount: drafts.length,
        skippedCount: result.errors.length,
        importBatchId: importBatchId,
      );
    } finally {
      state = state.copyWith(isCommitting: false);
    }
  }

  Future<void> revert(String importBatchId) {
    return _ref.read(transactionWriterProvider).revertImportBatch(importBatchId);
  }

  void _refreshDateFormatDetection() {
    final detection = _detectDateFormatFor(state.dataRows, state.fieldMapping);
    state = state.copyWith(
      dateFormatPattern: detection.pattern,
      dateFormatAmbiguous: detection.ambiguous,
      dateSampleParses: detection.sampleParses,
    );
  }

  static AmountStrategy _defaultStrategyFor(Map<int, ImportField> mapping) {
    final fields = mapping.values.toSet();
    if (fields.contains(ImportField.debit) && fields.contains(ImportField.credit)) {
      return AmountStrategy.debitCredit;
    }
    if (fields.contains(ImportField.type) && fields.contains(ImportField.amount)) {
      return AmountStrategy.amountPlusType;
    }
    return AmountStrategy.signedAmount;
  }

  static List<String> _dateSamples(List<List<String>> dataRows, Map<ImportField, int> fieldColumns) {
    final dateColumn = fieldColumns[ImportField.date];
    if (dateColumn == null) return const [];
    return [
      for (final row in dataRows)
        if (dateColumn < row.length) row[dateColumn],
    ];
  }

  static List<DateTime> _sampleParses(String pattern, List<String> samples) {
    final result = <DateTime>[];
    for (final s in samples.where((s) => s.trim().isNotEmpty)) {
      if (result.length == 3) break;
      final parsed = tryParseDate(pattern, s);
      if (parsed != null) result.add(parsed);
    }
    return result;
  }

  static DateFormatDetectionResult _detectDateFormatFor(
    List<List<String>> dataRows,
    Map<int, ImportField> mapping,
  ) {
    final dateColumn = mapping.entries.firstWhereOrNull((e) => e.value == ImportField.date)?.key;
    if (dateColumn == null) {
      return const DateFormatDetectionResult(
        pattern: 'yyyy-MM-dd',
        ambiguous: true,
        sampleParses: [],
      );
    }
    final samples = [
      for (final row in dataRows)
        if (dateColumn < row.length) row[dateColumn],
    ];
    return detectDateFormat(samples);
  }
}

final importWizardControllerProvider =
    StateNotifierProvider.autoDispose<ImportWizardController, ImportWizardState>(
  (ref) => ImportWizardController(ref),
);
