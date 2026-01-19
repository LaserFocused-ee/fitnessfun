import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/error/failures.dart';
import '../../../video_library/domain/entities/trainer_video.dart';
import '../../../video_library/presentation/widgets/video_picker_dialog.dart';
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
  final _tempoController = TextEditingController();
  String? _selectedMuscleGroup;
  String? _selectedVideoPath;
  String? _selectedVideoName;
  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _instructionsController.dispose();
    _tempoController.dispose();
    super.dispose();
  }

  void _initializeForm(Exercise exercise) {
    if (!_isInitialized) {
      _nameController.text = exercise.name;
      _instructionsController.text = exercise.instructions ?? '';
      _tempoController.text = exercise.tempo ?? '';
      _selectedMuscleGroup = exercise.muscleGroup;
      _selectedVideoPath = exercise.videoPath;
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
    notifier.setTempo(
      _tempoController.text.trim().isEmpty
          ? null
          : _tempoController.text.trim(),
    );
    notifier.setVideoPath(_selectedVideoPath);
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
          return _buildForm(context, canDelete: true);
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

  Future<void> _openVideoPicker() async {
    final selected = await showVideoPickerDialog(
      context,
      selectedVideoPath: _selectedVideoPath,
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedVideoPath = selected.storagePath;
        _selectedVideoName = selected.name;
      });
    }
  }

  Widget _buildVideoSelector(BuildContext context, ColorScheme colorScheme) {
    final hasVideo = _selectedVideoPath != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Demo Video',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _openVideoPicker,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: hasVideo
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    hasVideo ? Icons.videocam : Icons.videocam_outlined,
                    color: hasVideo
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasVideo
                            ? (_selectedVideoName ?? 'Video selected')
                            : 'No video selected',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: hasVideo
                                  ? colorScheme.onSurface
                                  : colorScheme.onSurfaceVariant,
                            ),
                      ),
                      Text(
                        hasVideo
                            ? 'Tap to change'
                            : 'Tap to select or upload',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                if (hasVideo)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _selectedVideoPath = null;
                        _selectedVideoName = null;
                      });
                    },
                    tooltip: 'Remove video',
                  )
                else
                  Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
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

            // Tempo field
            TextFormField(
              controller: _tempoController,
              decoration: const InputDecoration(
                labelText: 'Default Tempo',
                hintText: 'e.g., 3111 (eccentric-pause-concentric-pause)',
                border: OutlineInputBorder(),
                helperText: 'Each digit = seconds for that phase',
              ),
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 16),

            // Instructions field
            TextFormField(
              controller: _instructionsController,
              decoration: const InputDecoration(
                labelText: 'Instructions',
                hintText: 'Form cues, technique tips, step-by-step instructions...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
                helperText: 'These instructions are shown to clients',
              ),
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
            ),

            const SizedBox(height: 16),

            // Video selector
            _buildVideoSelector(context, colorScheme),

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
