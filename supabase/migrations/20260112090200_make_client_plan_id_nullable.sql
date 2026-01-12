-- Make client_plan_id nullable in workout_sessions
-- This allows users to start workouts directly from a plan template
-- without requiring an explicit client_plan assignment

ALTER TABLE public.workout_sessions
ALTER COLUMN client_plan_id DROP NOT NULL;
