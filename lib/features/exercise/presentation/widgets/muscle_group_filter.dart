import 'package:flutter/material.dart';
import '../../domain/entities/exercise.dart';

class MuscleGroupFilter extends StatelessWidget {
  const MuscleGroupFilter({
    super.key,
    required this.selectedGroup,
    required this.onSelected,
  });

  final String? selectedGroup;
  final void Function(String?) onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // "All" chip
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('All'),
              selected: selectedGroup == null,
              onSelected: (_) => onSelected(null),
              showCheckmark: false,
              backgroundColor: colorScheme.surface,
              selectedColor: colorScheme.primaryContainer,
            ),
          ),
          // Muscle group chips
          ...MuscleGroups.all.map((group) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(group),
                selected: selectedGroup == group,
                onSelected: (_) =>
                    onSelected(selectedGroup == group ? null : group),
                showCheckmark: false,
                backgroundColor: colorScheme.surface,
                selectedColor: colorScheme.primaryContainer,
              ),
            );
          }),
        ],
      ),
    );
  }
}
