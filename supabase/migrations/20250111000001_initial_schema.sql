-- Initial Schema for Fitness Tracking App
-- This migration creates all core tables for the application

-- Use gen_random_uuid() which is available by default in Supabase

-- ============================================
-- PROFILES (extends auth.users)
-- ============================================
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  full_name TEXT,
  role TEXT NOT NULL CHECK (role IN ('trainer', 'client')),
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Users can read their own profile
CREATE POLICY "Users can read own profile"
ON public.profiles FOR SELECT
TO authenticated
USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
ON public.profiles FOR UPDATE
TO authenticated
USING (auth.uid() = id);

-- ============================================
-- TRAINER-CLIENT RELATIONSHIPS
-- ============================================
CREATE TABLE public.trainer_clients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trainer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'inactive')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(trainer_id, client_id)
);

-- Enable RLS
ALTER TABLE public.trainer_clients ENABLE ROW LEVEL SECURITY;

-- Trainers can manage their client relationships
CREATE POLICY "Trainers can manage their relationships"
ON public.trainer_clients FOR ALL
TO authenticated
USING (trainer_id = auth.uid());

-- Clients can view/update their trainer relationships
CREATE POLICY "Clients can view their relationships"
ON public.trainer_clients FOR SELECT
TO authenticated
USING (client_id = auth.uid());

CREATE POLICY "Clients can accept invitations"
ON public.trainer_clients FOR UPDATE
TO authenticated
USING (client_id = auth.uid())
WITH CHECK (client_id = auth.uid());

-- Now that trainer_clients exists, add profile policy for trainers
CREATE POLICY "Trainers can view client profiles"
ON public.profiles FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.trainer_clients tc
    WHERE tc.trainer_id = auth.uid() AND tc.client_id = profiles.id AND tc.status = 'active'
  )
);

-- ============================================
-- EXERCISES (template library)
-- ============================================
CREATE TABLE public.exercises (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  instructions TEXT,
  video_path TEXT,  -- Path in Supabase Storage
  muscle_group TEXT,
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  is_global BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.exercises ENABLE ROW LEVEL SECURITY;

-- Anyone authenticated can view global exercises
CREATE POLICY "Anyone can view global exercises"
ON public.exercises FOR SELECT
TO authenticated
USING (is_global = true);

-- Trainers can view their own exercises
CREATE POLICY "Trainers can view own exercises"
ON public.exercises FOR SELECT
TO authenticated
USING (created_by = auth.uid());

-- Trainers can create exercises
CREATE POLICY "Trainers can create exercises"
ON public.exercises FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'trainer'
  )
);

-- Trainers can update their own exercises
CREATE POLICY "Trainers can update own exercises"
ON public.exercises FOR UPDATE
TO authenticated
USING (created_by = auth.uid());

-- Trainers can delete their own non-global exercises
CREATE POLICY "Trainers can delete own exercises"
ON public.exercises FOR DELETE
TO authenticated
USING (created_by = auth.uid() AND is_global = false);

-- ============================================
-- WORKOUT PLANS
-- ============================================
CREATE TABLE public.workout_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  trainer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.workout_plans ENABLE ROW LEVEL SECURITY;

-- Trainers can manage their own plans
CREATE POLICY "Trainers can manage own plans"
ON public.workout_plans FOR ALL
TO authenticated
USING (trainer_id = auth.uid());

-- NOTE: "Clients can view assigned plans" policy added after client_plans table

-- ============================================
-- PLAN EXERCISES (exercises in a plan with custom params)
-- ============================================
CREATE TABLE public.plan_exercises (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id UUID NOT NULL REFERENCES public.workout_plans(id) ON DELETE CASCADE,
  exercise_id UUID NOT NULL REFERENCES public.exercises(id) ON DELETE CASCADE,
  sets INTEGER,
  reps TEXT,  -- e.g. "8-10"
  tempo TEXT,  -- e.g. "3111"
  rest_seconds TEXT,  -- e.g. "90-120"
  notes TEXT,
  order_index INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.plan_exercises ENABLE ROW LEVEL SECURITY;

-- Same policies as workout_plans (through plan_id)
CREATE POLICY "Trainers can manage plan exercises"
ON public.plan_exercises FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.workout_plans wp
    WHERE wp.id = plan_exercises.plan_id AND wp.trainer_id = auth.uid()
  )
);

