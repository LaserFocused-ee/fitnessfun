import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../features/workout/domain/entities/workout_plan.dart';

/// Service for generating XLSX files from workout plans.
///
/// Generates Google Sheets compatible spreadsheets with:
/// - Plan header (name, description)
/// - Exercises table with columns: #, Exercise, Video, Set, Reps, Weight, Tempo, Rest, Notes
/// - One row per set, grouped by exercise
class XlsxExportService {
  const XlsxExportService();

  /// Generates an XLSX file from a workout plan.
  ///
  /// Returns the file bytes as [Uint8List].
  Uint8List generateWorkoutPlanXlsx(WorkoutPlan plan) {
    final excel = Excel.createExcel();

    // Remove default sheet and create named one
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null) {
      excel.delete(defaultSheet);
    }

    final sheetName = _sanitizeSheetName(plan.name);
    final sheet = excel[sheetName];

    var currentRow = 0;

    // === Row 1: Plan Name (bold, merged) ===
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
      CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: currentRow),
    );
    final titleCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
    );
    titleCell.value = TextCellValue(plan.name);
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
    );
    currentRow++;

    // === Row 2: Description (merged) ===
    if (plan.description != null && plan.description!.isNotEmpty) {
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
        CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: currentRow),
      );
      final descCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
      );
      descCell.value = TextCellValue(plan.description!);
      descCell.cellStyle = CellStyle(
        italic: true,
      );
      currentRow++;
    }

    // === Row 3: Empty spacer ===
    currentRow++;

    // === Row 4: Headers ===
    final headers = ['#', 'Exercise', 'Video', 'Set', 'Reps', 'Weight (kg)', 'Tempo', 'Rest (sec)', 'Notes'];
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#E0E0E0'),
    );

    for (var col = 0; col < headers.length; col++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow),
      );
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = headerStyle;
    }
    currentRow++;

    // === Data Rows: Exercises and Sets ===
    for (var exerciseIndex = 0; exerciseIndex < plan.exercises.length; exerciseIndex++) {
      final exercise = plan.exercises[exerciseIndex];
      final exerciseNumber = exerciseIndex + 1;

      // Get tempo (prefer exerciseTempo, fall back to tempo)
      final tempo = exercise.exerciseTempo ?? exercise.tempo ?? '';

      // Build rest string
      final rest = _buildRestString(exercise.restMin, exercise.restMax);

      // Build notes (combine exercise notes + client-specific notes)
      final notes = _buildNotesString(exercise.exerciseNotes, exercise.notes);

      if (exercise.sets.isEmpty) {
        // No sets defined - add single row for the exercise
        _writeExerciseRow(
          sheet: sheet,
          row: currentRow,
          exerciseNumber: exerciseNumber,
          exerciseName: exercise.exerciseName ?? 'Unknown',
          videoUrl: exercise.exerciseVideoUrl,
          setNumber: null,
          reps: '',
          weight: null,
          tempo: tempo,
          rest: rest,
          notes: notes,
        );
        currentRow++;
      } else {
        // Write one row per set
        for (var setIndex = 0; setIndex < exercise.sets.length; setIndex++) {
          final set = exercise.sets[setIndex];
          final isFirstSet = setIndex == 0;

          // Build reps string (e.g., "8" or "8-10")
          final reps = _buildRepsString(set.reps, set.repsMax);

          _writeExerciseRow(
            sheet: sheet,
            row: currentRow,
            // Only show exercise number on first set row
            exerciseNumber: isFirstSet ? exerciseNumber : null,
            // Only show exercise name on first set row
            exerciseName: isFirstSet ? (exercise.exerciseName ?? 'Unknown') : null,
            // Only show video URL on first set row
            videoUrl: isFirstSet ? exercise.exerciseVideoUrl : null,
            setNumber: set.setNumber,
            reps: reps,
            weight: set.weight,
            // Only show tempo on first set row
            tempo: isFirstSet ? tempo : '',
            // Only show rest on first set row
            rest: isFirstSet ? rest : '',
            // Only show notes on first set row
            notes: isFirstSet ? notes : '',
          );
          currentRow++;
        }
      }
    }

    // Set column widths for readability
    sheet.setColumnWidth(0, 5);   // #
    sheet.setColumnWidth(1, 25);  // Exercise
    sheet.setColumnWidth(2, 50);  // Video URL
    sheet.setColumnWidth(3, 6);   // Set
    sheet.setColumnWidth(4, 8);   // Reps
    sheet.setColumnWidth(5, 12);  // Weight
    sheet.setColumnWidth(6, 10);  // Tempo
    sheet.setColumnWidth(7, 12);  // Rest
    sheet.setColumnWidth(8, 40);  // Notes

    // Encode and return
    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to encode XLSX file');
    }
    return Uint8List.fromList(bytes);
  }

  /// Writes a single exercise row to the sheet.
  void _writeExerciseRow({
    required Sheet sheet,
    required int row,
    int? exerciseNumber,
    String? exerciseName,
    String? videoUrl,
    int? setNumber,
    required String reps,
    double? weight,
    required String tempo,
    required String rest,
    required String notes,
  }) {
    // Column 0: Exercise number
    if (exerciseNumber != null) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = IntCellValue(exerciseNumber);
    }

    // Column 1: Exercise name
    if (exerciseName != null) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
        .value = TextCellValue(exerciseName);
    }

    // Column 2: Video URL
    if (videoUrl != null && videoUrl.isNotEmpty) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
        .value = TextCellValue(videoUrl);
    }

    // Column 3: Set number
    if (setNumber != null) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
        .value = IntCellValue(setNumber);
    }

    // Column 4: Reps
    if (reps.isNotEmpty) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
        .value = TextCellValue(reps);
    }

    // Column 5: Weight (numeric for calculations)
    if (weight != null) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
        .value = DoubleCellValue(weight);
    }

    // Column 6: Tempo
    if (tempo.isNotEmpty) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
        .value = TextCellValue(tempo);
    }

    // Column 7: Rest
    if (rest.isNotEmpty) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
        .value = TextCellValue(rest);
    }

    // Column 8: Notes
    if (notes.isNotEmpty) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
        .value = TextCellValue(notes);
    }
  }

  /// Builds a reps string (e.g., "8" or "8-10").
  String _buildRepsString(int reps, int? repsMax) {
    if (repsMax != null && repsMax != reps) {
      return '$reps-$repsMax';
    }
    return '$reps';
  }

  /// Builds a rest string (e.g., "90" or "90-120").
  String _buildRestString(int? restMin, int? restMax) {
    if (restMin == null) return '';
    if (restMax != null && restMax != restMin) {
      return '$restMin-$restMax';
    }
    return '$restMin';
  }

  /// Combines exercise notes and client-specific notes.
  String _buildNotesString(String? exerciseNotes, String? clientNotes) {
    final parts = <String>[];
    if (exerciseNotes != null && exerciseNotes.isNotEmpty) {
      parts.add(exerciseNotes);
    }
    if (clientNotes != null && clientNotes.isNotEmpty) {
      parts.add(clientNotes);
    }
    return parts.join(' | ');
  }

  /// Sanitizes a string for use as an Excel sheet name.
  /// Excel sheet names cannot contain: \ / ? * [ ] : and max 31 chars
  String _sanitizeSheetName(String name) {
    var sanitized = name
        .replaceAll(RegExp(r'[\\/?*\[\]:]'), '')
        .trim();

    if (sanitized.isEmpty) {
      sanitized = 'Workout Plan';
    }

    if (sanitized.length > 31) {
      sanitized = sanitized.substring(0, 31);
    }

    return sanitized;
  }

  /// Generates a filename for the exported plan.
  String generateFileName(WorkoutPlan plan) {
    // Sanitize plan name for filename
    final safeName = plan.name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();

    final dateStamp = DateTime.now().toIso8601String().split('T').first;

    return '${safeName}_$dateStamp.xlsx';
  }
}
