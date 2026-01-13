import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/error/failures.dart';
import '../../../exercise/domain/entities/exercise.dart';
import '../../../exercise/presentation/providers/exercise_provider.dart';
import '../../domain/entities/plan_exercise_set.dart';
import '../../domain/entities/workout_plan.dart';
import '../providers/workout_provider.dart';

class PlanBuilderScreen extends ConsumerStatefulWidget {
  const PlanBuilderScreen({
    super.key,
    this.planId,
  });

  final String? planId;

  bool get isEditing => planId != null;

  @override
  ConsumerState<PlanBuilderScreen> createState() => _PlanBuilderScreenState();
}

class _PlanBuilderScreenState extends ConsumerState<PlanBuilderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _initializeForm(WorkoutPlan plan) {
    if (!_isInitialized) {
      _nameController.text = plan.name;
      _descriptionController.text = plan.description ?? '';
      _isInitialized = true;
    }
  }

  Future<void> _addExercise() async {
    final exercise = await showDialog<Exercise>(
      context: context,
      builder: (context) => const _ExercisePickerDialog(),
    );

    if (exercise != null) {
      final notifier = ref.read(planFormNotifierProvider.notifier);
      final currentExercises =
          ref.read(planFormNotifierProvider).exercises.length;

      notifier.addExercise(PlanExercise.empty(
        planId: '',
        exerciseId: exercise.id,
        exerciseName: exercise.name,
        orderIndex: currentExercises,
      ));
    }
  }

  Future<void> _editExercise(int index, PlanExercise exercise) async {
    final updated = await showDialog<PlanExercise>(
      context: context,
      builder: (context) => _ExerciseEditDialog(exercise: exercise),
    );

    if (updated != null) {
      ref.read(planFormNotifierProvider.notifier).updateExercise(index, updated);
    }
  }

  Future<void> _savePlan() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(planFormNotifierProvider.notifier);
    notifier.setName(_nameController.text.trim());
    notifier.setDescription(
      _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
    );

    if (ref.read(planFormNotifierProvider).exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one exercise')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await notifier.save();

    setState(() => _isLoading = false);

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.displayMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      },
      (plan) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditing
                  ? 'Plan updated successfully'
                  : 'Plan created successfully',
            ),
          ),
        );
        ref.invalidate(trainerPlansProvider);
        context.pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(planFormNotifierProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // If editing, load the plan
    if (widget.isEditing && !_isInitialized) {
      final planAsync = ref.watch(planByIdProvider(widget.planId!));

      return planAsync.when(
        data: (loadedPlan) {
          _initializeForm(loadedPlan);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(planFormNotifierProvider.notifier).loadPlan(loadedPlan);
          });
          return _buildForm(context, plan);
        },
        loading: () => Scaffold(
          appBar: AppBar(title: const Text('Edit Plan')),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Scaffold(
          appBar: AppBar(title: const Text('Edit Plan')),
          body: Center(child: Text('Error: $error')),
        ),
      );
    }

    // Reset form if creating new plan
    if (!widget.isEditing && !_isInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(planFormNotifierProvider.notifier).reset();
      });
      _isInitialized = true;
    }

    return _buildForm(context, plan);
  }

  Widget _buildForm(BuildContext context, WorkoutPlan plan) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Plan' : 'Create Plan'),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Plan info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Plan Name *',
                      hintText: 'e.g., Upper Body Day 1',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a plan name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Optional description...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),

            const Divider(),

            // Exercises header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Exercises (${plan.exercises.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _addExercise,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  ),
                ],
              ),
            ),

            // Exercise list
            Expanded(
              child: plan.exercises.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.fitness_center,
                            size: 48,
                            color: colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No exercises added yet',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _addExercise,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Exercise'),
                          ),
                        ],
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: plan.exercises.length,
                      onReorder: (oldIndex, newIndex) {
                        ref
                            .read(planFormNotifierProvider.notifier)
                            .reorderExercises(oldIndex, newIndex);
                      },
                      itemBuilder: (context, index) {
                        final exercise = plan.exercises[index];
                        return _ExerciseListItem(
                          key: ValueKey(exercise.exerciseId + index.toString()),
                          exercise: exercise,
                          index: index,
                          onEdit: () => _editExercise(index, exercise),
                          onDelete: () {
                            ref
                                .read(planFormNotifierProvider.notifier)
                                .removeExercise(index);
                          },
                        );
                      },
                    ),
            ),

            // Save button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _savePlan,
                  icon: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(widget.isEditing ? 'Save Changes' : 'Create Plan'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseListItem extends StatelessWidget {
  const _ExerciseListItem({
    super.key,
    required this.exercise,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  final PlanExercise exercise;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: CircleAvatar(
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Text(exercise.exerciseName ?? 'Unknown Exercise'),
        subtitle: _buildSubtitle(),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: onEdit,
              tooltip: 'Edit',
            ),
            IconButton(
              icon: Icon(Icons.delete, size: 20, color: colorScheme.error),
              onPressed: onDelete,
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildSubtitle() {
    final parts = <String>[];

    if (exercise.sets.isNotEmpty) {
      parts.add('${exercise.sets.length} sets');
      // Show reps from first set
      final firstSet = exercise.sets.first;
      if (firstSet.repsMax != null && firstSet.repsMax != firstSet.reps) {
        parts.add('${firstSet.reps}-${firstSet.repsMax} reps');
      } else {
        parts.add('${firstSet.reps} reps');
      }
    }
    if (exercise.tempo != null) {
      parts.add('tempo: ${exercise.tempo}');
    }
    if (exercise.restMin != null) {
      if (exercise.restMax != null && exercise.restMax != exercise.restMin) {
        parts.add('rest: ${exercise.restMin}-${exercise.restMax}s');
      } else {
        parts.add('rest: ${exercise.restMin}s');
      }
    }

    if (parts.isEmpty) return null;
    return Text(parts.join(' • '));
  }
}

class _ExercisePickerDialog extends ConsumerWidget {
  const _ExercisePickerDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesAsync = ref.watch(filteredExercisesProvider);
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Select Exercise'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: exercisesAsync.when(
          data: (exercises) {
            if (exercises.isEmpty) {
              return const Center(
                child: Text('No exercises available'),
              );
            }
            return ListView.builder(
              itemCount: exercises.length,
              itemBuilder: (context, index) {
                final exercise = exercises[index];
                return ListTile(
                  title: Text(exercise.name),
                  subtitle: exercise.muscleGroup != null
                      ? Text(exercise.muscleGroup!)
                      : null,
                  onTap: () => Navigator.pop(context, exercise),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _ExerciseEditDialog extends StatefulWidget {
  const _ExerciseEditDialog({required this.exercise});

  final PlanExercise exercise;

  @override
  State<_ExerciseEditDialog> createState() => _ExerciseEditDialogState();
}

class _ExerciseEditDialogState extends State<_ExerciseEditDialog> {
  late final TextEditingController _tempoController;
  late final TextEditingController _restMinController;
  late final TextEditingController _restMaxController;
  late final TextEditingController _notesController;
  late List<_SetEditRow> _setRows;

  @override
  void initState() {
    super.initState();
    _tempoController = TextEditingController(text: widget.exercise.tempo ?? '');
    _restMinController =
        TextEditingController(text: widget.exercise.restMin?.toString() ?? '');
    _restMaxController =
        TextEditingController(text: widget.exercise.restMax?.toString() ?? '');
    _notesController = TextEditingController(text: widget.exercise.notes ?? '');

    // Initialize set rows from existing sets or create one default row
    if (widget.exercise.sets.isEmpty) {
      _setRows = [_SetEditRow(setNumber: 1, reps: 10)];
    } else {
      _setRows = widget.exercise.sets.map((s) => _SetEditRow(
            setNumber: s.setNumber,
            reps: s.reps,
            repsMax: s.repsMax,
            weight: s.weight,
          )).toList();
    }
  }

  @override
  void dispose() {
    _tempoController.dispose();
    _restMinController.dispose();
    _restMaxController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _addSet() {
    setState(() {
      final lastSet = _setRows.isNotEmpty ? _setRows.last : null;
      _setRows.add(_SetEditRow(
        setNumber: _setRows.length + 1,
        reps: lastSet?.reps ?? 10,
        repsMax: lastSet?.repsMax,
        weight: lastSet?.weight,
      ));
    });
  }

  void _repeatSet(int index, int count) {
    setState(() {
      final sourceSet = _setRows[index];
      for (var i = 0; i < count; i++) {
        _setRows.add(_SetEditRow(
          setNumber: _setRows.length + 1,
          reps: sourceSet.reps,
          repsMax: sourceSet.repsMax,
          weight: sourceSet.weight,
        ));
      }
    });
  }

  void _deleteSet(int index) {
    if (_setRows.length <= 1) return;
    setState(() {
      _setRows.removeAt(index);
      // Renumber sets
      for (var i = 0; i < _setRows.length; i++) {
        _setRows[i] = _setRows[i].copyWith(setNumber: i + 1);
      }
    });
  }

  void _showRepeatDialog(int index) {
    showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Repeat Set'),
        content: const Text('How many times?'),
        actions: [
          for (var i = 1; i <= 5; i++)
            TextButton(
              onPressed: () => Navigator.pop(context, i),
              child: Text('$i'),
            ),
        ],
      ),
    ).then((count) {
      if (count != null) {
        _repeatSet(index, count);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.exercise.exerciseName ?? 'Edit Exercise'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rest period row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _restMinController,
                      decoration: const InputDecoration(
                        labelText: 'Rest Min (s)',
                        hintText: '60',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _restMaxController,
                      decoration: const InputDecoration(
                        labelText: 'Rest Max (s)',
                        hintText: '90',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _tempoController,
                decoration: const InputDecoration(
                  labelText: 'Tempo',
                  hintText: 'e.g., 3111',
                ),
              ),
              const SizedBox(height: 24),
              // Sets section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Sets', style: Theme.of(context).textTheme.titleMedium),
                  TextButton.icon(
                    onPressed: _addSet,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Set'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Set list
              ...List.generate(_setRows.length, (index) {
                final setRow = _setRows[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text('${setRow.setNumber}.',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Reps',
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                          controller: TextEditingController(
                            text: setRow.reps.toString(),
                          ),
                          onChanged: (v) {
                            _setRows[index] = _setRows[index].copyWith(
                              reps: int.tryParse(v) ?? setRow.reps,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Max',
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                          controller: TextEditingController(
                            text: setRow.repsMax?.toString() ?? '',
                          ),
                          onChanged: (v) {
                            _setRows[index] = _setRows[index].copyWith(
                              repsMax: int.tryParse(v),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Weight',
                            isDense: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          controller: TextEditingController(
                            text: setRow.weight?.toString() ?? '',
                          ),
                          onChanged: (v) {
                            _setRows[index] = _setRows[index].copyWith(
                              weight: double.tryParse(v),
                            );
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.repeat, size: 20),
                        onPressed: () => _showRepeatDialog(index),
                        tooltip: 'Repeat',
                      ),
                      if (_setRows.length > 1)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _deleteSet(index),
                          tooltip: 'Delete',
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Additional notes...',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            // Convert set rows to PlanExerciseSet objects
            final sets = _setRows.map((row) => PlanExerciseSet(
                  id: '', // Will be assigned by database
                  planExerciseId: widget.exercise.id,
                  setNumber: row.setNumber,
                  reps: row.reps,
                  repsMax: row.repsMax,
                  weight: row.weight,
                )).toList();

            final updated = widget.exercise.copyWith(
              sets: sets,
              tempo:
                  _tempoController.text.isEmpty ? null : _tempoController.text,
              restMin: int.tryParse(_restMinController.text),
              restMax: int.tryParse(_restMaxController.text),
              notes:
                  _notesController.text.isEmpty ? null : _notesController.text,
            );
            Navigator.pop(context, updated);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Helper class to manage set editing state
class _SetEditRow {
  _SetEditRow({
    required this.setNumber,
    required this.reps,
    this.repsMax,
    this.weight,
  });

  final int setNumber;
  final int reps;
  final int? repsMax;
  final double? weight;

  _SetEditRow copyWith({
    int? setNumber,
    int? reps,
    int? repsMax,
    double? weight,
  }) {
    return _SetEditRow(
      setNumber: setNumber ?? this.setNumber,
      reps: reps ?? this.reps,
      repsMax: repsMax ?? this.repsMax,
      weight: weight ?? this.weight,
    );
  }
}
