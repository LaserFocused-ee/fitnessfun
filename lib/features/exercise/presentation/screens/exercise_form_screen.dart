import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/exercise.dart';
import '../providers/exercise_provider.dart';

class ExerciseFormScreen extends ConsumerStatefulWidget {
  const ExerciseFormScreen({
    super.key,
    this.exerciseId,
  });

  final String? exerciseId;

  bool get isEditing => exerciseId != null;

  @override
  ConsumerState<ExerciseFormScreen> createState() => _ExerciseFormScreenState();
}

class _ExerciseFormScreenState extends ConsumerState<ExerciseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _videoUrlController = TextEditingController();
  String? _selectedMuscleGroup;
  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _instructionsController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }

  void _initializeForm(Exercise exercise) {
    if (!_isInitialized) {
      _nameController.text = exercise.name;
      _instructionsController.text = exercise.instructions ?? '';
      _videoUrlController.text = exercise.videoUrl ?? '';
      _selectedMuscleGroup = exercise.muscleGroup;
      _isInitialized = true;
    }
  }

  Future<void> _saveExercise() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final notifier = ref.read(exerciseFormNotifierProvider.notifier);
    notifier.setName(_nameController.text.trim());
    notifier.setInstructions(
      _instructionsController.text.trim().isEmpty
          ? null
          : _instructionsController.text.trim(),
    );
    notifier.setVideoUrl(
      _videoUrlController.text.trim().isEmpty
          ? null
          : _videoUrlController.text.trim(),
    );
    notifier.setMuscleGroup(_selectedMuscleGroup);

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
      (exercise) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditing
                  ? 'Exercise updated successfully'
                  : 'Exercise created successfully',
            ),
          ),
        );
        ref.invalidate(filteredExercisesProvider);
        context.pop();
      },
    );
  }

  Future<void> _deleteExercise() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Exercise'),
        content: const Text(
          'Are you sure you want to delete this exercise? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    final notifier = ref.read(exerciseFormNotifierProvider.notifier);
    final result = await notifier.delete();

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
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exercise deleted')),
        );
        ref.invalidate(filteredExercisesProvider);
        context.pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // If editing, load the exercise
    if (widget.isEditing) {
      final exerciseAsync = ref.watch(exerciseByIdProvider(widget.exerciseId!));

      return exerciseAsync.when(
        data: (exercise) {
          _initializeForm(exercise);
          // Load into notifier for saving
          if (!_isInitialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(exerciseFormNotifierProvider.notifier).loadExercise(exercise);
            });
          }
          return _buildForm(context, canDelete: !exercise.isGlobal);
        },
        loading: () => Scaffold(
          appBar: AppBar(title: const Text('Edit Exercise')),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Scaffold(
          appBar: AppBar(title: const Text('Edit Exercise')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Creating new exercise
    if (!_isInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(exerciseFormNotifierProvider.notifier).reset();
      });
      _isInitialized = true;
    }
    return _buildForm(context, canDelete: false);
  }

  Widget _buildForm(BuildContext context, {required bool canDelete}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Exercise' : 'Create Exercise'),
        actions: [
          if (widget.isEditing && canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _isLoading ? null : _deleteExercise,
              tooltip: 'Delete',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Name field
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Exercise Name *',
                hintText: 'e.g., Barbell Bench Press',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an exercise name';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Muscle group dropdown
            DropdownButtonFormField<String>(
              value: _selectedMuscleGroup,
              decoration: const InputDecoration(
                labelText: 'Muscle Group',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Select muscle group'),
                ),
                ...MuscleGroups.all.map((group) => DropdownMenuItem(
                      value: group,
                      child: Text(group),
                    )),
              ],
              onChanged: (value) {
                setState(() => _selectedMuscleGroup = value);
              },
            ),

            const SizedBox(height: 16),

            // Instructions field
            TextFormField(
              controller: _instructionsController,
              decoration: const InputDecoration(
                labelText: 'Instructions',
                hintText: 'Step-by-step instructions for proper form...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
            ),

            const SizedBox(height: 16),

            // Video URL field
            TextFormField(
              controller: _videoUrlController,
              decoration: const InputDecoration(
                labelText: 'Video URL',
                hintText: 'https://youtube.com/watch?v=...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.videocam_outlined),
              ),
              keyboardType: TextInputType.url,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final uri = Uri.tryParse(value);
                  if (uri == null || !uri.hasScheme) {
                    return 'Please enter a valid URL';
                  }
                }
                return null;
              },
            ),

            const SizedBox(height: 8),

            Text(
              'Tip: You can paste a YouTube or Vimeo link for the video demo.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),

            const SizedBox(height: 32),

            // Save button
            FilledButton.icon(
              onPressed: _isLoading ? null : _saveExercise,
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
              label: Text(widget.isEditing ? 'Save Changes' : 'Create Exercise'),
            ),
          ],
        ),
      ),
    );
  }
}
