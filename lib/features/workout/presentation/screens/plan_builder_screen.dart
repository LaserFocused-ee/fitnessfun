import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/error/failures.dart';
import '../../../exercise/domain/entities/exercise.dart';
import '../../../exercise/presentation/providers/exercise_provider.dart';
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

    if (exercise.sets != null) {
      parts.add('${exercise.sets} sets');
    }
    if (exercise.reps != null) {
      parts.add('${exercise.reps} reps');
    }
    if (exercise.tempo != null) {
      parts.add('tempo: ${exercise.tempo}');
    }
    if (exercise.restSeconds != null) {
      parts.add('rest: ${exercise.restSeconds}s');
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
  late final TextEditingController _setsController;
  late final TextEditingController _repsController;
  late final TextEditingController _tempoController;
  late final TextEditingController _restController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _setsController =
        TextEditingController(text: widget.exercise.sets?.toString() ?? '');
    _repsController = TextEditingController(text: widget.exercise.reps ?? '');
    _tempoController = TextEditingController(text: widget.exercise.tempo ?? '');
    _restController =
        TextEditingController(text: widget.exercise.restSeconds ?? '');
    _notesController = TextEditingController(text: widget.exercise.notes ?? '');
  }

  @override
  void dispose() {
    _setsController.dispose();
    _repsController.dispose();
    _tempoController.dispose();
    _restController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.exercise.exerciseName ?? 'Edit Exercise'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _setsController,
              decoration: const InputDecoration(
                labelText: 'Sets',
                hintText: 'e.g., 3',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _repsController,
              decoration: const InputDecoration(
                labelText: 'Reps',
                hintText: 'e.g., 8-10',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tempoController,
              decoration: const InputDecoration(
                labelText: 'Tempo',
                hintText: 'e.g., 3111',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _restController,
              decoration: const InputDecoration(
                labelText: 'Rest (seconds)',
                hintText: 'e.g., 90-120',
              ),
            ),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final updated = widget.exercise.copyWith(
              sets: int.tryParse(_setsController.text),
              reps: _repsController.text.isEmpty ? null : _repsController.text,
              tempo:
                  _tempoController.text.isEmpty ? null : _tempoController.text,
              restSeconds:
                  _restController.text.isEmpty ? null : _restController.text,
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
