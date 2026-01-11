-- Storage configuration for exercise videos
-- Private bucket with authenticated access

-- Create private bucket for exercise videos
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('exercise-videos', 'exercise-videos', false, 104857600)  -- 100MB limit
ON CONFLICT (id) DO NOTHING;

-- RLS Policy: Only authenticated users can read videos
CREATE POLICY "Authenticated users can view videos"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'exercise-videos');

-- RLS Policy: Only trainers can upload videos
CREATE POLICY "Trainers can upload videos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'exercise-videos'
  AND EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'trainer'
  )
);

-- RLS Policy: Trainers can update their own videos
CREATE POLICY "Trainers can update own videos"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'exercise-videos'
  AND EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'trainer'
  )
);

-- RLS Policy: Trainers can delete their own videos
CREATE POLICY "Trainers can delete own videos"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'exercise-videos'
  AND EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'trainer'
  )
);
