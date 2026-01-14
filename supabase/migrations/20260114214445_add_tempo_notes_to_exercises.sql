-- Add tempo and notes columns to exercises table
-- Tempo: Default tempo notation (e.g., "3111") - moved from plan_exercises
-- Notes: Default exercise notes (form cues, technique tips)

ALTER TABLE public.exercises
ADD COLUMN tempo TEXT,
ADD COLUMN notes TEXT;

-- Migrate most common tempo per exercise from plan_exercises
-- For exercises used in multiple plans with different tempos, use the most frequent one
WITH tempo_counts AS (
  SELECT
    exercise_id,
    tempo,
    COUNT(*) as cnt,
    ROW_NUMBER() OVER (PARTITION BY exercise_id ORDER BY COUNT(*) DESC) as rn
  FROM public.plan_exercises
  WHERE tempo IS NOT NULL AND tempo != ''
  GROUP BY exercise_id, tempo
)
UPDATE public.exercises e
SET tempo = tc.tempo
FROM tempo_counts tc
WHERE tc.exercise_id = e.id AND tc.rn = 1;

-- Add comment to document the columns
COMMENT ON COLUMN public.exercises.tempo IS 'Default tempo notation (e.g., "3111" = 3s eccentric, 1s pause, 1s concentric, 1s pause)';
COMMENT ON COLUMN public.exercises.notes IS 'Default exercise notes - form cues, technique tips (always shown to clients)';
