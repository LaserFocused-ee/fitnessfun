-- Multi-role support migration
-- Enables users to have both trainer AND client roles with ability to switch between views

-- ============================================
-- USER ROLES JUNCTION TABLE
-- ============================================
CREATE TABLE public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('trainer', 'client')),
  granted_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, role)
);

-- Index for user lookups
CREATE INDEX idx_user_roles_user ON public.user_roles(user_id);

-- Enable RLS
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- Users can view their own roles
CREATE POLICY "Users can view own roles"
ON public.user_roles FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Users can add roles to themselves
CREATE POLICY "Users can add roles"
ON public.user_roles FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- ============================================
-- ADD active_role COLUMN TO PROFILES
-- ============================================
ALTER TABLE public.profiles
  ADD COLUMN active_role TEXT CHECK (active_role IN ('trainer', 'client', 'pending'));

-- ============================================
-- MIGRATE EXISTING USERS
-- ============================================
-- Insert existing roles into user_roles table
INSERT INTO public.user_roles (user_id, role)
  SELECT id, role FROM public.profiles WHERE role IN ('trainer', 'client');

-- Set active_role based on existing role
UPDATE public.profiles SET active_role = role WHERE role IN ('trainer', 'client');
UPDATE public.profiles SET active_role = 'pending' WHERE role = 'pending';

-- ============================================
-- UPDATE RLS POLICIES TO USE user_roles TABLE
-- ============================================

-- 1. exercises: "Trainers can create exercises"
DROP POLICY IF EXISTS "Trainers can create exercises" ON public.exercises;
CREATE POLICY "Trainers can create exercises"
ON public.exercises FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = auth.uid() AND role = 'trainer'
  )
);

-- 2. trainer_videos: "Trainers insert videos"
DROP POLICY IF EXISTS "Trainers insert videos" ON public.trainer_videos;
CREATE POLICY "Trainers insert videos"
ON public.trainer_videos FOR INSERT
TO authenticated
WITH CHECK (
  trainer_id = auth.uid()
  AND EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'trainer')
);

-- 3. storage.objects: "Trainers can upload videos"
DROP POLICY IF EXISTS "Trainers can upload videos" ON storage.objects;
CREATE POLICY "Trainers can upload videos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'exercise-videos'
  AND EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = auth.uid() AND role = 'trainer'
  )
);

-- 4. storage.objects: "Trainers can update own videos"
DROP POLICY IF EXISTS "Trainers can update own videos" ON storage.objects;
CREATE POLICY "Trainers can update own videos"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'exercise-videos'
  AND EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = auth.uid() AND role = 'trainer'
  )
);

-- 5. storage.objects: "Trainers can delete own videos"
DROP POLICY IF EXISTS "Trainers can delete own videos" ON storage.objects;
CREATE POLICY "Trainers can delete own videos"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'exercise-videos'
  AND EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = auth.uid() AND role = 'trainer'
  )
);

-- ============================================
-- UPDATE handle_new_user FUNCTION
-- ============================================
-- Update the trigger function to set active_role and create user_role entry
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  user_role TEXT;
BEGIN
  -- Get the role from metadata, default to 'pending' for OAuth users
  user_role := COALESCE(NEW.raw_user_meta_data->>'role', 'pending');

  -- Insert into profiles
  INSERT INTO public.profiles (id, email, full_name, role, active_role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    user_role,
    user_role
  );

  -- If role is trainer or client, also insert into user_roles
  IF user_role IN ('trainer', 'client') THEN
    INSERT INTO public.user_roles (user_id, role)
    VALUES (NEW.id, user_role);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
