-- ============================================
-- Migration: Restructure Plan Exercise Sets
-- ============================================
-- Creates a normalized structure for per-set configuration
-- Supports: pyramid sets, rep ranges, target weights

-- 1. Create the new plan_exercise_sets table
CREATE TABLE public.plan_exercise_sets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_exercise_id UUID NOT NULL REFERENCES public.plan_exercises(id) ON DELETE CASCADE,
  set_number INTEGER NOT NULL,
  reps INTEGER NOT NULL,
  reps_max INTEGER,  -- nullable, for ranges like 8-10 where reps=8, reps_max=10
  weight REAL,       -- nullable, allows decimals like 22.5
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT positive_set_number CHECK (set_number > 0),
  CONSTRAINT positive_reps CHECK (reps > 0),
  CONSTRAINT valid_reps_max CHECK (reps_max IS NULL OR reps_max >= reps),
  CONSTRAINT non_negative_weight CHECK (weight IS NULL OR weight >= 0)
);

-- 2. Enable RLS on new table
ALTER TABLE public.plan_exercise_sets ENABLE ROW LEVEL SECURITY;

-- 3. RLS policies for plan_exercise_sets (inherit from plan_exercises -> workout_plans)
CREATE POLICY "Trainers can manage plan exercise sets"
ON public.plan_exercise_sets FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.plan_exercises pe
    JOIN public.workout_plans wp ON wp.id = pe.plan_id
    WHERE pe.id = plan_exercise_sets.plan_exercise_id AND wp.trainer_id = auth.uid()
  )
);

CREATE POLICY "Clients can view assigned plan exercise sets"
ON public.plan_exercise_sets FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.plan_exercises pe
    JOIN public.client_plans cp ON cp.plan_id = pe.plan_id
    WHERE pe.id = plan_exercise_sets.plan_exercise_id AND cp.client_id = auth.uid()
  )
);

-- 4. Add new rest columns to plan_exercises (as integers, in seconds)
ALTER TABLE public.plan_exercises
ADD COLUMN rest_min INTEGER,
ADD COLUMN rest_max INTEGER;

-- 5. Indexes for performance
CREATE INDEX idx_plan_exercise_sets_plan_exercise ON public.plan_exercise_sets(plan_exercise_id);
CREATE INDEX idx_plan_exercise_sets_order ON public.plan_exercise_sets(plan_exercise_id, set_number);

-- 6. Migrate existing rest_seconds to rest_min/rest_max
UPDATE public.plan_exercises
SET
  rest_min = CASE
    WHEN rest_seconds ~ '^[0-9]+$' THEN CAST(rest_seconds AS INTEGER)
    WHEN rest_seconds ~ '^[0-9]+-[0-9]+$' THEN CAST(SPLIT_PART(rest_seconds, '-', 1) AS INTEGER)
    ELSE NULL
  END,
  rest_max = CASE
    WHEN rest_seconds ~ '^[0-9]+-[0-9]+$' THEN CAST(SPLIT_PART(rest_seconds, '-', 2) AS INTEGER)
    ELSE NULL
  END
WHERE rest_seconds IS NOT NULL;

-- 7. Migrate existing sets/reps data to plan_exercise_sets
-- For each plan_exercise with sets/reps, create N rows in plan_exercise_sets
INSERT INTO public.plan_exercise_sets (plan_exercise_id, set_number, reps, reps_max, weight)
SELECT
  pe.id AS plan_exercise_id,
  gs AS set_number,
  CASE
    WHEN pe.reps ~ '^[0-9]+$' THEN CAST(pe.reps AS INTEGER)
    WHEN pe.reps ~ '^[0-9]+-[0-9]+$' THEN CAST(SPLIT_PART(pe.reps, '-', 1) AS INTEGER)
    ELSE 10  -- Default reps if not parseable
  END AS reps,
  CASE
    WHEN pe.reps ~ '^[0-9]+-[0-9]+$' THEN CAST(SPLIT_PART(pe.reps, '-', 2) AS INTEGER)
    ELSE NULL
  END AS reps_max,
  NULL AS weight  -- No weight data in current schema
FROM public.plan_exercises pe
CROSS JOIN generate_series(1, COALESCE(pe.sets, 3)) AS gs
WHERE pe.sets IS NOT NULL OR pe.reps IS NOT NULL;

-- 8. Drop old columns now that data is migrated
ALTER TABLE public.plan_exercises
DROP COLUMN IF EXISTS sets,
DROP COLUMN IF EXISTS reps,
DROP COLUMN IF EXISTS rest_seconds;
