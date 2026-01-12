-- Add set_data JSONB column to store per-set logging
-- Format: [{"reps": "10", "weight": "40kg"}, {"reps": "8", "weight": "40kg"}, ...]

ALTER TABLE public.exercise_logs
ADD COLUMN set_data JSONB DEFAULT '[]'::jsonb;

-- Add comment for documentation
COMMENT ON COLUMN public.exercise_logs.set_data IS 'Per-set logging data as JSON array. Each element: {reps: string, weight: string}';
