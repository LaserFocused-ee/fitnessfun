-- Update the handle_new_user function to use 'pending' as the default role
-- This allows us to detect OAuth users who haven't selected their role yet
-- and redirect them to role selection.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    -- If role is explicitly set in metadata, use it. Otherwise, use 'pending'
    -- to indicate the user needs to select their role (typically OAuth users).
    COALESCE(NULLIF(NEW.raw_user_meta_data->>'role', ''), 'pending')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
