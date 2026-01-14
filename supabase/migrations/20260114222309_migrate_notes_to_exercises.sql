-- Migrate notes from plan_exercises to exercises
-- For exercises that don't have notes yet, copy the most common notes from plan_exercises

-- Use the most frequently used notes per exercise (in case of duplicates)
WITH notes_ranked AS (
  SELECT
    exercise_id,
    notes,
    COUNT(*) as cnt,
    ROW_NUMBER() OVER (PARTITION BY exercise_id ORDER BY COUNT(*) DESC) as rn
  FROM public.plan_exercises
  WHERE notes IS NOT NULL AND notes != ''
  GROUP BY exercise_id, notes
)
UPDATE public.exercises e
SET notes = nr.notes
FROM notes_ranked nr
WHERE nr.exercise_id = e.id
  AND nr.rn = 1
  AND (e.notes IS NULL OR e.notes = '');
