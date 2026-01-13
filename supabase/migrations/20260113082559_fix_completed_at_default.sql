-- Remove DEFAULT now() from completed_at column
-- Sessions should only have completed_at set when explicitly completed
ALTER TABLE public.workout_sessions
  ALTER COLUMN completed_at DROP DEFAULT;