-- NOTE: "Clients can view assigned plan exercises" policy added after client_plans table

-- ============================================
-- CLIENT PLANS (assigned plans to clients)
-- ============================================
CREATE TABLE public.client_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  plan_id UUID NOT NULL REFERENCES public.workout_plans(id) ON DELETE CASCADE,
  start_date DATE,
  end_date DATE,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.client_plans ENABLE ROW LEVEL SECURITY;

-- Trainers can manage client plans for their clients
CREATE POLICY "Trainers can manage client plans"
ON public.client_plans FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.trainer_clients tc
    WHERE tc.client_id = client_plans.client_id
    AND tc.trainer_id = auth.uid()
    AND tc.status = 'active'
  )
);

-- Clients can view their own plans
CREATE POLICY "Clients can view own plans"
ON public.client_plans FOR SELECT
TO authenticated
USING (client_id = auth.uid());

-- Now that client_plans exists, add deferred policies
CREATE POLICY "Clients can view assigned plans"
ON public.workout_plans FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.client_plans cp
    WHERE cp.plan_id = workout_plans.id AND cp.client_id = auth.uid()
  )
);

CREATE POLICY "Clients can view assigned plan exercises"
ON public.plan_exercises FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.client_plans cp
    JOIN public.workout_plans wp ON wp.id = cp.plan_id
    WHERE wp.id = plan_exercises.plan_id AND cp.client_id = auth.uid()
  )
);

-- ============================================
-- WORKOUT SESSIONS (when client completes a workout)
-- ============================================
CREATE TABLE public.workout_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  client_plan_id UUID NOT NULL REFERENCES public.client_plans(id) ON DELETE CASCADE,
  completed_at TIMESTAMPTZ DEFAULT NOW(),
  notes TEXT
);

-- Enable RLS
ALTER TABLE public.workout_sessions ENABLE ROW LEVEL SECURITY;

-- Clients can manage their own sessions
CREATE POLICY "Clients can manage own sessions"
ON public.workout_sessions FOR ALL
TO authenticated
USING (client_id = auth.uid());

-- Trainers can view client sessions
CREATE POLICY "Trainers can view client sessions"
ON public.workout_sessions FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.trainer_clients tc
    WHERE tc.client_id = workout_sessions.client_id
    AND tc.trainer_id = auth.uid()
    AND tc.status = 'active'
  )
);

-- ============================================
-- EXERCISE LOGS (individual exercise logs within a session)
-- ============================================
CREATE TABLE public.exercise_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES public.workout_sessions(id) ON DELETE CASCADE,
  plan_exercise_id UUID NOT NULL REFERENCES public.plan_exercises(id) ON DELETE CASCADE,
  completed BOOLEAN DEFAULT true,
  actual_sets INTEGER,  -- NULL = used plan value
  actual_reps TEXT,     -- NULL = used plan value
  actual_weight TEXT,   -- weight used
  actual_rest TEXT,     -- NULL = used plan value
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.exercise_logs ENABLE ROW LEVEL SECURITY;

-- Same policies as workout_sessions (through session_id)
CREATE POLICY "Clients can manage own exercise logs"
ON public.exercise_logs FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.workout_sessions ws
    WHERE ws.id = exercise_logs.session_id AND ws.client_id = auth.uid()
  )
);

CREATE POLICY "Trainers can view client exercise logs"
ON public.exercise_logs FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.workout_sessions ws
    JOIN public.trainer_clients tc ON tc.client_id = ws.client_id
    WHERE ws.id = exercise_logs.session_id
    AND tc.trainer_id = auth.uid()
    AND tc.status = 'active'
  )
);

