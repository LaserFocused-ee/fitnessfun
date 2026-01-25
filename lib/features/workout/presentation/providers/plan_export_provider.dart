import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failures.dart';
import '../../../../shared/services/xlsx_export_service.dart';
import '../../domain/entities/workout_plan.dart';

part 'plan_export_provider.g.dart';

/// Provides the XLSX export service.
@riverpod
XlsxExportService xlsxExportService(XlsxExportServiceRef ref) {
  return const XlsxExportService();
}

/// Export state for tracking export progress.
sealed class ExportState {
  const ExportState();
}

class ExportIdle extends ExportState {
  const ExportIdle();
}

class ExportInProgress extends ExportState {
  const ExportInProgress();
}

class ExportSuccess extends ExportState {
  const ExportSuccess(this.fileName);
  final String fileName;
}

class ExportError extends ExportState {
  const ExportError(this.message);
  final String message;
}

/// Notifier for exporting workout plans to XLSX.
@riverpod
class PlanExportNotifier extends _$PlanExportNotifier {
  @override
  ExportState build() => const ExportIdle();

  /// Exports a workout plan to XLSX format.
  ///
  /// Returns [Right] with the filename on success,
  /// or [Left] with a [Failure] on error.
  Future<Either<Failure, String>> exportPlan(WorkoutPlan plan) async {
    state = const ExportInProgress();

    try {
      final exportService = ref.read(xlsxExportServiceProvider);

      // Generate XLSX bytes
      final bytes = exportService.generateWorkoutPlanXlsx(plan);
      final fileName = exportService.generateFileName(plan);

      // Save using file_saver (cross-platform)
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        ext: '', // Extension already in filename
        mimeType: MimeType.microsoftExcel,
      );

      state = ExportSuccess(fileName);
      return right(fileName);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Export error: $e');
        print('Stack trace: $stackTrace');
      }

      final message = 'Failed to export plan: ${e.toString()}';
      state = ExportError(message);
      return left(Failure.unknown(message: message, error: e));
    }
  }

  /// Resets the export state to idle.
  void reset() {
    state = const ExportIdle();
  }
}
