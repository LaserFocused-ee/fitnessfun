-- Add started_at to track session duration
ALTER TABLE public.workout_sessions
ADD COLUMN started_at TIMESTAMPTZ DEFAULT NOW();

-- Add plan_id directly for easier querying (denormalized)
ALTER TABLE public.workout_sessions
ADD COLUMN plan_id UUID REFERENCES public.workout_plans(id);

-- Update existing sessions to have plan_id from client_plans
UPDATE public.workout_sessions ws
SET plan_id = cp.plan_id
FROM public.client_plans cp
WHERE ws.client_plan_id = cp.id;

-- Add index for querying sessions by plan
CREATE INDEX idx_workout_sessions_plan ON public.workout_sessions(plan_id);