-- ============================================
-- DAILY CHECK-INS
-- ============================================
CREATE TABLE public.daily_checkins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  date DATE NOT NULL,

  -- Biometrics
  bodyweight_kg DECIMAL(5,2),
  fluid_intake_litres DECIMAL(4,2),
  caffeine_mg INTEGER,

  -- Activity
  steps INTEGER,
  cardio_minutes INTEGER,
  training_session TEXT,  -- "Upper 1", "Lower 2", etc.

  -- Recovery metrics (1-7 scale)
  performance INTEGER CHECK (performance IS NULL OR performance BETWEEN 1 AND 7),
  muscle_soreness INTEGER CHECK (muscle_soreness IS NULL OR muscle_soreness BETWEEN 1 AND 7),
  energy_levels INTEGER CHECK (energy_levels IS NULL OR energy_levels BETWEEN 1 AND 7),
  recovery_rate INTEGER CHECK (recovery_rate IS NULL OR recovery_rate BETWEEN 1 AND 7),
  stress_levels INTEGER CHECK (stress_levels IS NULL OR stress_levels BETWEEN 1 AND 7),
  mental_health INTEGER CHECK (mental_health IS NULL OR mental_health BETWEEN 1 AND 7),
  hunger_levels INTEGER CHECK (hunger_levels IS NULL OR hunger_levels BETWEEN 1 AND 7),

  -- Health
  illness BOOLEAN DEFAULT false,
  gi_distress TEXT,

  -- Sleep
  sleep_duration_minutes INTEGER,
  sleep_quality INTEGER CHECK (sleep_quality IS NULL OR sleep_quality BETWEEN 1 AND 7),

  -- Notes
  notes TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(client_id, date)
);

-- Enable RLS
ALTER TABLE public.daily_checkins ENABLE ROW LEVEL SECURITY;

-- Clients can manage their own check-ins
CREATE POLICY "Clients can manage own checkins"
ON public.daily_checkins FOR ALL
TO authenticated
USING (client_id = auth.uid());

-- Trainers can view client check-ins
CREATE POLICY "Trainers can view client checkins"
ON public.daily_checkins FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.trainer_clients tc
    WHERE tc.client_id = daily_checkins.client_id
    AND tc.trainer_id = auth.uid()
    AND tc.status = 'active'
  )
);

-- ============================================
-- FUNCTIONS & TRIGGERS
-- ============================================

-- Function to handle new user registration
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'role', 'client')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create profile on signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add updated_at triggers
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER update_exercises_updated_at
  BEFORE UPDATE ON public.exercises
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER update_workout_plans_updated_at
  BEFORE UPDATE ON public.workout_plans
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER update_daily_checkins_updated_at
  BEFORE UPDATE ON public.daily_checkins
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================
-- INDEXES FOR PERFORMANCE
-- ============================================
CREATE INDEX idx_trainer_clients_trainer ON public.trainer_clients(trainer_id);
CREATE INDEX idx_trainer_clients_client ON public.trainer_clients(client_id);
CREATE INDEX idx_exercises_created_by ON public.exercises(created_by);
CREATE INDEX idx_exercises_is_global ON public.exercises(is_global);
CREATE INDEX idx_workout_plans_trainer ON public.workout_plans(trainer_id);
CREATE INDEX idx_plan_exercises_plan ON public.plan_exercises(plan_id);
CREATE INDEX idx_client_plans_client ON public.client_plans(client_id);
CREATE INDEX idx_client_plans_plan ON public.client_plans(plan_id);
CREATE INDEX idx_workout_sessions_client ON public.workout_sessions(client_id);
CREATE INDEX idx_exercise_logs_session ON public.exercise_logs(session_id);
CREATE INDEX idx_daily_checkins_client ON public.daily_checkins(client_id);
CREATE INDEX idx_daily_checkins_date ON public.daily_checkins(date);
