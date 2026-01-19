-- Default both trainer AND client roles for all users
-- This enables the role toggle for everyone

-- ============================================
-- GIVE ALL EXISTING USERS BOTH ROLES
-- ============================================
-- Add client role to users who only have trainer
INSERT INTO public.user_roles (user_id, role)
SELECT p.id, 'client'
FROM public.profiles p
WHERE p.role IN ('trainer', 'client')
  AND NOT EXISTS (
    SELECT 1 FROM public.user_roles ur
    WHERE ur.user_id = p.id AND ur.role = 'client'
  )
ON CONFLICT (user_id, role) DO NOTHING;

-- Add trainer role to users who only have client
INSERT INTO public.user_roles (user_id, role)
SELECT p.id, 'trainer'
FROM public.profiles p
WHERE p.role IN ('trainer', 'client')
  AND NOT EXISTS (
    SELECT 1 FROM public.user_roles ur
    WHERE ur.user_id = p.id AND ur.role = 'trainer'
  )
ON CONFLICT (user_id, role) DO NOTHING;

-- ============================================
-- UPDATE handle_new_user TO GIVE BOTH ROLES
-- ============================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  user_role TEXT;
BEGIN
  -- Get the role from metadata, default to 'client' for OAuth users (was 'pending')
  user_role := COALESCE(NEW.raw_user_meta_data->>'role', 'client');

  -- If pending, default to client
  IF user_role = 'pending' THEN
    user_role := 'client';
  END IF;

  -- Insert into profiles
  INSERT INTO public.profiles (id, email, full_name, role, active_role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    user_role,
    user_role
  );

  -- Give ALL users BOTH roles by default
  INSERT INTO public.user_roles (user_id, role) VALUES (NEW.id, 'trainer');
  INSERT INTO public.user_roles (user_id, role) VALUES (NEW.id, 'client');

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
