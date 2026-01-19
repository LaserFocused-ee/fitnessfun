-- Rename training_session to workout_plan_id and change type to UUID reference
-- This stores the workout plan ID instead of a free-text session name

-- First, drop the old column and add new one with proper type
ALTER TABLE daily_checkins
  DROP COLUMN IF EXISTS training_session;

ALTER TABLE daily_checkins
  ADD COLUMN workout_plan_id UUID REFERENCES workout_plans(id) ON DELETE SET NULL;

-- Add index for lookups
CREATE INDEX IF NOT EXISTS idx_daily_checkins_workout_plan_id
  ON daily_checkins(workout_plan_id);
